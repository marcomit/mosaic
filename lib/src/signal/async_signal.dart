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

import 'signal.dart';

/// A signal that handles asynchronous operations with built-in loading states.
///
/// AsyncSignal automatically manages loading, success, and error states
/// for async operations. It wraps the result in an [AsyncStatus] that
/// can be easily handled in UI code.
///
/// Example:
/// ```dart
/// final userSignal = AsyncSignal<User>(() async {
///   return await api.fetchUser();
/// }, autorun: true);
///
/// // Handle different states
/// userSignal.then(
///   loading: () => CircularProgressIndicator(),
///   success: (user) => Text('Hello ${user.name}'),
///   error: (err) => Text('Error: $err'),
///   orElse: () => Text('No data'),
/// );
///
/// // Manually refresh
/// await userSignal.fetch();
/// ```
///
/// Parameters:
/// * [autorun]: If true, automatically calls [fetch] during construction
/// * [multifetch]: If true, allows multiple concurrent fetch operations
class AsyncSignal<T> extends Signal<AsyncStatus<T>> {
  /// Creates an async signal with the given data [builder] function.
  ///
  /// Parameters:
  /// * [builder]: Function that returns a Future with the data to load
  /// * [autorun]: If true, automatically calls [fetch] during construction
  /// * [multifetch]: If true, allows multiple concurrent fetch operations
  ///
  /// Example:
  /// ```dart
  /// // Manual fetch
  /// final userSignal = AsyncSignal<User>(() => api.fetchUser());
  /// await userSignal.fetch();
  ///
  /// // Auto-fetch on creation
  /// final autoUserSignal = AsyncSignal<User>(
  ///   () => api.fetchUser(),
  ///   autorun: true,
  /// );
  /// ```
  AsyncSignal(this.builder, {this.autorun = false, this.multifetch = false})
    : super(AsyncStatus.stale()) {
    if (autorun) fetch();
  }

  /// The function used to fetch data asynchronously.
  ///
  /// This function is called by [fetch] to retrieve the data. It should
  /// return a Future that completes with the desired data or throws
  /// an error if the operation fails.
  Future<T> Function() builder;

  /// Whether to automatically start fetching data when the signal is created.
  ///
  /// If true, [fetch] will be called immediately during construction.
  /// If false, you must manually call [fetch] to load data.
  bool autorun;

  /// Whether to allow multiple concurrent fetch operations.
  ///
  /// If false (default), calling [fetch] while already loading will be ignored.
  /// If true, multiple fetch operations can run simultaneously, with the
  /// last one to complete setting the final state.
  bool multifetch;

  /// Executes the builder function and updates the signal's state.
  ///
  /// This method will:
  /// 1. Set the state to loading (unless already loading and [multifetch] is false)
  /// 2. Execute the [builder] function
  /// 3. Set the state to success with the result, or error if an exception occurs
  ///
  /// If the signal is already in a loading state and [multifetch] is false,
  /// this method returns immediately without starting a new fetch operation.
  ///
  /// Example:
  /// ```dart
  /// final userSignal = AsyncSignal<User>(() => api.fetchUser());
  ///
  /// // Trigger data loading
  /// await userSignal.fetch();
  ///
  /// // Check the result
  /// if (userSignal.state.success) {
  ///   print('User loaded: ${userSignal.state.data?.name}');
  /// }
  /// ```
  ///
  /// Throws any exceptions that occur during the fetch operation.
  Future<void> fetch() async {
    if (state.loading && !multifetch) return;
    try {
      state = AsyncStatus.loading();
      final result = await builder();
      state = AsyncStatus.success(result);
    } catch (err) {
      state = AsyncStatus.error(err);
    }
  }

  /// Pattern matching for handling different async states with optional handlers.
  ///
  /// Provides a convenient way to handle async states by providing callbacks
  /// for each possible state. Unlike [when], all parameters are optional
  /// and [orElse] will be called for any state that doesn't have a handler.
  ///
  /// Example:
  /// ```dart
  /// final result = userSignal.then(
  ///   success: (user) => 'Hello ${user.name}',
  ///   loading: () => 'Loading...',
  ///   error: (err) => 'Error: $err',
  ///   orElse: () => 'No data available',
  /// );
  /// ```
  ///
  /// Parameters:
  /// * [success]: Called when data is successfully loaded
  /// * [loading]: Called when a fetch operation is in progress
  /// * [error]: Called when an error occurred during fetching
  /// * [orElse]: Called for any state without a specific handler
  ///
  /// Returns the result of the appropriate callback function.
  R then<R>({
    R Function(T)? success,
    R Function()? loading,
    R Function(Object?)? error,
    required R Function() orElse,
  }) {
    if (state.loading && loading != null) return loading();
    if (state.isError && error != null) return error(state.error);
    if (state.success && success != null) {
      final data = state.data;
      if (data != null) return success(data);
    }
    return orElse();
  }

  /// Pattern matching for handling async states.
  ///
  /// Provides access to the complete [AsyncStatus] object for more advanced
  /// state handling scenarios where you need access to all state information.
  ///
  /// Example:
  /// ```dart
  /// final widget = userSignal.when((status) {
  ///   if (status.loading) return CircularProgressIndicator();
  ///   if (status.isError) return Text('Error: ${status.error}');
  ///   if (status.success) return Text('Hello ${status.data?.name}');
  ///   return Text('No data');
  /// });
  /// ```
  ///
  /// The [onFetching] callback receives the current [AsyncStatus] and should
  /// return a value of type [R].
  ///
  /// Returns the result of calling [onFetching] with the current status.
  R when<R>(R Function(AsyncStatus<T>) onFetching) {
    return onFetching(state);
  }

  @override
  String toString() => 'Signal<$T>($state)';
}

/// Represents the state of an asynchronous operation.
///
/// AsyncStatus wraps the result of async operations with additional
/// metadata about the operation's current state (loading, success, error).
///
/// This class is immutable - all fields are final and cannot be changed
/// after construction.
///
/// Example:
/// ```dart
/// // Check the status
/// if (status.loading) {
///   return CircularProgressIndicator();
/// } else if (status.success) {
///   return Text('Data: ${status.data}');
/// } else if (status.isError) {
///   return Text('Error: ${status.error}');
/// }
/// ```
class AsyncStatus<T> {
  /// Creates a new AsyncStatus in the stale state.
  ///
  /// Stale indicates that no operation has been started yet, or that
  /// the current data is considered outdated and should be refreshed.
  ///
  /// Example:
  /// ```dart
  /// final status = AsyncStatus<User>.stale();
  /// print(status.loading); // false
  /// print(status.success); // false
  /// ```
  const AsyncStatus.stale() : data = null, loading = false, error = null;

  /// Creates a new AsyncStatus in the loading state.
  ///
  /// Loading indicates that an async operation is currently in progress.
  ///
  /// Example:
  /// ```dart
  /// final status = AsyncStatus<User>.loading();
  /// print(status.loading); // true
  /// ```
  const AsyncStatus.loading() : data = null, loading = true, error = null;

  /// Creates a new AsyncStatus in the error state.
  ///
  /// Error indicates that the async operation failed with the given [err].
  ///
  /// Example:
  /// ```dart
  /// final status = AsyncStatus<User>.error('Network timeout');
  /// print(status.isError); // true
  /// print(status.error); // 'Network timeout'
  /// ```
  const AsyncStatus.error(Object err)
    : data = null,
      loading = false,
      error = err;

  /// Creates a new AsyncStatus in the success state.
  ///
  /// Success indicates that the async operation completed successfully
  /// and returned the given [result].
  ///
  /// Example:
  /// ```dart
  /// final user = User(name: 'John');
  /// final status = AsyncStatus<User>.success(user);
  /// print(status.success); // true
  /// print(status.data?.name); // 'John'
  /// ```
  const AsyncStatus.success(T result)
    : data = result,
      loading = false,
      error = null;

  /// The data returned by the async operation, if successful.
  ///
  /// This will be null unless the operation completed successfully.
  /// When [success] is true, this field contains the actual result data.
  final T? data;

  /// Whether the async operation is currently in progress.
  ///
  /// True when the operation has started but not yet completed.
  /// False in all other states (stale, success, error).
  final bool loading;

  /// The error that occurred during the async operation, if any.
  ///
  /// This will be null unless an error occurred during the operation.
  /// When [isError] is true, this field contains the error object.
  final Object? error;

  /// Whether the async operation completed successfully.
  ///
  /// Returns true when [data] is not null, indicating that the operation
  /// finished successfully and returned valid data.
  bool get success => data != null;

  /// Whether the async operation resulted in an error.
  ///
  /// Returns true when [error] is not null, indicating that the operation
  /// failed and an error was captured.
  bool get isError => error != null;

  @override
  String toString() {
    if (loading) return 'AsyncStatus.loading()';
    if (isError) return 'AsyncStatus.error($error)';
    if (success) return 'AsyncStatus.success($data)';
    return 'AsyncStatus.stale()';
  }
}
