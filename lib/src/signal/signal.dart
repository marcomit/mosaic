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

typedef SignalCallback<T> = void Function(T);
typedef SignalListener = Object;

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
/// Note:
/// Signals don't depend on flutter, you can use signals without importing flutter.
///
/// See also:
/// * [AsyncSignal] for handling asynchronous operations
/// * [computed] for derived state
/// * [combine] for combining multiple signals
class Signal<T> {
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

  T _state;
  bool _disposed = false;
  final Map<SignalListener, Signal> _derived = {};
  bool _shouldNotify = true;
  final Map<SignalListener, SignalCallback<T>> _listeners = {};

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
    onChanged(_state, newValue);
    _state = newValue;
    if (_shouldNotify) notify();
  }

  void notify() {
    for (final listener in _listeners.values) {
      try {
        listener(_state);
      } catch (err) {
        // Log error without blocking other listeners
      }
    }
  }

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
  /// // Basic watch/unwatch changes
  /// final listener = counter.watch((value) => print('New value: $value'));
  /// counter.unwatch(listener);
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
  SignalListener watch(SignalCallback callback) {
    if (_disposed) {
      throw SignalException(
        'Called watch after the signal was disposed.',
        cause: 'Missing unwatch call',
        fix: 'Ensure you unwatch the signal on dispose',
      );
    }
    final token = Object();
    _listeners[token] = callback;
    return token;
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

    _listeners.clear();

    for (final sig in _derived.values) {
      sig.dispose();
    }
    _derived.clear();
    _disposed = true;
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
  void unwatch(Object watcher) => _listeners.remove(watcher);

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

    final key = watch((value) {
      computedSignal.state = compute(value);
    });

    _derived[key] = computedSignal;

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

    void update(_) {
      combined.state = combinator(_state, other._state);
    }

    final key = watch(update);
    final otherKey = other.watch(update);

    _derived[key] = combined;
    other._derived[otherKey] = combined;

    return combined;
  }
}
