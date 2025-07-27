/* 
* BSD 3-Clause License
* 
* Copyright (c) 2025, Marco Menegazzi
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* 1. Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice,
*  this list of conditions and the following disclaimer in the documentation
*  and/or other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its
*  contributors may be used to endorse or promote products derived from
*  this software without specific prior written permission.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';
import 'dart:collection';

import '../logger/logger.dart';

typedef InternalQueueAction<T> = Future<T> Function();

class InternalQueueNode<T> {
  final Completer<T> _completer = Completer<T>();
  InternalQueueAction<T> action;

  InternalQueueNode(this.action);

  void resolve(T value) => _completer.complete(value);
}

class InternalAutoQueue {
  static const int maxRetries = 1;
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
    for (int i = 0; i < maxRetries; i++) {
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
