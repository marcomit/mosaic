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
import 'mutex.dart';

/// A function type that represents an asynchronous operation in the queue.
///
/// This typedef defines the signature for operations that can be queued
/// for execution. The operation should return a [Future] of type [T].
///
/// Example:
/// ```dart
/// InternalQueueAction<String> fetchData = () async {
///   final response = await http.get('https://api.example.com/data');
///   return response.body;
/// };
/// ```
typedef InternalQueueAction<T> = Future<T> Function();

/// Represents a single operation in the queue with its completion mechanism.
///
/// Each node wraps an asynchronous operation and provides a way to signal
/// completion to the caller through a [Completer]. This allows the queue
/// to process operations asynchronously while providing a way for callers
/// to await the results.
///
/// The node is parameterized by type [T] which represents the return type
/// of the operation.
///
/// Example:
/// ```dart
/// final node = InternalQueueNode<String>(() async => 'Hello World');
/// final future = node._completer.future;
///
/// // Later, when processing completes:
/// node.resolve('Hello World');
/// ```
class InternalQueueNode<T> {
  /// Completer used to signal operation completion to waiting callers.
  ///
  /// This completer is resolved when the operation completes successfully
  /// or rejected when the operation fails after all retry attempts.
  final Completer<T> _completer = Completer<T>();

  /// The asynchronous operation to be executed.
  ///
  /// This function will be called when the queue processes this node.
  /// It should complete with a value of type [T] or throw an exception
  /// if the operation fails.
  final InternalQueueAction<T> action;

  /// Creates a new queue node with the specified [action].
  ///
  /// The [action] parameter defines the operation to be executed when
  /// this node is processed by the queue.
  ///
  /// Example:
  /// ```dart
  /// final node = InternalQueueNode(() async {
  ///   await Future.delayed(Duration(seconds: 1));
  ///   return 'Operation complete';
  /// });
  /// ```
  InternalQueueNode(this.action);

  /// Gets the future that completes when this operation finishes.
  ///
  /// Callers should await this future to get the result of the operation.
  /// The future will complete with the operation result or reject with
  /// an error if all retry attempts fail.
  Future<T> get future => _completer.future;

  /// Resolves this operation with the given [value].
  ///
  /// This method is called by the queue when the operation completes
  /// successfully. It signals to any waiting callers that the operation
  /// has finished and provides the result.
  ///
  /// **Note:** This method should only be called once per node.
  ///
  /// Example:
  /// ```dart
  /// node.resolve('Success!');
  /// ```
  void resolve(T value) => _completer.complete(value);

  /// Rejects this operation with the given [error].
  ///
  /// This method is called by the queue when the operation fails after
  /// all retry attempts have been exhausted. It signals to any waiting
  /// callers that the operation could not be completed.
  ///
  /// **Note:** This method should only be called once per node.
  ///
  /// Example:
  /// ```dart
  /// node.reject(Exception('Operation failed after 3 retries'));
  /// ```
  void reject(Object error, [StackTrace? stackTrace]) {
    _completer.completeError(error, stackTrace);
  }
}

/// Internal state container for the auto queue.
///
/// This class encapsulates the queue's internal state to ensure thread-safe
/// access through mutex operations. It contains both the operation queue
/// and the dequeuing status flag.
///
/// **Thread Safety:** This class is not thread-safe on its own. It should
/// only be accessed through mutex operations to ensure consistency.
class _QueueState {
  /// The queue of pending operations waiting to be processed.
  ///
  /// Operations are processed in FIFO (First In, First Out) order.
  /// Each element is an [InternalQueueNode] representing a queued operation.
  final Queue<InternalQueueNode> queue = Queue<InternalQueueNode>();

  /// Flag indicating whether the queue is currently being processed.
  ///
  /// This prevents multiple dequeue operations from running simultaneously
  /// and ensures efficient resource utilization.
  bool isDequeuing = false;

  /// Gets the current number of operations in the queue.
  ///
  /// This property provides insight into the queue's current load.
  /// A consistently high number may indicate that operations are being
  /// queued faster than they can be processed.
  int get length => queue.length;

  /// Checks if the queue is currently empty.
  ///
  /// Returns `true` if there are no pending operations, `false` otherwise.
  bool get isEmpty => queue.isEmpty;

  /// Checks if the queue contains any operations.
  ///
  /// Returns `true` if there are pending operations, `false` otherwise.
  bool get isNotEmpty => queue.isNotEmpty;
}

/// A thread-safe auto-retry queue for asynchronous operations.
///
/// This class provides automatic retry functionality for failed operations
/// with configurable retry limits. Operations are processed sequentially
/// to ensure thread safety and resource management.
///
/// ## Features
///
/// - **Thread-safe**: All operations are protected by mutex locks
/// - **Automatic retry**: Failed operations are retried up to [maxRetries] times
/// - **Sequential processing**: Operations are processed one at a time
/// - **Background processing**: Queue processing doesn't block callers
/// - **Type-safe**: Generic support for any return type
///
/// ## Usage
///
/// ```dart
/// final queue = InternalAutoQueue(maxRetries: 3);
///
/// // Queue an operation
/// final result = await queue.push<String>(() async {
///   final response = await http.get('https://api.example.com/data');
///   return response.body;
/// });
///
/// print('Result: $result');
/// ```
///
/// ## Error Handling
///
/// Operations that fail after all retry attempts will cause the returned
/// future to complete with an error. The queue will continue processing
/// other operations.
///
/// ```dart
/// try {
///   final result = await queue.push(() async {
///     throw Exception('This will fail');
///   });
/// } catch (e) {
///   print('Operation failed: $e');
/// }
/// ```
///
/// ## Performance Considerations
///
/// - Operations are processed sequentially, not in parallel
/// - Failed operations consume retry attempts before being removed
/// - Memory usage grows with queue length - monitor in high-throughput scenarios
/// - Background processing uses minimal resources when queue is empty
///
/// ## Thread Safety
///
/// All public methods are thread-safe and can be called from multiple
/// isolates simultaneously. Internal state is protected by mutex locks.
class InternalAutoQueue with Loggable {
  /// Maximum number of retry attempts for failed operations.
  ///
  /// When an operation fails, it will be retried up to this many times
  /// before being considered permanently failed. A value of 1 means
  /// each operation gets one retry attempt after the initial failure.
  ///
  /// **Default:** 1 retry attempt
  ///
  /// Example:
  /// ```dart
  /// final queue = InternalAutoQueue(maxRetries: 3);
  /// // Operations will be attempted up to 4 times total (1 initial + 3 retries)
  /// ```
  final int maxRetries;

  /// Mutex protecting the internal queue state.
  ///
  /// This mutex ensures thread-safe access to the queue and prevents
  /// race conditions when multiple threads are adding operations or
  /// checking queue status.
  final Mutex<_QueueState> _queue = Mutex(_QueueState());

  /// Logger tags for this queue instance.
  ///
  /// All log messages from this queue will be tagged with these values
  /// for easy filtering and debugging.
  @override
  List<String> get loggerTags => ['auto_queue'];

  /// Creates a new auto-retry queue with the specified configuration.
  ///
  /// **Parameters:**
  /// - [maxRetries]: Maximum number of retry attempts for failed operations.
  ///   Defaults to 1. Must be non-negative.
  ///
  /// **Example:**
  /// ```dart
  /// // Queue with default retry behavior (1 retry)
  /// final defaultQueue = InternalAutoQueue();
  ///
  /// // Queue with custom retry limit
  /// final customQueue = InternalAutoQueue(maxRetries: 5);
  /// ```
  ///
  /// **Throws:**
  /// - [ArgumentError] if [maxRetries] is negative
  InternalAutoQueue([this.maxRetries = 1]) {
    if (maxRetries < 0) {
      throw ArgumentError.value(
        maxRetries,
        'maxRetries',
        'Must be non-negative',
      );
    }
    debug('Auto queue created with maxRetries: $maxRetries');
  }

  /// Adds an operation to the queue and returns a future for its result.
  ///
  /// The operation will be executed asynchronously in the background.
  /// If the operation fails, it will be retried up to [maxRetries] times.
  /// If all retry attempts fail, the returned future will complete with
  /// an error.
  ///
  /// **Type Parameter:**
  /// - [T]: The return type of the operation
  ///
  /// **Parameters:**
  /// - [action]: The asynchronous operation to queue for execution
  ///
  /// **Returns:** A [Future] that completes with the operation result
  /// or an error if all attempts fail.
  ///
  /// **Example:**
  /// ```dart
  /// // Queue a simple operation
  /// final result = await queue.push<int>(() async => 42);
  ///
  /// // Queue a network operation
  /// final data = await queue.push<String>(() async {
  ///   final response = await http.get('https://api.example.com/data');
  ///   if (response.statusCode != 200) {
  ///     throw Exception('HTTP ${response.statusCode}');
  ///   }
  ///   return response.body;
  /// });
  /// ```
  ///
  /// **Error Handling:**
  /// ```dart
  /// try {
  ///   final result = await queue.push(() async {
  ///     throw Exception('Simulated failure');
  ///   });
  /// } catch (e) {
  ///   print('Operation failed after all retries: $e');
  /// }
  /// ```
  ///
  /// **Thread Safety:** This method is thread-safe and can be called
  /// concurrently from multiple threads.
  Future<T> push<T>(InternalQueueAction<T> action) async {
    final node = InternalQueueNode<T>(action);

    debug('Pushing operation to queue');

    // Add to queue and check if we need to start processing
    final shouldStartDequeue = await _queue.use((state) async {
      state.queue.add(node);
      debug('Queue length: ${state.length}');

      if (!state.isDequeuing) {
        state.isDequeuing = true;
        return true;
      }
      return false;
    });

    // Start background processing if needed
    if (shouldStartDequeue) {
      debug('Starting background dequeue process');
      unawaited(_autoDequeue());
    }

    return node.future;
  }

  /// Gets the current number of operations waiting in the queue.
  ///
  /// This method provides insight into the queue's current load without
  /// blocking or interfering with ongoing operations.
  ///
  /// **Returns:** The number of pending operations
  ///
  /// **Example:**
  /// ```dart
  /// final queueLength = await queue.length;
  /// if (queueLength > 100) {
  ///   print('Warning: Queue is getting long ($queueLength operations)');
  /// }
  /// ```
  ///
  /// **Thread Safety:** This method is thread-safe and provides a
  /// consistent snapshot of the queue length at the time of the call.
  Future<int> get length async {
    return await _queue.use((state) async => state.length);
  }

  /// Checks if the queue is currently empty.
  ///
  /// **Returns:** `true` if no operations are pending, `false` otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (await queue.isEmpty) {
  ///   print('Queue is empty - all operations completed');
  /// }
  /// ```
  Future<bool> get isEmpty async {
    return await _queue.use((state) async => state.isEmpty);
  }

  /// Automatically processes all operations in the queue.
  ///
  /// This method runs in the background and processes operations sequentially
  /// until the queue is empty. It handles the dequeuing flag to prevent
  /// multiple concurrent dequeue operations.
  ///
  /// **Process Flow:**
  /// 1. Extract next operation from queue (thread-safe)
  /// 2. Process operation with retry logic
  /// 3. Repeat until queue is empty
  /// 4. Update dequeuing flag when finished
  ///
  /// **Error Handling:** Individual operation failures don't stop the
  /// processing of other operations. Failed operations are logged and
  /// their futures are completed with errors.
  ///
  /// **Thread Safety:** This method coordinates with [push] through
  /// mutex-protected state to ensure only one dequeue process runs
  /// at a time.
  Future<void> _autoDequeue() async {
    debug('Starting auto-dequeue process');

    try {
      while (true) {
        // Get next item from queue (thread-safe)
        final item = await _queue.use((state) async {
          if (state.isEmpty) {
            // No more items - stop dequeuing
            state.isDequeuing = false;
            debug('Queue empty, stopping dequeue process');
            return null;
          }

          final item = state.queue.removeFirst();
          debug('Dequeued operation, remaining: ${state.length}');
          return item;
        });

        // If no item, we're done
        if (item == null) break;

        // Process the item outside the mutex
        await _processItem(item);
      }
    } catch (e) {
      error('Error in auto-dequeue process: $e');

      // Ensure dequeuing flag is reset even on error
      await _queue.use((state) async {
        state.isDequeuing = false;
      });

      rethrow;
    }

    debug('Auto-dequeue process completed');
  }

  /// Processes a single queue item with retry logic.
  ///
  /// This method attempts to execute the operation up to [maxRetries] + 1
  /// times (initial attempt plus retries). If all attempts fail, the
  /// operation's future is completed with an error.
  ///
  /// **Parameters:**
  /// - [item]: The queue node containing the operation to process
  ///
  /// **Retry Logic:**
  /// 1. Attempt operation execution
  /// 2. If successful, complete the future with the result
  /// 3. If failed and retries remaining, log error and retry
  /// 4. If failed with no retries left, complete future with error
  ///
  /// **Error Logging:** Each retry attempt is logged for debugging
  /// purposes. The final failure (after all retries) is logged as an error.
  Future<void> _processItem(InternalQueueNode item) async {
    debug('Processing queue item (max retries: $maxRetries)');

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        debug('Attempt ${attempt + 1}/${maxRetries + 1}');

        final result = await item.action();
        item.resolve(result);

        debug('Operation completed successfully on attempt ${attempt + 1}');
        return;
      } catch (e, stackTrace) {
        final isLastAttempt = attempt == maxRetries;

        if (isLastAttempt) {
          error('Operation failed after ${attempt + 1} attempts: $e');
          item.reject(e, stackTrace);
          return;
        } else {
          warning('Operation failed on attempt ${attempt + 1}, retrying: $e');
        }
      }
    }
  }

  /// Clears all pending operations from the queue.
  ///
  /// This method removes all queued operations and completes their
  /// futures with a cancellation error. It's useful for cleanup
  /// scenarios or when you need to abort all pending work.
  ///
  /// **Warning:** This operation cannot be undone. All pending operations
  /// will be cancelled and their callers will receive errors.
  ///
  /// **Example:**
  /// ```dart
  /// // Cancel all pending operations
  /// final cancelledCount = await queue.clear();
  /// print('Cancelled $cancelledCount operations');
  /// ```
  ///
  /// **Returns:** The number of operations that were cancelled
  ///
  /// **Thread Safety:** This method is thread-safe and will not
  /// interfere with currently executing operations.
  Future<int> clear() async {
    debug('Clearing queue');

    return await _queue.use((state) async {
      final cancelledCount = state.length;

      // Cancel all pending operations
      while (state.isNotEmpty) {
        final item = state.queue.removeFirst();
        item.reject(Exception('Operation cancelled - queue cleared'));
      }

      info('Cleared $cancelledCount operations from queue');
      return cancelledCount;
    });
  }

  /// Disposes of this queue and cancels all pending operations.
  ///
  /// After calling this method, the queue should not be used for any
  /// further operations. All pending operations will be cancelled.
  ///
  /// **Example:**
  /// ```dart
  /// // Clean shutdown
  /// await queue.dispose();
  /// ```
  ///
  /// **Thread Safety:** This method is thread-safe and ensures
  /// proper cleanup of all resources.
  Future<void> dispose() async {
    info('Disposing auto queue');

    final cancelledCount = await clear();

    await _queue.use((state) async {
      state.isDequeuing = false;
    });

    debug('Auto queue disposed, cancelled $cancelledCount operations');
  }
}

