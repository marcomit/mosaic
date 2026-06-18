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

import 'package:mosaic/mosaic.dart';

/// A type-safe descriptor for an event channel.
///
/// Raw `emit`/`on` are stringly-typed: a typo or a payload-type mismatch only
/// fails at runtime (and the bus silently drops listeners whose generic type
/// doesn't match the emit). An [EventChannel] binds the channel [path] and its
/// payload type [T] together once, so emitting and listening are checked by the
/// compiler and always agree on the type.
///
/// Use it for the well-known channels in your app; keep raw strings for fully
/// dynamic cases.
///
/// ```dart
/// class UserLoggedIn extends EventChannel<User> {
///   const UserLoggedIn();
///   @override
///   String get path => 'user/login';
/// }
///
/// const userLoggedIn = UserLoggedIn();
/// userLoggedIn.emit(user);                 // typed emit
/// userLoggedIn.watch((ctx) => use(ctx.data)); // typed listen
/// ```
abstract class EventChannel<T> {
  const EventChannel();

  /// The channel path (segments separated by [Events.sep], default `/`).
  ///
  /// For [emit] this must be a concrete path; for [watch]/[once] it may contain
  /// `*`/`#` wildcards.
  String get path;

  /// Emits [data] on this channel. See [Events.emit].
  void emit(T data, {bool retain = false}) =>
      mosaic.events.emit<T>(path, data, retain);

  /// Listens on this channel. See [Events.on].
  EventListener<T> watch(EventCallback<T> callback) =>
      mosaic.events.on<T>(path, callback);

  /// Listens once, then auto-removes. See [Events.once].
  void once(EventCallback<T> callback) => mosaic.events.once<T>(path, callback);

  /// Completes with the next payload emitted on this channel. See [Events.wait].
  Future<T> wait() => mosaic.events.wait<T>(path);
}
