#!/usr/bin/env python3
"""r2 mutation check: cancellation, adapter and queued-cache protections.

Applies one mutation at a time to a scratch copy of the candidate, runs the
related tests and records whether they fail (the mutation is "killed").
The copy is restored after every mutation; nothing is kept.

Usage: python3 -I mutation_check_r2.py <scratch_repo> <out.json> [ID,ID,...]
Requires flutter on PATH and FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR.
"""
import json
import pathlib
import subprocess
import sys
import time

REPO = pathlib.Path(sys.argv[1]).resolve()
OUT = pathlib.Path(sys.argv[2]).resolve()
ONLY = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else None

IMAGES = "lib/network/images.dart"
LIMITER = "lib/network/request_limiter.dart"
CACHED = "lib/foundation/image_provider/cached_image.dart"
HISTORY = "lib/foundation/image_provider/history_image_provider.dart"
T_CACHE = "test/network/thumbnail_cover_cache_test.dart"
T_QUEUE = "test/network/thumbnail_cover_queue_test.dart"
T_LIMIT = "test/network/request_limiter_test.dart"
T_INVAL = "test/network/thumbnail_cover_invalidation_test.dart"
T_CANCEL = "test/network/thumbnail_cover_cancel_test.dart"
T_ADAPTER = "test/network/rhttp_adapter_cancel_test.dart"
T_QCACHE = "test/network/thumbnail_cover_queue_cache_test.dart"
ADIO = "lib/network/app_dio.dart"
BASE = "lib/foundation/image_provider/base_image_provider.dart"

MUTANTS = [
    {
        "id": "R1_cancel_rhttp_before_headers",
        "why": "rhttp must not be cancelled while the headers may be arriving (panic=abort race)",
        "file": ADIO,
        "old": "          cancelled = true;\n          if (headersReceived) scheduleRhttpCancel();",
        "new": "          cancelled = true;\n          scheduleRhttpCancel();",
        "tests": [T_CANCEL, T_ADAPTER],
    },
    {
        "id": "R2_no_rhttp_cancel_token",
        "why": "Dio's cancel signal must reach rhttp",
        "file": ADIO,
        "old": "      cancelToken: cancelToken,\n      headers: rhttp.HttpHeaders.rawMap(",
        "new": "      headers: rhttp.HttpHeaders.rawMap(",
        "tests": [T_CANCEL, T_ADAPTER],
    },
    {
        "id": "R3_no_drain_after_cancel",
        "why": "rhttp's cancel error needs a listener after Dio stops listening",
        "file": ADIO,
        "old": "      cancelToken == null\n          ? res.body\n          : _drainAfterCancel(res.body, () => cancelled),",
        "new": "      res.body,",
        "tests": [T_CANCEL, T_ADAPTER],
    },
    {
        "id": "R4_base_ignores_stop_signal",
        "why": "BaseImageProvider must hand the stop signal to providers",
        "file": BASE,
        "old": "          }, stopped.future);",
        "new": "          }, Completer<void>().future);",
        "tests": [T_CANCEL],
    },
    {
        "id": "R5_abandoned_load_stays_joinable",
        "why": "a consumer arriving after all others cancelled must start a new load",
        "file": IMAGES,
        "old": "    _abandoned.complete();\n    ImageDownloader._forgetCoverLoad(this);",
        "new": "    _abandoned.complete();",
        "tests": [T_CANCEL],
    },
    {
        "id": "R6_dio_cancel_before_headers",
        "why": "a slot must stay taken while rhttp still waits for headers",
        "file": IMAGES,
        "old": "    if (headersReceived) {\n      cancelToken.cancel();\n    }",
        "new": "    cancelToken.cancel();",
        "tests": [T_CANCEL],
    },
    {
        "id": "R7_limiter_ignores_cancel_signal",
        "why": "a cancelled waiter must leave the queue at once",
        "file": LIMITER,
        "old": "      if (!waiter.completer.isCompleted && _waiters.remove(waiter)) {",
        "new": "      if (false) {",
        "tests": [T_LIMIT],
    },
    {
        "id": "R8_no_recheck_after_wait",
        "why": "a valid image stored while queued must be used without a request",
        "file": IMAGES,
        "old": "      final cache = await _readValidCoverCache(cacheKey);\n      if (cache != null) {\n        return cache;\n      }",
        "new": "",
        "tests": [T_QCACHE],
    },
    {
        "id": "R9_recheck_accepts_broken_bytes",
        "why": "empty or undecodable bytes stored while queued are no hit",
        "file": IMAGES,
        "old": "      final cache = await _readValidCoverCache(cacheKey);",
        "new": "      final cache = await _readCoverCache(cacheKey);",
        "tests": [T_QCACHE],
    },
]


LAST_OUTPUT = {"text": ""}


def run_tests(tests):
    t0 = time.time()
    p = subprocess.run(
        ["flutter", "test", "--no-pub", "--reporter", "expanded", *tests],
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=900,
    )
    LAST_OUTPUT["text"] = p.stdout + p.stderr
    lines = [l for l in p.stdout.splitlines() if l.strip()]
    tail = [l for l in lines if l[:1].isdigit()][-1:] or lines[-1:] or [""]
    return p.returncode, round(time.time() - t0, 1), tail[0][-200:]


def main():
    results = []
    for m in MUTANTS:
        if ONLY and m["id"] not in ONLY:
            continue
        path = REPO / m["file"]
        original = path.read_text()
        if original.count(m["old"]) != 1:
            results.append({**m, "status": "NOT_APPLIED (pattern not unique)"})
            continue
        path.write_text(original.replace(m["old"], m["new"]))
        try:
            code, secs, tail = run_tests(m["tests"])
        except subprocess.TimeoutExpired:
            code, secs, tail = "timeout", 900, "timeout"
        finally:
            path.write_text(original)
        killed = code != 0
        log_dir = OUT.parent / (OUT.stem + "_logs")
        log_dir.mkdir(exist_ok=True)
        (log_dir / (m["id"] + ".log")).write_text(LAST_OUTPUT["text"])
        failed = sorted({l.split(": ", 1)[-1] for l in LAST_OUTPUT["text"].splitlines()
                         if l.endswith("[E]")})
        compile_error = "Compilation failed" in LAST_OUTPUT["text"]
        results.append({
            "id": m["id"],
            "why": m["why"],
            "file": m["file"],
            "tests": m["tests"],
            "exit_code": code,
            "seconds": secs,
            "last_line": tail,
            "status": ("INVALID (compile error)" if compile_error
                       else "KILLED" if killed else "SURVIVED"),
            "failed_tests": failed,
            "aborted": "SIGABRT" in LAST_OUTPUT["text"],
        })
        print(m["id"], results[-1]["status"], code, secs, flush=True)
    # Sanity: the unmutated copy passes the same tests.
    code, secs, tail = run_tests([T_CANCEL, T_ADAPTER, T_QCACHE, T_LIMIT])
    OUT.write_text(json.dumps(
        {"unmutated_exit_code": code, "unmutated_last_line": tail,
         "mutants": results},
        indent=2, ensure_ascii=False))
    print("unmutated", code, tail)


if __name__ == "__main__":
    main()
