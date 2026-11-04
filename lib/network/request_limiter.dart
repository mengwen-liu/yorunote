import 'dart:async';
import 'dart:collection';

/// Thrown by [RequestLimiter.acquire] when a waiter was cancelled before it
/// got a slot.
class RequestCancelledException implements Exception {
  const RequestCancelledException();

  @override
  String toString() => 'RequestCancelledException';
}

/// Lets at most [maxConcurrent] requests run at the same time.
///
/// Waiters are served in FIFO order. A released slot is handed to the next
/// waiter right away (no polling). Waiters whose [acquire] `isCancelled`
/// callback returns true when their turn comes are skipped, so cancelled loads
/// never hold or lose a slot.
class RequestLimiter {
  RequestLimiter(this.maxConcurrent) : assert(maxConcurrent > 0);

  final int maxConcurrent;

  int _active = 0;

  final _waiters = Queue<_Waiter>();

  /// Number of slots in use.
  int get active => _active;

  /// Number of waiters, including cancelled ones not yet skipped.
  int get waiting => _waiters.length;

  /// Waits for a free slot and returns the function that gives it back.
  ///
  /// The returned function must be called once the request has finished,
  /// failed or been abandoned; calling it again has no effect.
  Future<void Function()> acquire({bool Function()? isCancelled}) {
    if (_active < maxConcurrent && _waiters.isEmpty) {
      _active++;
      return Future.value(_releaser());
    }
    final waiter = _Waiter(isCancelled);
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  void Function() _releaser() {
    var released = false;
    return () {
      if (released) return;
      released = true;
      _active--;
      _grantNext();
    };
  }

  void _grantNext() {
    while (_active < maxConcurrent && _waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      if (waiter.cancelled) {
        waiter.completer.completeError(const RequestCancelledException());
        continue;
      }
      _active++;
      waiter.completer.complete(_releaser());
    }
  }
}

class _Waiter {
  _Waiter(this.isCancelled);

  final bool Function()? isCancelled;

  final completer = Completer<void Function()>();

  bool get cancelled {
    try {
      return isCancelled?.call() ?? false;
    } catch (_) {
      return false;
    }
  }
}
