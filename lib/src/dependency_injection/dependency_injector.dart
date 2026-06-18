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

import 'package:mosaic/src/mosaic.dart';
import '../../exceptions.dart';

/// A dependency injection container that manages object lifecycles and provides
/// type-safe dependency resolution.
///
/// Supports three types of dependency registration:
/// - [put]: Singleton instances (created once, reused always)
/// - [factory]: Transient instances (new instance every time)
/// - [lazy]: Lazy singletons (created once on first access, then cached)
///
/// Example usage:
/// ```dart
/// final di = DependencyInjector();
///
/// // Register dependencies
/// di.put<DatabaseService>(DatabaseServiceImpl());
/// di.factory<HttpClient>(() => HttpClient());
/// di.lazy<ExpensiveService>(() => ExpensiveService());
///
/// // Retrieve dependencies
/// final database = di.get<DatabaseService>();
/// final client = di.get<HttpClient>(); // New instance each time
/// final expensive = di.get<ExpensiveService>(); // Created on first access
/// ```
/// Composite key for a registration: the dependency type plus an optional
/// [name] qualifier, so multiple instances of the same type can coexist.
typedef _Key = (Type, String?);

class DependencyInjector {
  /// Eagerly-provided singletons ([put]) and resolved lazy/async singletons.
  final Map<_Key, Object> _singletons = {};

  /// Transient builders ([factory]) invoked on every [get].
  final Map<_Key, Object Function()> _factories = {};

  /// Lazy-singleton builders ([lazy]) invoked once, then promoted to
  /// [_singletons] and removed from here.
  final Map<_Key, Object Function()> _lazyBuilders = {};

  /// Async singleton builders ([putAsync]) resolved by [getAsync], then
  /// promoted to [_singletons].
  final Map<_Key, Future<Object> Function()> _asyncBuilders = {};

  /// All currently-instantiated objects: eager singletons plus any lazy or
  /// async singletons that have been resolved.
  ///
  /// Transient ([factory]) registrations and not-yet-resolved [lazy]/[putAsync]
  /// registrations are not included because no instance exists for them.
  List<Object> get instances => List.unmodifiable(_singletons.values);

  /// Throws [DependencyException] if `(T, name)` is already registered.
  void _assertAbsent<T extends Object>(String? name) {
    final key = (T, name);
    if (_singletons.containsKey(key) ||
        _factories.containsKey(key) ||
        _lazyBuilders.containsKey(key) ||
        _asyncBuilders.containsKey(key)) {
      throw DependencyException(
        'Dependency $T${name == null ? '' : ' (name: $name)'} already registered',
        fix: 'If you want to replace consider the use of override<T>()',
      );
    }
  }

  /// Registers a singleton instance that will be returned every time [get] is called.
  ///
  /// The same [instance] will be returned on every call to [get<T>()].
  /// This is ideal for stateful services that should be shared across the application.
  ///
  /// Throws [DependencyException] if [T] is already registered.
  /// Use [override] if you need to replace an existing dependency.
  ///
  /// Example:
  /// ```dart
  /// di.put<UserService>(UserServiceImpl());
  /// final service1 = di.get<UserService>(); // Same instance
  /// final service2 = di.get<UserService>(); // Same instance (service1 == service2)
  /// ```
  /// Optionally pass [name] to register a *qualified* instance, allowing
  /// several registrations of the same type (e.g. two `HttpClient`s).
  void put<T extends Object>(T instance, {String? name}) {
    _assertAbsent<T>(name);
    _singletons[(T, name)] = instance;
  }

  /// Registers a factory function that returns a new instance every time
  /// [get] is called.
  ///
  /// A new instance will be created on every call to [get<T>()]. This is ideal
  /// for stateless services or when you need fresh instances.
  ///
  /// Throws [DependencyException] if [T] is already registered.
  /// Use [override] if you need to replace an existing dependency.
  ///
  /// Example:
  /// ```dart
  /// di.factory<HttpClient>(() => HttpClient());
  /// final client1 = di.get<HttpClient>(); // New instance
  /// final client2 = di.get<HttpClient>(); // Different instance (client1 != client2)
  /// ```
  void factory<T extends Object>(T Function() builder, {String? name}) {
    _assertAbsent<T>(name);
    _factories[(T, name)] = builder;
  }

  /// Registers a lazy builder whose result is cached after the first [get].
  ///
  /// The [builder] is called only once, on the first call to [get<T>()].
  /// Subsequent calls return the cached instance. Ideal for expensive-to-create
  /// services that should be singletons but need not be created immediately.
  ///
  /// Throws [DependencyException] if [T] is already registered.
  /// Use [override] if you need to replace an existing dependency.
  ///
  /// Example:
  /// ```dart
  /// di.lazy<DatabaseConnection>(() => DatabaseConnection.connect());
  /// final conn1 = di.get<DatabaseConnection>(); // Creates and caches
  /// final conn2 = di.get<DatabaseConnection>(); // Returns cached (conn1 == conn2)
  /// ```
  void lazy<T extends Object>(T Function() builder, {String? name}) {
    _assertAbsent<T>(name);
    _lazyBuilders[(T, name)] = builder;
  }

  /// Registers an asynchronous singleton builder, resolved on the first
  /// [getAsync] call and cached thereafter.
  ///
  /// Ideal for dependencies whose creation is inherently async (opening a
  /// database, loading a config file). Resolve it with [getAsync]; once
  /// resolved it is also reachable through the synchronous [get].
  ///
  /// Throws [DependencyException] if `(T, name)` is already registered.
  ///
  /// Example:
  /// ```dart
  /// di.putAsync<Database>(() => Database.open());
  /// final db = await di.getAsync<Database>(); // opens once, then cached
  /// ```
  void putAsync<T extends Object>(
    Future<T> Function() builder, {
    String? name,
  }) {
    _assertAbsent<T>(name);
    _asyncBuilders[(T, name)] = builder;
  }

  /// Replaces any existing registration for type [T] with a new singleton.
  ///
  /// This bypasses the duplicate registration check and removes any prior
  /// singleton, factory, or lazy registration for [T]. Useful for testing or
  /// runtime swaps.
  ///
  /// Example:
  /// ```dart
  /// di.put<ApiService>(ProductionApiService());
  /// di.override<ApiService>(MockApiService()); // Replace for testing
  /// ```
  void override<T extends Object>(T instance, {String? name}) {
    final key = (T, name);
    _factories.remove(key);
    _lazyBuilders.remove(key);
    _asyncBuilders.remove(key);
    _singletons[key] = instance;
  }

  /// Checks if a dependency of type [T] is registered in this container.
  ///
  /// Returns `true` if the dependency exists in any form (singleton, factory, or lazy),
  /// `false` otherwise. This method does not throw exceptions and does not
  /// instantiate lazy dependencies.
  ///
  /// Example:
  /// ```dart
  /// if (di.contains<UserService>()) {
  ///   final service = di.get<UserService>();
  /// } else {
  ///   // Handle missing dependency
  /// }
  /// ```
  bool contains<T>({String? name}) {
    final key = (T, name);
    return _singletons.containsKey(key) ||
        _factories.containsKey(key) ||
        _lazyBuilders.containsKey(key) ||
        _asyncBuilders.containsKey(key);
  }

  /// Clears all registered dependencies and cached instances.
  ///
  /// This removes all registrations and clears the lazy dependency cache.
  /// Useful for testing cleanup or when you need to reset the container state.
  ///
  /// Warning: This will invalidate all existing dependency references.
  /// Use with caution in production code.
  ///
  /// Example:
  /// ```dart
  /// // In test tearDown
  /// di.clear();
  /// ```
  void clear() {
    _singletons.clear();
    _factories.clear();
    _lazyBuilders.clear();
    _asyncBuilders.clear();
  }

  /// Returns the dependency instance for type [T].
  ///
  /// The behavior depends on how the dependency was registered:
  /// - [put]: Returns the same instance every time
  /// - [factory]: Creates and returns a new instance every time
  /// - [lazy]: Creates instance on first call, returns cached instance thereafter
  ///
  /// Throws [DependencyException] if the dependency [T] is not registered.
  /// Use [contains<T>()] to check existence before calling this method.
  ///
  /// Example:
  /// ```dart
  /// final userService = di.get<UserService>();
  /// final httpClient = di.get<HttpClient>();
  /// ```
  T get<T extends Object>({String? name}) {
    final key = (T, name);

    final singleton = _singletons[key];
    if (singleton != null) return singleton as T;

    final lazyBuilder = _lazyBuilders[key];
    if (lazyBuilder != null) {
      final instance = lazyBuilder();
      _singletons[key] = instance;
      _lazyBuilders.remove(key);
      return instance as T;
    }

    final factory = _factories[key];
    if (factory != null) return factory() as T;

    throw DependencyException(
      'Dependency $T${name == null ? '' : ' (name: $name)'} does not exists in this container. ',
      fix: _asyncBuilders.containsKey(key)
          ? 'It is registered asynchronously; resolve it with getAsync<$T>().'
          : 'Try to use put<$T>() before calling it.',
    );
  }

  /// Resolves an asynchronous singleton registered with [putAsync].
  ///
  /// Returns the cached instance if already resolved (or registered eagerly).
  /// Otherwise runs the async builder once, caches the result, and returns it.
  ///
  /// Throws [DependencyException] if no registration exists for `(T, name)`.
  Future<T> getAsync<T extends Object>({String? name}) async {
    final key = (T, name);

    final existing = _singletons[key];
    if (existing != null) return existing as T;

    final builder = _asyncBuilders[key];
    if (builder == null) {
      throw DependencyException(
        'Async dependency $T${name == null ? '' : ' (name: $name)'} is not registered.',
        fix: 'Register it with putAsync<$T>() first.',
      );
    }

    final instance = await builder();
    _singletons[key] = instance;
    _asyncBuilders.remove(key);
    return instance as T;
  }

  /// Removes the dependency registration for type [T].
  ///
  /// This removes the dependency from all internal maps (singletons, factories,
  /// and lazy builders). If the dependency was not registered, logs a warning
  /// instead of throwing an exception.
  ///
  /// After removal, calls to [get<T>()] will throw [DependencyException] until
  /// the dependency is registered again.
  ///
  /// Example:
  /// ```dart
  /// di.remove<UserService>(); // Remove registration
  /// // di.get<UserService>(); // Would throw DependencyException
  /// ```
  void remove<T>({String? name}) {
    final key = (T, name);
    bool res = _singletons.remove(key) != null;
    res |= _factories.remove(key) != null;
    res |= _lazyBuilders.remove(key) != null;
    res |= _asyncBuilders.remove(key) != null;
    if (!res) {
      mosaic.logger.warning(
        'Trying to remove $T but is not a registered dependency',
        ['dependency'],
      );
    }
  }

  /// It is the equivalent to call [get]
  ///
  /// Example:
  /// ```dart
  /// final userService = di<UserService>(); // same as di.get<UserService>();
  /// ```
  T call<T extends Object>({String? name}) => get<T>(name: name);
}
