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

import 'package:mosaic/mosaic.dart';

/// Signature for an asynchronous source of feature flag values.
///
/// A resolver is consulted by [FeatureFlags.resolve] when a flag has no local
/// override. Return `null` to indicate the resolver has no opinion about the
/// given [key], allowing the next resolver (or the default value) to decide.
///
/// This is the integration point for remote config providers (Firebase Remote
/// Config, LaunchDarkly, a custom backend, etc.).
typedef FeatureFlagResolver = FutureOr<bool?> Function(String key);

/// Signature for a gate that decides whether a lazy module may be loaded.
///
/// Returning `false` keeps the module unavailable: navigation and explicit
/// [ModuleManager.load] calls will fail with a descriptive [ModuleException].
typedef ModuleGate = FutureOr<bool> Function();

/// A lightweight, reactive feature-flag store.
///
/// Feature flags let you ship code that is conditionally available at runtime,
/// enabling staged rollouts, A/B tests, and kill-switches. Flags can be set
/// locally (overrides) or fetched lazily from remote [FeatureFlagResolver]s.
///
/// The store integrates with the module system: a lazy module can be gated
/// behind a flag so it is only ever constructed and initialized when the flag
/// is enabled.
///
/// ## Example
///
/// ```dart
/// // Local override (e.g. from a debug menu)
/// mosaic.features.enable('new_checkout');
///
/// // Remote source consulted on demand
/// mosaic.features.addResolver((key) async {
///   return await remoteConfig.getBool(key);
/// });
///
/// // Gate a lazy module behind the flag
/// mosaic.registry.registerLazy(
///   'checkout',
///   () => CheckoutModule(),
///   gate: mosaic.features.gate('new_checkout'),
/// );
/// ```
class FeatureFlags with Loggable {
  /// Creates a feature-flag store.
  ///
  /// [defaultValue] is returned by [isEnabled] / [resolve] when no override or
  /// resolver provides a value for a key.
  FeatureFlags({this.defaultValue = false});

  @override
  List<String> get loggerTags => ['features'];

  /// Value used when a flag is neither overridden nor resolved.
  bool defaultValue;

  final Map<String, bool> _overrides = {};
  final List<FeatureFlagResolver> _resolvers = [];

  /// Snapshot of all locally overridden flags (read-only).
  Map<String, bool> get overrides => Map.unmodifiable(_overrides);

  /// Enables [key] locally, overriding any resolver.
  void enable(String key) => set(key, true);

  /// Disables [key] locally, overriding any resolver.
  void disable(String key) => set(key, false);

  /// Sets [key] to [value] locally and notifies listeners.
  void set(String key, bool value) {
    final changed = _overrides[key] != value;
    _overrides[key] = value;
    debug('Flag $key set to $value');
    if (changed) _notify(key, value);
  }

  /// Removes the local override for [key], falling back to resolvers/default.
  void remove(String key) {
    if (_overrides.remove(key) != null) {
      debug('Flag $key override removed');
    }
  }

  /// Clears every local override.
  void clear() => _overrides.clear();

  /// Registers a remote [resolver] consulted by [resolve] for flags without a
  /// local override. Resolvers are consulted in registration order.
  void addResolver(FeatureFlagResolver resolver) => _resolvers.add(resolver);

  /// Synchronously reads [key] from local overrides only.
  ///
  /// Resolvers are not consulted (they may be asynchronous). Use [resolve] to
  /// include remote sources. Returns [defaultValue] when there is no override.
  bool isEnabled(String key) => _overrides[key] ?? defaultValue;

  /// Resolves [key], consulting local overrides first, then resolvers in order,
  /// and finally [defaultValue].
  ///
  /// A resolver that returns `null` is skipped (it has no opinion).
  Future<bool> resolve(String key) async {
    final override = _overrides[key];
    if (override != null) return override;

    for (final resolver in _resolvers) {
      try {
        final value = await resolver(key);
        if (value != null) return value;
      } catch (e) {
        warning('Resolver failed for flag $key: $e');
      }
    }
    return defaultValue;
  }

  /// Builds a [ModuleGate] backed by [key].
  ///
  /// The returned gate resolves the flag (including remote resolvers) each time
  /// the module manager attempts to load the gated module.
  ModuleGate gate(String key) => () => resolve(key);

  void _notify(String key, bool value) {
    mosaic.events.emit<bool>(
      ['features', key].join(mosaic.events.sep),
      value,
      true,
    );
  }
}
