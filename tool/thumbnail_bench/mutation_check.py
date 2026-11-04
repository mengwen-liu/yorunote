#!/usr/bin/env python3
"""Mutation check for the cover cache / queue protections.

Applies one mutation at a time to a scratch copy of the candidate, runs the
related tests and records whether they fail (the mutation is "killed").
The copy is restored after every mutation; nothing is kept.

Usage: python3 -I mutation_check.py <scratch_repo> <out.json>
Requires flutter on PATH and FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR.
"""
import json
import pathlib
import subprocess
import sys
import time

REPO = pathlib.Path(sys.argv[1]).resolve()
OUT = pathlib.Path(sys.argv[2]).resolve()

IMAGES = "lib/network/images.dart"
LIMITER = "lib/network/request_limiter.dart"
CACHED = "lib/foundation/image_provider/cached_image.dart"
HISTORY = "lib/foundation/image_provider/history_image_provider.dart"
T_CACHE = "test/network/thumbnail_cover_cache_test.dart"
T_QUEUE = "test/network/thumbnail_cover_queue_test.dart"
T_LIMIT = "test/network/request_limiter_test.dart"

MUTANTS = [
    {
        "id": "M1_invalidate_without_byte_check",
        "why": "invalidation must not delete an entry repaired in the meantime",
        "file": IMAGES,
        "old": "      if (!listEquals(await file.readAsBytes(), data)) {\n        return;\n      }\n",
        "new": "",
        "tests": [T_CACHE],
    },
    {
        "id": "M2_cached_provider_default_invalidation",
        "why": "CachedImageProvider must invalidate the real disk key",
        "file": CACHED,
        "old": "  @override\n  Future<void> onInvalidImageData(Uint8List data) =>\n      ImageDownloader.invalidateCoverCache(data);\n",
        "new": "",
        "tests": [T_CACHE],
    },
    {
        "id": "M3_history_provider_default_invalidation",
        "why": "HistoryImageProvider must invalidate the real disk key",
        "file": HISTORY,
        "old": "  @override\n  Future<void> onInvalidImageData(Uint8List data) =>\n      ImageDownloader.invalidateCoverCache(data);\n",
        "new": "",
        "tests": [T_CACHE],
    },
    {
        "id": "M4_limit_9",
        "why": "explicit limit of 8 concurrent cover requests",
        "file": IMAGES,
        "old": "static const maxCoverRequests = 8;",
        "new": "static const maxCoverRequests = 9;",
        "tests": [T_QUEUE, T_LIMIT],
    },
    {
        "id": "M5_release_without_handoff",
        "why": "a released slot must be handed to the next waiter (event driven)",
        "file": LIMITER,
        "old": "      _active--;\n      _grantNext();\n",
        "new": "      _active--;\n",
        "tests": [T_QUEUE, T_LIMIT],
    },
    {
        "id": "M6_grant_cancelled_waiters",
        "why": "cancelled waiters must be skipped without taking a slot",
        "file": LIMITER,
        "old": "      if (waiter.cancelled) {",
        "new": "      if (false && waiter.cancelled) {",
        "tests": [T_QUEUE, T_LIMIT],
    },
    {
        "id": "M7_cache_hit_waits_for_slot",
        "why": "valid cache hits must not wait for a network slot",
        "file": IMAGES,
        "old": "    final cacheKey = thumbnailCacheKey(url, sourceKey, cid);\n    final cache = await _readCoverCache(cacheKey);\n    if (cache != null) {\n      return cache;\n    }\n    var load = _coverLoads[cacheKey];",
        "new": "    final cacheKey = thumbnailCacheKey(url, sourceKey, cid);\n    final r0 = await coverRequestLimiter.acquire();\n    Uint8List? cache;\n    try {\n      cache = await _readCoverCache(cacheKey);\n    } finally {\n      r0();\n    }\n    if (cache != null) {\n      return cache;\n    }\n    var load = _coverLoads[cacheKey];",
        "tests": [T_QUEUE],
    },
    {
        "id": "M8_no_request_sharing",
        "why": "loads of the same cache key share one request",
        "file": IMAGES,
        "old": "    var load = _coverLoads[cacheKey];\n    if (load != null) {",
        "new": "    var load = _coverLoads[cacheKey];\n    if (false && load != null) {",
        "tests": [T_QUEUE],
    },
    {
        "id": "M9_abort_when_any_consumer_leaves",
        "why": "one cancelled load must not abort a request others still use",
        "file": IMAGES,
        "old": "  bool isCancelled() => consumers.every((c) => c.isCancelled());",
        "new": "  bool isCancelled() => consumers.any((c) => c.isCancelled());",
        "tests": [T_QUEUE],
    },
    {
        "id": "M10_release_only_on_success",
        "why": "errors must give the slot back",
        "file": IMAGES,
        "old": "      _coverCacheKeys[result] = cacheKey;\n      return result;\n    } finally {\n      release();\n    }",
        "new": "      _coverCacheKeys[result] = cacheKey;\n      release();\n      return result;\n    } finally {\n    }",
        "tests": [T_QUEUE],
    },
]


def run_tests(tests):
    t0 = time.time()
    p = subprocess.run(
        ["flutter", "test", "--no-pub", *tests],
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=900,
    )
    tail = [l for l in p.stdout.splitlines() if l.strip()][-1:] or [""]
    return p.returncode, round(time.time() - t0, 1), tail[0][-200:]


def main():
    results = []
    for m in MUTANTS:
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
        results.append({
            "id": m["id"],
            "why": m["why"],
            "file": m["file"],
            "tests": m["tests"],
            "exit_code": code,
            "seconds": secs,
            "last_line": tail,
            "status": "KILLED" if killed else "SURVIVED",
        })
        print(m["id"], results[-1]["status"], code, secs, flush=True)
    # Sanity: the unmutated copy passes the same tests.
    code, secs, tail = run_tests([T_CACHE, T_QUEUE, T_LIMIT])
    OUT.write_text(json.dumps(
        {"unmutated_exit_code": code, "unmutated_last_line": tail,
         "mutants": results},
        indent=2, ensure_ascii=False))
    print("unmutated", code, tail)


if __name__ == "__main__":
    main()
