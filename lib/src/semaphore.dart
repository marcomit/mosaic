import 'dart:async';
import 'dart:collection';

class Semaphore {
  // final int _maxThreads;
  final Queue<Completer<void>> _queue = Queue();

  // Semaphore([this._maxThreads = 1]);

  Future<void> lock() {
    final completer = Completer<void>();
    _queue.addLast(completer);

    if (_queue.length == 1) {
      return Future.value();
    }

    return _queue.elementAt(_queue.length - 2).future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeFirst().complete();
    }
  }
}
