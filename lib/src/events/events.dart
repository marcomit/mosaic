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
import 'dart:math';

import 'package:mosaic/exceptions.dart';

import '../logger/logger.dart';

/// Contains information passed to a listener when an event is emitted.
///
/// [T] represents the optional type of data associated with the event.
///
/// Example:
/// ```dart
/// events.on<String>('user/login', (context) {
///   print('Event: ${context.name}');
///   print('Data: ${context.data}');
///   print('Params: ${context.params}');
/// });
/// ```
class EventContext<T> {
  /// Creates a new event context.
  const EventContext(this.data, this.name, this.params);

  /// Data passed with the event, may be null.
  final T? data;

  /// Full name (or channel) of the emitted event.
  final String name;

  /// Parameters extracted from the path when using wildcards (`*` or `#`).
  final List<String> params;

  @override
  String toString() =>
      'EventContext(name: $name, data: $data, params: $params)';
}

// Represents a listener registered to a specific channel or pattern.
///
/// Supports dynamic patterns using special characters:
/// - `*`: matches any single segment
/// - `#`: matches all remaining segments (global match)
///
/// Example:
/// ```dart
/// // Listen to specific user
/// events.on('user/123/update', callback);
///
/// // Listen to any user update
/// events.on('user/*/update', callback);
///
/// // Listen to all user events
/// events.on('user/#', callback);
/// ```
class EventListener<T> {
  /// Creates a new event listener.
  EventListener(this.path, this.callback);

  /// Channel representation as a list of segments.
  final List<String> path;

  /// Callback invoked when a matching event is emitted.
  final EventCallback<T> callback;

  /// Checks if a given channel matches this listener.
  ///
  /// Supports wildcards `*` and `#`.
  bool _verify(List<String> channel) {
    if (path.isEmpty && channel.isEmpty) return true;

    final len = min(channel.length, path.length);
    for (int i = 0; i < len; i++) {
      if (path[i] == '#') return true;
      if (path[i] == '*') continue;
      if (channel[i] != path[i]) return false;
    }
    return channel.length == path.length;
  }

  /// Extracts dynamic parameters from the event path
  /// when using `*` or `#` wildcards.
  List<String> _getParams(List<String> channel) {
    final List<String> res = [];
    int pathIndex = 0;

    for (int i = 0; i < channel.length && pathIndex < path.length; i++) {
      if (pathIndex >= path.length) break;

      if (path[pathIndex] == '#') {
        return [...res, ...channel.sublist(i)];
      } else if (path[pathIndex] == '*') {
        res.add(channel[i]);
      }
      pathIndex++;
    }
    return res;
  }

  @override
  String toString() => 'EventListener(path: ${path.join('/')})';
}

/// Type for a callback function that receives an event context.
typedef EventCallback<T> = void Function(EventContext<T>);

/// Global event manager with support for dynamic channels.
///
/// Accessible through the [events] singleton instance.
///
/// Features:
/// - Wildcard pattern matching with `*` and `#`
/// - Retained events for late subscribers
/// - Type-safe event handling
/// - Comprehensive logging integration
///
/// Example:
/// ```dart
/// // Register listener
/// final listener = events.on<String>('user/login', (context) {
///   print('User logged in: ${context.data}');
/// });
///
/// // Emit event
/// events.emit<String>('user/login', 'john_doe');
///
/// // Remove listener
/// events.deafen(listener);
/// ```
class Events {
  Events._internal();

  /// Segment separator for channels (default: `/`).
  static String sep = '/';

  static final _instance = Events._internal();

  final List<EventListener> _listeners = [];

  final Map<String, dynamic> _retained = {};

  /// Registers a listener on a specific channel.
  ///
  /// The channel can contain `*` for a wildcard segment or `#` for all
  /// remaining segments. The callback will receive an [EventContext] when
  /// the event is emitted.
  ///
  /// If there are retained events for matching channels, the callback
  /// will be called immediately with those events.
  ///
  /// Parameters:
  /// * [channel]: Event channel pattern (e.g., 'user/*/update')
  /// * [callback]: Function to call when matching events are emitted
  ///
  /// Returns an [EventListener] that can be used to remove the listener.
  ///
  /// Example:
  /// ```dart
  /// final listener = events.on<User>('user/profile/update', (context) {
  ///   print('Profile updated: ${context.data?.name}');
  /// });
  /// ```
  EventListener<T> on<T>(String channel, EventCallback<T> callback) {
    if (channel.isEmpty) throw EventException('Channel cannot be empty');

    final listener = EventListener<T>(channel.split(sep), callback);

    _deliverRetainedEvents<T>(listener, channel);

    _listeners.add(listener);
    logger.info(
      'Registered listener for \'$channel\' (${_listeners.length} total)',
      ['events'],
    );
    return listener;
  }

  /// Rigisters a listener on a specific channel and use it only one time.
  ///
  /// Parameters:
  /// * [channel]: Event channel pattern (see [on] method for clarification)
  /// * [callback] Function to call when matching events are emitted
  ///
  /// When an event match the channel it runs the callback and remove the listener (use once)
  /// You can use the method like [on] method
  ///
  /// Example:
  /// ```dart
  /// events.once<int>('counter/add', (context) {
  ///   print('The counter is incremented ${context.data}');
  /// })
  /// ```
  void once<T>(String channel, EventCallback<T> callback) {
    final Completer<void> completer = Completer();

    final listener = on(channel, (EventContext<T> ctx) {
      callback(ctx);
      completer.complete();
    });

    completer.future.then((_) => deafen(listener));
  }

  void _deliverRetainedEvents<T>(EventListener<T> listener, String channel) {
    for (final route in _retained.keys) {
      final path = route.split(sep);

      if (!listener._verify(path)) continue;

      try {
        final data = _retained[route];
        if (data is! T || data == null) continue;
        final context = EventContext<T>(
          data as T?,
          channel,
          listener._getParams(path),
        );

        listener.callback(context);
      } catch (e) {
        logger.error(
          'Error delivering retained event \'$route\' to listener: $e',
          ['events'],
        );
      }
    }
  }

  /// Emits an event on the specified channel.
  ///
  /// All listeners with matching patterns will receive the event.
  ///
  /// Parameters:
  /// * [channel]: Channel path with segments separated by [sep]
  /// * [data]: Optional data to pass to listeners
  /// * [retain]: Whether to retain this event for future listeners
  ///
  /// Example:
  /// ```dart
  /// // Simple event
  /// events.emit('user/logout');
  ///
  /// // Event with data
  /// events.emit<String>('user/login', 'john_doe');
  ///
  /// // Retained event
  /// events.emit<bool>('app/ready', true, true);
  /// ```
  void emit<T>(String channel, [T? data, bool retain = false]) {
    if (channel.isEmpty) {
      logger.warning('Attempted to emit event on empty channel', ['events']);
      return;
    }

    final path = channel.split(sep);
    logger.info('Emitting \'$channel\'${retain ? ' (retained)' : ''}', [
      'events',
    ]);

    if (retain) {
      _retained[channel] = data;
    }

    int notifiedCount = 0;

    for (final listener in _listeners) {
      if (!listener._verify(path)) continue;

      try {
        if (listener is EventListener<T>) {
          final context = EventContext<T>(
            data,
            channel,
            listener._getParams(path),
          );
          listener.callback(context);
          notifiedCount++;
        } else {
          final context = EventContext<dynamic>(
            data,
            channel,
            listener._getParams(path),
          );
          listener.callback(context);
          notifiedCount++;
        }
      } catch (e) {
        logger.error('Error in event listener for \'$channel\': $e', [
          'events',
        ]);
      }
    }
    logger.debug('Notified $notifiedCount listeners for \'$channel\'', [
      'events',
    ]);
  }

  /// Removes a specific listener.
  ///
  /// The listener will no longer receive events after being removed.
  ///
  /// Example:
  /// ```dart
  /// final listener = events.on('user/login', callback);
  /// // Later...
  /// events.deafen(listener);
  /// ```
  void deafen<T>(EventListener<T> listener) {
    final wasRemoved = _listeners.remove(listener);
    if (wasRemoved) {
      logger.info('Removed listener (${_listeners.length} remaining)', [
        'events',
      ]);
    } else {
      logger.warning('Attempted to remove non-existent listener', ['events']);
    }
  }

  /// Removes the most recently registered listener.
  ///
  /// **Note**: This method should be used with caution as it may remove
  /// unexpected listeners if the registration order is not carefully managed.
  void pop() {
    if (_listeners.isNotEmpty) {
      _listeners.removeLast();
      logger.info('Popped listener (${_listeners.length} remaining)', [
        'events',
      ]);
    } else {
      logger.warning('Attempted to pop from empty listener list', ['events']);
    }
  }

  /// Removes all listeners and retained events.
  ///
  /// This method is useful for cleanup during application shutdown
  /// or when resetting the event system.
  void clear() {
    final listenerCount = _listeners.length;
    final retainedCount = _retained.length;

    _listeners.clear();
    _retained.clear();

    logger.info(
      'Cleared $listenerCount listeners and $retainedCount retained events',
      ['events'],
    );
  }

  /// Removes all retained events.
  ///
  /// New listeners will not receive previously retained events after
  /// calling this method.
  void clearRetained() {
    final count = _retained.length;
    _retained.clear();
    logger.info('Cleared $count retained events', ['events']);
  }

  // Returns the number of registered listeners.
  int get listenerCount => _listeners.length;

  /// Returns the number of retained events.
  int get retainedEventCount => _retained.length;

  /// Returns a copy of all retained event channels.
  List<String> get retainedChannels => List.unmodifiable(_retained.keys);

  @override
  String toString() =>
      'Events(listeners: ${_listeners.length}, retained: ${_retained.length})';
}

/// Global event manager instance.
final events = Events._instance;
