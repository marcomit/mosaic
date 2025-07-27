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

import '../../exceptions.dart';

import '../events/events.dart';

/// A reactive state container that notifies listeners when its value changes.
///
/// Signals provide a simple way to manage reactive state in your application.
/// When the state changes, all registered listeners are automatically notified.
///
/// Example:
/// ```dart
/// final counter = Signal<int>(0);
///
/// counter.watch((value) {
///   print('Counter changed to: $value');
/// });
///
/// counter.state = 5; // Prints: Counter changed to: 5
/// ```
///
/// Signals integrate with the Mosaic event system and can be used across
/// modules for shared state management.
///
/// See also:
/// * [AsyncSignal] for handling asynchronous operations
/// * [computed] for derived state
/// * [combine] for combining multiple signals
class Signal<T> {
  T _state;
  bool _disposed = false;
  final Set<Signal> _derived = {};
  bool _shouldNotify = true;
  final Map<Object, EventListener<T>> _listeners = {};

  /// The current value of this signal.
  ///
  /// Setting this property will update the signal's state and notify all
  /// listeners if the new value is different from the current value.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal<int>(0);
  /// print(counter.state); // 0
  /// counter.state = 5;    // Triggers notifications
  /// ```
  T get state => _state;

  /// Updates the signal's state and notifies listeners if the value changed.
  ///
  /// If [newValue] is equal to the current state (using `==`), no notification
  /// is sent and listeners are not called.
  set state(T newValue) {
    if (_state == newValue) return;
    _state = newValue;
    if (_shouldNotify) notify();
  }

  String get _eventChannel =>
      ['shared', 'state', identityHashCode(this)].join(Events.sep);

  /// Creates a new signal with the given [initial] value.
  ///
  /// The signal will immediately have this value and will notify listeners
  /// when it changes.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal<int>(0);
  /// final message = Signal<String>('Hello');
  /// ```
  Signal(T initial) : _state = initial;

  /// Emits an event to notify all listeners of the current state.
  ///
  /// This method manually triggers notifications to all registered listeners
  /// with the current state value. It's automatically called when the state
  /// changes, but can be called manually if needed.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal<int>(5);
  /// signal.notify(); // Manually trigger notifications
  /// ```
  ///
  /// **Note:** This uses the Mosaic event system with retained messages,
  /// so new listeners will immediately receive the current state.
  void notify() => events.emit<T>(_eventChannel, _state, true);

  /// Registers a listener that will be called whenever this signal's state changes.
  ///
  /// The [callback] function receives the new value when the state changes.
  /// The optional [watcher] parameter can be used to identify this listener
  /// for later removal with [unwatch].
  ///
  /// If a listener with the same [watcher] key already exists, this method
  /// does nothing.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal<int>(0);
  ///
  /// // Basic watching
  /// counter.watch((value) => print('New value: $value'));
  ///
  /// // With custom watcher for cleanup
  /// final myWatcher = Object();
  /// counter.watch((value) => updateUI(value), myWatcher);
  ///
  /// // Later, remove this specific listener
  /// counter.unwatch(myWatcher);
  /// ```
  ///
  /// See also:
  /// * [unwatch] to remove listeners
  /// * [dispose] to remove all listeners
  void watch([void Function(T)? callback, Object? watcher]) {
    if (_disposed) {
      throw SignalException(
        "Called watch after the signal wad disposed.",
        cause: "Missing unwatch call",
        fix: "Ensure you unwatch the signal on dispose",
      );
    }
    watcher ??= Object();

    if (_listeners.containsKey(watcher)) return;

    final l = events.on<T>(
      _eventChannel,
      (ctx) => _handleStateChange(ctx, callback),
    );

    _listeners[watcher] = l;
  }

  /// Removes all listeners and cleans up resources.
  ///
  /// After calling dispose, this signal should not be used. Any attempt
  /// to watch or modify the signal after disposal may result in undefined
  /// behavior.
  ///
  /// This method should be called when the signal is no longer needed,
  /// typically in a module's cleanup phase or widget's dispose method.
  ///
  /// Example:
  /// ```dart
  /// class MyModule extends Module {
  ///   final counter = Signal<int>(0);
  ///
  ///   @override
  ///   void dispose() {
  ///     counter.dispose();
  ///     super.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// See also:
  /// * [unwatch] to remove individual listeners
  void dispose() {
    if (_disposed) return;
    for (final listener in _listeners.values) {
      events.deafen(listener);
    }
    for (final sig in _derived) {
      sig.dispose();
    }
    _derived.clear();
    _listeners.clear();
    _disposed = true;
  }

  void _handleStateChange(EventContext<T> ctx, void Function(T)? callback) {
    final T? v = ctx.data;
    if (v == null) return;
    final old = _state;
    state = v;
    if (callback != null) callback(state);
    onChanged(old, state);
  }

  /// Override this method to react to state changes.
  ///
  /// This method is called automatically whenever the signal's state changes
  /// to a different value. It provides both the previous and new values,
  /// making it useful for logging, validation, or triggering side effects.
  ///
  /// The method is called after the state has been updated but before
  /// listeners are notified.
  ///
  /// Example:
  /// ```dart
  /// class CounterSignal extends Signal<int> {
  ///   CounterSignal(super.initial);
  ///
  ///   @override
  ///   void onChanged(int oldValue, int newValue) {
  ///     print('Counter changed from $oldValue to $newValue');
  ///
  ///     // Trigger side effects
  ///     if (newValue > 10) {
  ///       events.emit('counter/threshold_reached', newValue);
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Parameters:
  /// * [oldValue]: The previous state value
  /// * [newValue]: The new state value that triggered this change
  void onChanged(T oldValue, T newValue) {}

  /// Removes a specific listener from this signal.
  ///
  /// The [watcher] parameter should match the one used when calling [watch].
  /// If no [watcher] is provided, a default watcher object will be used.
  ///
  /// If no listener exists for the given [watcher], this method does nothing.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal<int>(0);
  /// final myWatcher = Object();
  ///
  /// // Register listener
  /// counter.watch((value) => print(value), myWatcher);
  ///
  /// // Later, remove it
  /// counter.unwatch(myWatcher);
  /// ```
  ///
  /// See also:
  /// * [watch] to add listeners
  /// * [dispose] to remove all listeners
  void unwatch([Object? watcher]) {
    final id = watcher ?? Object();
    final l = _listeners.remove(id);
    if (l != null) events.deafen(l);
  }

  /// Returns the current state value.
  ///
  /// This is a convenience method equivalent to accessing [state].
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(5);
  /// print(counter()); // 5 (same as counter.state)
  /// ```
  T call() => state;

  /// Executes multiple state updates in a batch, sending only one notification.
  ///
  /// During the execution of [callback], state changes will not trigger
  /// notifications. After the callback completes, a single notification
  /// is sent with the final state value.
  ///
  /// This is useful for performance when making multiple related updates:
  ///
  /// ```dart
  /// final counter = Signal<int>(0);
  ///
  /// counter.batch((currentValue) {
  ///   counter.state = 1;   // No notification
  ///   counter.state = 2;   // No notification
  ///   counter.state = 3;   // No notification
  ///   return currentValue * 2;
  /// }); // Single notification sent here with value 3
  /// ```
  ///
  /// The [callback] receives the current state value and can return a result
  /// of type [R], which is returned by this method.
  ///
  /// **Note:** If [callback] throws an exception, notifications will still
  /// be re-enabled and a final notification will be sent.
  ///
  /// Returns the result of calling [callback].
  R batch<R>(R Function(T) callback) {
    _shouldNotify = false;
    R res;
    try {
      res = callback(_state);
    } finally {
      _shouldNotify = true;
      notify();
    }
    return res;
  }

  /// Creates a computed signal that automatically recalculates when this signal changes.
  ///
  /// The returned signal will automatically update its value whenever this
  /// signal's state changes, using the provided [compute] function to
  /// derive the new value.
  ///
  /// **Important:** The computed signal maintains a reference to this signal.
  /// Make sure to properly dispose of computed signals to avoid memory leaks.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal<int>(2);
  /// final squared = counter.computed((value) => value * value);
  ///
  /// print(squared.state); // 4
  ///
  /// counter.state = 3;
  /// print(squared.state); // 9 (automatically updated)
  /// ```
  ///
  /// The [compute] function receives the current value of this signal
  /// and should return the computed result of type [R].
  ///
  /// Returns a new [Signal] that will automatically stay in sync with
  /// this signal's state.
  ///
  /// See also:
  /// * [combine] for combining multiple signals
  Signal<R> computed<R>(R Function(T) compute) {
    final computedSignal = Signal(compute(_state));

    watch((value) {
      computedSignal.state = compute(value);
    });

    _derived.add(computedSignal);

    return computedSignal;
  }

  /// Creates a combined signal from two source signals.
  ///
  /// The [other] signal to combine with this one.
  /// The [combinator] function that takes values from both signals
  /// and returns the combined result.
  ///
  /// Returns a new signal that updates whenever either source signal changes.
  Signal<R> combine<R, U>(Signal<U> other, R Function(T, U) combinator) {
    final combined = Signal(combinator(_state, other._state));

    void update() {
      combined.state = combinator(_state, other._state);
    }

    watch((_) => update());
    other.watch((_) => update());

    _derived.add(combined);

    return combined;
  }
}

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
      T? data = state.data;
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
  String toString() => "Signal<$T>($state)";
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
    if (loading) return "AsyncStatus.loading()";
    if (isError) return "AsyncStatus.error($error)";
    if (success) return "AsyncStatus.success($data)";
    return "AsyncStatus.stale()";
  }
}
