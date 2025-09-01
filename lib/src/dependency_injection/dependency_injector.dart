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

import 'package:mosaic/src/logger/logger.dart';
import '../../exceptions.dart';

final global = DependencyInjector();

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
class DependencyInjector {
  final Map<Type, Function()> _instances = {};

  final Map<Type, Object Function()> _toLazy = {};
  final Map<Type, Object> _cached = {};

  List<Object> get instances {
    final List<Object> result = [];
    final Set<Type> seen = {};
    for (final entry in _instances.entries) {
      seen.add(entry.key);
      result.add(entry.value);
    }
    for (final entry in _cached.entries) {
      if (seen.contains(entry.key)) continue;
      result.add(entry.value);
    }
    return result;
  }

  /// Checks if a dependency type is already registered in the given map.
  ///
  /// Throws [DependencyException] if the type [T] already exists.
  void _checkIfAbsent<T extends Object>(Map<Type, Function()> map) {
    if (!map.containsKey(T)) return;
    throw DependencyException(
      'Dependency $T already registered',
      fix: 'If you want to replace consider the use of override<T>()',
    );
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
  void put<T extends Object>(T instance) {
    _checkIfAbsent<T>(_instances);
    _checkIfAbsent<T>(_toLazy);
    _instances[T] = () => instance;
  }

  /// Registers a lazy builder that will cache the result only the first time [get] is called.
  ///
  /// The [builder] function is called only once, on the first call to [get<T>()].
  /// Subsequent calls return the cached instance. This is ideal for expensive-to-create
  /// services that should be singletons but don't need to be created immediately.
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
  void factory<T extends Object>(T Function() builder) {
    _checkIfAbsent<T>(_instances);
    _checkIfAbsent<T>(_toLazy);
    _instances[T] = builder;
  }

  /// Registers a factory function that will return a new instance every time [get] is called.
  ///
  /// A new instance will be created on every call to [get<T>()].
  /// This is ideal for stateless services or when you need fresh instances.
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
  void lazy<T extends Object>(T Function() builder) {
    _checkIfAbsent(_toLazy);
    _checkIfAbsent<T>(_toLazy);
    _toLazy[T] = builder;
  }

  /// Replaces an existing dependency with a new instance.
  ///
  /// This method bypasses the duplicate registration check and replaces
  /// any existing registration for type [T]. Useful for testing scenarios
  /// or when you need to update dependencies at runtime.
  ///
  /// Note: This only affects future calls to [get<T>()]. If the dependency
  /// was registered with [lazy] and already cached, you may need to call
  /// [remove<T>()] first to clear the cache.
  ///
  /// Example:
  /// ```dart
  /// di.put<ApiService>(ProductionApiService());
  /// di.override<ApiService>(MockApiService()); // Replace for testing
  /// ```
  void override<T extends Object>(T instance) {
    _instances[T] = () => instance;
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
  bool contains<T>() {
    if (_toLazy.containsKey(T)) return true;
    if (_cached.containsKey(T)) return true;
    if (_instances.containsKey(T)) return true;
    return false;
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
    _instances.clear();
    _toLazy.clear();
    _cached.clear();
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
  T get<T extends Object>() {
    if (_toLazy.containsKey(T)) {
      _cached[T] = _toLazy[T]!();
      return _cached[T]! as T;
    }

    if (_instances.containsKey(T)) {
      return _instances[T]!();
    }

    throw DependencyException(
      'Dependency $T does not exists in this container. ',
      fix: 'Try to use put<$T>() before calling it.',
    );
  }

  /// Removes the dependency registration for type [T].
  ///
  /// This removes the dependency from all internal maps (instances, lazy builders, and cache).
  /// If the dependency was not registered, logs a warning instead of throwing an exception.
  ///
  /// After removal, calls to [get<T>()] will throw [DependencyException] until
  /// the dependency is registered again.
  ///
  /// Example:
  /// ```dart
  /// di.remove<UserService>(); // Remove registration
  /// // di.get<UserService>(); // Would throw DependencyException
  /// ```
  void remove<T>() {
    bool res = _removeIfPresent<T>(_toLazy);
    res |= _removeIfPresent<T>(_cached);
    res |= _removeIfPresent<T>(_instances);
    if (!res) {
      logger.warning('Trying to remove $T but is not a registered dependency', [
        'dependency',
      ]);
    }
  }

  /// Helper method to remove a type from a map if it exists.
  ///
  /// Returns `true` if the type was found and removed, `false` otherwise.
  bool _removeIfPresent<T>(Map<Type, Object> map) => map.remove(T) != null;

  /// It is the equivalent to call [get]
  ///
  /// Example:
  /// ```dart
  /// final userService = di<UserService>(); // same as di.get<UserService>();
  /// ```
  T call<T extends Object>() => get<T>();
}
