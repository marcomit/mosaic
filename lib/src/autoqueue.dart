import 'dart:async';
import 'dart:collection';

import 'logger.dart';

typedef InternalQueueAction<T> = Future<T> Function();

class InternalQueueNode<T> {
  final Completer<T> _completer = Completer<T>();
  InternalQueueAction<T> action;

  InternalQueueNode(this.action);

  void resolve(T value) => _completer.complete(value);
}

class InternalAutoQueue {
  static const int MAX_RETRIES = 1;
  bool _isDequeuing = false;
  final Queue<InternalQueueNode> _queue = Queue();

  Future<T> push<T>(InternalQueueAction<T> action) async {
    final node = InternalQueueNode(action);
    _queue.add(node);
    if (!_isDequeuing) _autoDequeue();
    return node._completer.future;
  }

  Future<void> _autoDequeue() async {
    _isDequeuing = true;
    while (_queue.isNotEmpty) {
      _dequeue();
    }
    _isDequeuing = false;
  }

  Future<void> _dequeue() async {
    for (int i = 0; i < MAX_RETRIES; i++) {
      try {
        final first = _queue.first;
        final result = await first.action();
        first._completer.complete(result);
        _queue.removeFirst();
        return;
      } catch (err) {
        logger.log("Generic error");
      }
    }
    logger.log("MAX_RETRIES achieved");
  }

  void remove() {
    _queue.removeFirst();
  }
}
