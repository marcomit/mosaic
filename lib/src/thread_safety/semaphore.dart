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
import 'dart:math';

/// A counting semaphore for controlling access to a resource pool.
///
/// This semaphore implementation allows up to [permits] concurrent operations
/// to proceed while queuing additional requests in FIFO order.
class Semaphore {
  final int _permits;
  final Queue<Completer<void>> _waitQueue = Queue();
  int _available;
  bool _disposed = false;

  Semaphore([this._permits = 1]) : _available = _permits {
    if (_permits < 0) {
      throw ArgumentError.value(_permits, 'permits', 'Must be non-negative');
    }
  }

  Future<void> acquire() async {
    if (_disposed) throw StateError('Semaphore has been disposed');

    if (_available > 0) {
      _available--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  Future<void> lock() => acquire();

  void release() {
    if (_disposed) return;

    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeFirst().complete();
    } else {
      _available = min(_available + 1, _permits);
    }
  }

  void dispose() {
    _disposed = true;
    while (_waitQueue.isNotEmpty) {
      _waitQueue.removeFirst().completeError(
        StateError('Semaphore disposed while waiting'),
      );
    }
  }
}
