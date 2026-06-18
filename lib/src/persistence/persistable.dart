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
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mosaic/mosaic.dart';

class _PersistBinding {
  _PersistBinding(this.signal);
  final Signal signal;
  late final SignalListener token;
  Timer? timer;
}

/// Adds automatic state persistence to a [Module], built on [Signal]s.
///
/// Call [persist] for each signal you want to survive disposal/restart. On the
/// first call the stored value (if any) is rehydrated into the signal; every
/// subsequent change is written back through [MosaicStorage], debounced to
/// avoid thrashing. Bindings are torn down automatically on dispose.
///
/// Keys are namespaced by module name, so two modules can use the same local
/// key without colliding.
///
/// ```dart
/// class CartModule extends Module with Persistable {
///   CartModule() : super(name: 'cart');
///   final count = Signal<int>(0);
///
///   @override
///   Future<void> onInit() async {
///     await persistJson<int>(count, key: 'count');
///   }
/// }
/// ```
mixin Persistable on Module {
  final List<_PersistBinding> _persistBindings = [];

  /// Persists [signal] under [key], (de)serializing with [encode]/[decode].
  ///
  /// Rehydrates the signal from storage immediately, then writes back on every
  /// change after [debounce] of inactivity.
  Future<void> persist<T>(
    Signal<T> signal, {
    required String key,
    required String Function(T value) encode,
    required T Function(String raw) decode,
    Duration debounce = const Duration(milliseconds: 300),
  }) async {
    final storageKey = _key(key);

    final stored = await mosaic.storage.read(storageKey);
    if (stored != null) {
      try {
        signal.state = decode(stored);
      } catch (e) {
        warning('Failed to rehydrate "$storageKey": $e');
      }
    }

    final binding = _PersistBinding(signal);
    binding.token = signal.watch((value) {
      binding.timer?.cancel();
      binding.timer = Timer(debounce, () {
        mosaic.storage.write(storageKey, encode(value as T));
      });
    });
    _persistBindings.add(binding);
  }

  /// Convenience [persist] for JSON-encodable values (`int`, `String`, `bool`,
  /// `List`, `Map`, …).
  Future<void> persistJson<T>(
    Signal<T> signal, {
    required String key,
    Duration debounce = const Duration(milliseconds: 300),
  }) {
    return persist<T>(
      signal,
      key: key,
      encode: jsonEncode,
      decode: (raw) => jsonDecode(raw) as T,
      debounce: debounce,
    );
  }

  String _key(String key) => 'mosaic/$name/$key';

  /// Flushes pending writes, unwatches signals, and clears bindings.
  ///
  /// Called automatically from [onDispose]; override [onDispose] and call
  /// `super.onDispose()` if you add your own teardown.
  @mustCallSuper
  @override
  FutureOr<void> onDispose() async {
    for (final binding in _persistBindings) {
      binding.timer?.cancel();
      binding.signal.unwatch(binding.token);
    }
    _persistBindings.clear();
    await super.onDispose();
  }
}
