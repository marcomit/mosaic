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
import 'package:mosaic/src/mosaic.dart';

import 'events.dart';

/// Base class for building event topic paths with chaining support.
///
/// Segments allow you to construct event topics by chaining method calls,
/// making it easy to build complex event paths programmatically.
///
/// Example:
/// ```dart
/// class UserSegment extends Segment {
///   UserSegment() : super('user');
/// }
///
/// final userEvents = UserSegment();
/// userEvents.$('profile').$('update').emit<String>('John Doe');
/// ```
abstract class Segment {
  /// Creates a new segment with the given base [topic].
  Segment(this.topic);

  /// The current topic path being built.
  String topic;

  /// Appends a new segment to the current topic path.
  ///
  /// If the current topic is not empty, adds the event separator before
  /// the new segment. Returns this segment for method chaining.
  ///
  /// Example:
  /// ```dart
  /// final segment = MySegment('user');
  /// segment.$('profile').$('update'); // Results in 'user/profile/update'
  /// ```
  Segment $(String data) {
    if (topic.isNotEmpty) topic += mosaic.events.sep;
    topic += data;
    return this;
  }

  /// Emits an event on the current topic path.
  ///
  /// Parameters:
  /// * [data]: Optional data to send with the event
  /// * [retain]: Whether to retain this event for future listeners
  ///
  /// Example:
  /// ```dart
  /// segment.$('user').$('login').emit<String>('user123');
  /// ```
  void emit<T>([T? data, bool retain = false]) =>
      mosaic.events.emit<T>(topic, data, retain);

  /// Registers a listener for events on the current topic path.
  ///
  /// Returns an [EventListener] that can be used to remove the listener later.
  ///
  /// Example:
  /// ```dart
  /// final listener = segment.$('user').$('login').on<String>((ctx) {
  ///   print('User logged in: ${ctx.data}');
  /// });
  ///
  /// // Later, remove the listener
  /// events.deafen(listener);
  /// ```
  EventListener<T> on<T>(EventCallback<T> callback) =>
      mosaic.events.on<T>(topic, callback);

  /// Waits for a single event on the current topic path.
  ///
  /// This method will wait until one event is received on the topic,
  /// call the provided callback, and then automatically remove the listener.
  ///
  /// **Note**: This method will wait indefinitely until an event is received.
  /// Use with caution to avoid hanging operations.
  ///
  /// Example:
  /// ```dart
  /// await segment.$('user').$('login').waitForEvent<String>((ctx) {
  ///   print('Received login event: ${ctx.data}');
  /// });
  /// ```
  Future<void> waitForEvent<T>(EventCallback<T> callback) async {
    final completer = Completer<void>();

    late EventListener<T> listener;
    listener = on<T>((ctx) {
      try {
        callback(ctx);
      } finally {
        mosaic.events.deafen(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  /// Waits for a single event and returns the event data.
  ///
  /// This is a convenience method that waits for one event and returns
  /// the data from that event.
  ///
  /// Example:
  /// ```dart
  /// final userData = await segment.$('user').$('login').waitForData<String>();
  /// print('User: $userData');
  /// ```
  Future<T?> waitForData<T>() async {
    final completer = Completer<T?>();

    late EventListener<T> listener;
    listener = on<T>((ctx) {
      mosaic.events.deafen(listener);
      if (!completer.isCompleted) {
        completer.complete(ctx.data);
      }
    });

    return completer.future;
  }

  @override
  String toString() => 'Segment(\'$topic\')';
}

/// Mixin that adds ID-based path building to segments.
///
/// This mixin provides the [id] method for appending ID parameters
/// to the topic path, commonly used for resource identification.
///
/// Example:
/// ```dart
/// class UserSegment extends Segment with Id {
///   UserSegment() : super('user');
/// }
///
/// final userEvents = UserSegment();
/// userEvents.id('123').$('profile').emit<Map>({'name': 'John'});
/// // Results in topic: 'user/123/profile'
/// ```
mixin Id on Segment {
  /// Appends an ID parameter to the current topic path.
  ///
  /// This is equivalent to calling `$(param)` but provides semantic clarity
  /// when dealing with resource IDs.
  ///
  /// Returns this segment for method chaining.
  ///
  /// Example:
  /// ```dart
  /// segment.id('user123').$('update'); // 'user/user123/update'
  /// ```
  Segment id(String param) {
    $(param);
    return this;
  }
}

/// Mixin that adds multi-parameter path building to segments.
///
/// This mixin provides the [params] method for appending multiple
/// path segments at once.
///
/// Example:
/// ```dart
/// class ApiSegment extends Segment with Param {
///   ApiSegment() : super('api');
/// }
///
/// final apiEvents = ApiSegment();
/// apiEvents.params(['v1', 'users', '123']).emit<User>(userData);
/// // Results in topic: 'api/v1/users/123'
/// ```
mixin Param on Segment {
  /// Appends multiple parameters to the current topic path.
  ///
  /// All parameters are joined with the event separator and appended
  /// to the current topic.
  ///
  /// Returns this segment for method chaining.
  ///
  /// Example:
  /// ```dart
  /// segment.params(['api', 'v1', 'users']); // 'base/api/v1/users'
  /// ```
  Segment params(List<String> params) {
    topic = [topic, ...params].join(mosaic.events.sep);
    return this;
  }
}
