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
import 'package:mosaic/src/mosaic.dart';

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
    final List<String> params = [];

    for (int i = 0; i < channel.length && i < path.length; i++) {
      if (i >= path.length) break;

      if (path[i] == '#') {
        return [...params, ...channel.sublist(i)];
      } else if (path[i] == '*') {
        params.add(channel[i]);
      }
    }
    return params;
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
  Events([this.sep = '/']);

  /// Segment separator for channels (default: `/`).
  String sep;

  String? _namespace;
  Events? _parent;

  final List<EventListener> _selfGlobalListeners = [];
  final Map<int, List<EventListener>> _selfFixedLengthListeners = {};
  final Map<String, List<EventListener>> _selfStaticListeners = {};

  final Map<String, dynamic> _selfRetained = {};

  List<EventListener> get _globalListeners {
    if (_parent != null) return _parent!._globalListeners;
    return _selfGlobalListeners;
  }

  Map<int, List<EventListener>> get _fixedLengthListeners {
    if (_parent != null) return _parent!._fixedLengthListeners;
    return _selfFixedLengthListeners;
  }

  Map<String, List<EventListener>> get _staticListeners {
    if (_parent != null) return _parent!._staticListeners;
    return _selfStaticListeners;
  }

  Map<String, dynamic> get _retained {
    if (_parent != null) return _parent!._retained;
    return _selfRetained;
  }

  List<EventListener> _getMatchingListeners(List<String> path) {
    final listeners = <EventListener>[];

    listeners.addAll(_staticListeners[path.join(sep)] ?? []);

    for (final listener in _fixedLengthListeners[path.length] ?? []) {
      if (listener._verify(path)) listeners.add(listener);
    }

    for (final listener in _globalListeners) {
      if (listener._verify(path)) listeners.add(listener);
    }
    return listeners;
  }

  void _registerListener(EventListener listener) {
    if (listener.path.contains('#')) {
      _globalListeners.add(listener);
    } else if (listener.path.contains('*')) {
      _fixedLengthListeners
          .putIfAbsent(listener.path.length, () => [])
          .add(listener);
    } else {
      _staticListeners
          .putIfAbsent(listener.path.join(sep), () => [])
          .add(listener);
    }
  }

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
    final path = <String>[];
    if (_namespace != null) path.add(_namespace!);
    path.addAll(channel.split(sep).where((s) => s.isNotEmpty).toList());
    if (channel.isEmpty) throw EventException('Channel cannot be empty');

    final listener = EventListener<T>(path, callback);

    _deliverRetainedEvents<T>(listener, channel);
    _registerListener(listener);

    return listener;
  }

  /// Registers a listener on a specific channel and use it only one time.
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
      if (!completer.isCompleted) completer.complete();
    });

    completer.future.then((_) => deafen(listener));
  }

  /// Waits the event and return the data received.
  ///
  /// Parameters:
  /// * [channel]: is the channel of the event
  ///
  /// Example:
  /// ```dart
  /// final user = events.wait<User>('user/update');
  /// ```
  Future<T> wait<T>(String channel) {
    final data = Completer<T>();

    once<T>(channel, (ctx) {
      if (ctx.data == null) return;
      data.complete(ctx.data);
    });

    return data.future;
  }

  void _deliverRetainedEvents<T>(EventListener<T> listener, String channel) {
    for (final route in _retained.keys) {
      final path = route.split(sep);

      if (!listener._verify(path)) continue;

      try {
        final data = _retained[route];
        if (data == null && null is! T) continue;
        if (data != null && data is! T) continue;
        final context = EventContext<T>(
          data as T?,
          channel,
          listener._getParams(path),
        );

        listener.callback(context);
      } catch (e) {
        mosaic.logger.error(
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
  ///
  /// Performance considerations:
  /// Listeners are stored in 3 different way:
  /// 1. Static listeners that does not contains wildcard.
  ///   Emitting a static listener is O(1).
  /// 2. Listeners that contains only '*' wildcard.
  ///   It takes O(m) where m is listeners that has m segments.
  /// 3. Listeners with # wildcard.
  ///   For this type of listener is O(n).
  void emit<T>(String channel, T data, [bool retain = false]) {
    if (_namespace != null) {
      channel = _namespace! + sep + channel;
    }
    final path = channel.split(sep).where((s) => s.isNotEmpty).toList();

    if (path.isEmpty) {
      throw EventException('Invalid channel after normalization');
    }

    if (retain) {
      _retained[channel] = data;
    }

    final listeners = _getMatchingListeners(path);

    for (final listener in listeners) {
      try {
        final context = EventContext<T>(
          data,
          channel,
          listener._getParams(path),
        );
        if (listener is! EventListener<T>) {
          mosaic.logger.warning(
            'Type mismatch: Expected EventListener<$T>, found ${listener.runtimeType}',
            ['events'],
          );
          continue;
        }
        listener.callback(context);
      } catch (e) {
        mosaic.logger.error('Error in event listener for \'$channel\': $e', [
          'events',
        ]);
      }
    }
  }

  /// Uses a prefix for emit and receive events.
  ///
  /// It puts the [prefix] when [emit] and [on] are called.
  ///
  /// Example:
  /// ```dart
  /// final userEvents = events.namespace('user');
  /// userEvents.on('login', callback); // It listen on 'user/login'
  /// ```
  ///
  /// This namespace is also used inside a module.
  ///
  /// Example:
  /// ```dart
  /// class UserModule extends Module {
  ///   UserModule() : Module(name: 'user');
  ///
  ///   void someMethod() {
  ///     on('login', callback);
  ///   }
  ///   ... rest of the code.
  /// }
  /// ```
  Events namespace(String prefix) {
    final event = Events();
    event._namespace = prefix;
    if (_namespace != null) {
      event._namespace = '$_namespace$sep$prefix';
    }
    event._parent = _parent ?? this;
    return event;
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
    if (listener.path.contains('#')) {
      _globalListeners.remove(listener);
    } else if (listener.path.contains('*')) {
      final list = _fixedLengthListeners[listener.path.length];
      list?.remove(listener);
      if (list != null && list.isEmpty) {
        _fixedLengthListeners.remove(listener.path.length);
      }
    } else {
      final key = listener.path.join(sep);
      final list = _staticListeners[key];
      list?.remove(listener);
      if (list != null && list.isEmpty) {
        _staticListeners.remove(key);
      }
    }
  }

  /// Removes all listeners and retained events.
  ///
  /// This method is useful for cleanup during application shutdown
  /// or when resetting the event system.
  void clear() {
    _globalListeners.clear();
    _fixedLengthListeners.clear();
    _staticListeners.clear();
    _retained.clear();
  }

  /// Removes all retained events.
  ///
  /// New listeners will not receive previously retained events after
  /// calling this method.
  void clearRetained() {
    // final count = _retained.length;
    _retained.clear();
    // mosaic.logger.info('Cleared $count retained events', ['events']);
  }

  // Returns the number of registered listeners.
  int get listenerCount {
    int res = _globalListeners.length;
    for (final listeners in _fixedLengthListeners.values) {
      res += listeners.length;
    }
    for (final listeners in _staticListeners.values) {
      res += listeners.length;
    }
    return res;
  }

  /// Returns the number of retained events.
  int get retainedEventCount => _retained.length;

  /// Returns a copy of all retained event channels.
  List<String> get retainedChannels => List.unmodifiable(_retained.keys);

  @override
  String toString() =>
      'Events(listeners: $listenerCount, retained: ${_retained.length})';
}
