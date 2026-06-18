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

/// Factory that lazily constructs a [Module] the first time it is needed.
///
/// May be synchronous or asynchronous, allowing deferred-import code splitting
/// (`import '...' deferred as ...`) before the module instance is built.
typedef ModuleFactory = FutureOr<Module> Function();

/// Internal record describing a module that has been registered lazily but not
/// yet constructed.
class _LazyModule {
  _LazyModule({
    required this.name,
    required this.factory,
    required this.dependencies,
    required this.provides,
    this.gate,
  });

  final String name;
  final ModuleFactory factory;
  final List<String> dependencies;
  final List<Type> provides;
  final ModuleGate? gate;
}

/// Manages all modules in the application and provides centralized control
/// over module lifecycle, error handling, and state management.
class ModuleManager with Loggable {
  @override
  List<String> get loggerTags => ['module_manager'];

  Module? _defaultModule;

  /// Name of the currently active module.
  String? _currentModule;

  String? get currentModule => _currentModule;

  set currentModule(String? module) {
    if (module != null && !_modules.containsKey(module)) {
      throw ModuleException(
        'Invalid current module',
        cause:
            'Trying to set the current module to $module but it is not registered',
        fix: 'Try to register or recover it',
      );
    }
    _currentModule = module;
  }

  /// All registered modules (read-only view).
  final Map<String, Module> _modules = {};

  /// Modules registered lazily, keyed by name, awaiting their first load.
  final Map<String, _LazyModule> _lazy = {};

  /// Names currently being loaded, used to detect lazy dependency cycles.
  final Set<String> _loading = {};

  /// Name of the default module to use when none is specified.
  Module? get defaultModule => _defaultModule;

  /// Only active modules (read-only view).
  Map<String, Module> get activeModules {
    return Map.unmodifiable(
      Map.fromEntries(_modules.entries.where((entry) => entry.value.active)),
    );
  }

  /// Getter of all modules (unmodifiable)
  Map<String, Module> get modules => Map.unmodifiable(_modules);

  /// Names of every registered module, whether eager or lazy.
  Set<String> get registeredNames => {..._modules.keys, ..._lazy.keys};

  /// Whether a module with [name] is known to the manager (eager or lazy).
  bool isRegistered(String name) =>
      _modules.containsKey(name) || _lazy.containsKey(name);

  /// Whether [name] was registered lazily and has not been constructed yet.
  bool isLazy(String name) => _lazy.containsKey(name);

  /// Whether [name] has been constructed (its instance exists).
  bool isLoaded(String name) => _modules.containsKey(name);

  /// Whether [name] is loaded and currently in the active state.
  bool isActive(String name) => _modules[name]?.active ?? false;

  /// The currently active module, if any.
  Module get current {
    if (currentModule == null) {
      throw ModuleException(
        'Current module does not set! Consider setting it before!',
      );
    }
    if (!_modules.containsKey(currentModule)) {
      throw RouterException('Current module does not exists');
    }
    return _modules[currentModule]!;
  }

  /// Unregisters a module with the manager
  ///
  /// **Parameters:**
  /// * [module] the module to unregister.
  ///
  /// **Note:**
  /// * This method trigger the [Module.onDispose] function
  ///
  /// **Throws:**
  /// * [ModuleException] if the module is not already registered
  Future<void> unregister(Module module) async {
    if (!_modules.containsKey(module.name)) {
      throw ModuleException(
        'Trying to unregister an unregistered module ${module.name}',
      );
    }
    await module.dispose();
    _modules.remove(module.name);
    if (currentModule == module.name) {
      currentModule = null;
    }
    info('Module ${module.name} unregistered');
  }

  /// Initialize all registered modules
  ///
  /// It try to load modules sorted by dependencies.
  /// It means that a module wait that all dependencies are initialized.
  ///
  /// **Throws:**
  /// * [ModuleException] If it detect a circular dependency
  Future<void> initialize(Module start, Iterable<Module> toInitialize) async {
    _defaultModule = start;
    final sorted = _sortByDeps(toInitialize);

    for (final module in toInitialize) {
      if (!modules.containsKey(module.name)) {
        throw ModuleException('Module ${module.name} is not registered');
      }
    }

    for (final module in sorted) {
      await activateModule(module);
    }
    mosaic.router.init(start.name);
  }

  /// This is an implementation of topological sort with DFS
  ///
  /// At each node:
  /// * Checks if it is already visiting (circular dependencies).
  /// * Checks if it is already resolved
  /// * Navigate each dependencies
  /// * Resolve it (add the node to the result and remove the node from the visiting)
  ///
  /// **Throws:**
  /// * [ModuleException] If it detect a circular dependency
  List<Module> _sortByDeps(Iterable<Module> modules) {
    final sorted = <Module>[];
    final resolved = <String>{};
    final visiting = <String>{};

    void visit(Module m) {
      if (resolved.contains(m.name)) return;

      if (visiting.contains(m.name)) {
        throw ModuleException(
          'Circular dependency detected',
          cause: 'This was the circle ${visiting.join(' -> ')}',
        );
      }
      visiting.add(m.name);

      m.dependencies.forEach(visit);

      sorted.add(m);
      resolved.add(m.name);
      visiting.remove(m.name);
    }

    modules.forEach(visit);

    return sorted;
  }

  /// Registers a new module with the manager.
  ///
  /// **Parameters:**
  /// * [module] - The module to register
  ///
  /// **Throws:**
  /// * [ModuleException] if a module with the same name already exists
  Future<void> register(Module module) async {
    if (_modules.containsKey(module.name)) {
      throw ModuleException('Module ${module.name} is already registered');
    }

    _modules[module.name] = module;
    info('Registered module ${module.name}');
  }

  /// Registers a module lazily: it is not constructed or initialized until it
  /// is first navigated to or explicitly [load]ed.
  ///
  /// This keeps startup cheap and lets large applications defer the cost of
  /// rarely-used features. Combine with [gate] for feature-flagged or
  /// remotely-controlled availability.
  ///
  /// **Parameters:**
  /// * [name] - Unique identifier for the module (must match `Module.name`)
  /// * [factory] - Builds the module instance on first use (may be async)
  /// * [dependencies] - Names of modules that must be loaded & initialized first
  /// * [provides] - Contract types this module exposes; declaring them lets
  ///   [ContractRegistry.resolve] load this module on demand
  /// * [gate] - Optional predicate; when it returns `false` the module is
  ///   considered unavailable and [load] throws
  ///
  /// **Throws:**
  /// * [ModuleException] if a module with the same name is already registered
  ///
  /// **Example:**
  /// ```dart
  /// mosaic.registry.registerLazy(
  ///   'checkout',
  ///   () => CheckoutModule(),
  ///   dependencies: ['cart'],
  ///   provides: [CheckoutContract],
  ///   gate: mosaic.features.gate('new_checkout'),
  /// );
  /// ```
  void registerLazy(
    String name,
    ModuleFactory factory, {
    List<String> dependencies = const [],
    List<Type> provides = const [],
    ModuleGate? gate,
  }) {
    if (isRegistered(name)) {
      throw ModuleException('Module $name is already registered');
    }
    _lazy[name] = _LazyModule(
      name: name,
      factory: factory,
      dependencies: dependencies,
      provides: provides,
      gate: gate,
    );
    for (final type in provides) {
      mosaic.contracts.declareLazyProviderType(type, name);
    }
    info('Registered lazy module $name');
  }

  /// Resolves whether a lazily-registered module is currently available.
  ///
  /// Evaluates the module's [ModuleGate] (if any). Already-loaded or eager
  /// modules are always considered available.
  Future<bool> isAvailable(String name) async {
    final lazy = _lazy[name];
    if (lazy?.gate == null) return isRegistered(name);
    return lazy!.gate!();
  }

  /// Constructs, registers and initializes a lazily-registered module.
  ///
  /// Lazy dependencies are loaded first (depth-first, with cycle detection),
  /// then the [ModuleGate] is evaluated, then the factory runs and the module
  /// is initialized. If the module was already loaded it is returned as-is.
  ///
  /// **Throws:**
  /// * [ModuleException] if [name] is not registered, is gated off, or a
  ///   circular lazy dependency is detected
  Future<Module> load(String name) async {
    final existing = _modules[name];
    if (existing != null) return existing;

    final lazy = _lazy[name];
    if (lazy == null) {
      throw ModuleException(
        'Cannot load module $name',
        cause: 'No lazy registration found',
        fix: 'Call registerLazy(\'$name\', ...) first',
      );
    }

    if (_loading.contains(name)) {
      throw ModuleException(
        'Circular lazy dependency detected',
        cause: 'While loading ${_loading.join(' -> ')} -> $name',
        moduleName: name,
      );
    }

    if (lazy.gate != null && !(await lazy.gate!())) {
      throw ModuleException(
        'Module $name is gated off',
        cause: 'Its feature gate evaluated to false',
        fix: 'Enable the backing feature flag before loading $name',
        moduleName: name,
      );
    }

    _loading.add(name);
    try {
      for (final dep in lazy.dependencies) {
        await load(dep);
      }

      final module = await lazy.factory();
      if (module.name != name) {
        throw ModuleException(
          'Lazy factory for $name produced module "${module.name}"',
          cause: 'The constructed module name must match the registered name',
          fix: 'Use the same name in registerLazy and the Module constructor',
        );
      }

      _modules[name] = module;
      _lazy.remove(name);
      await module.initialize();
      info('Lazily loaded module $name');
      return module;
    } finally {
      _loading.remove(name);
    }
  }

  /// Ensures a module is loaded and active, loading it lazily if required.
  ///
  /// Returns the active module instance. Used by the router to transparently
  /// bring lazy modules online when they are navigated to.
  ///
  /// **Throws:**
  /// * [ModuleException] if the module cannot be loaded or activated
  Future<Module> ensureActive(String name) async {
    if (!_modules.containsKey(name)) {
      if (_lazy.containsKey(name)) {
        await load(name);
      } else {
        throw ModuleException(
          'Module $name is not registered',
          fix: 'Register it with register() or registerLazy() first',
        );
      }
    }
    final module = _modules[name]!;
    if (!module.active) {
      await activateModule(module);
    }
    return module;
  }

  /// Activates a module, making it the current active module.
  ///
  /// **Parameters:**
  /// * [name] - Name of the module to activate
  ///
  /// **Throws:**
  /// * [ArgumentError] if the module doesn't exist
  /// * [ModuleException] if activation fails
  Future<void> activateModule(Module module) async {
    if (module.state == ModuleLifecycleState.uninitialized) {
      await module.initialize();
    } else if (module.state == ModuleLifecycleState.suspended) {
      await module.resume();
    } else if (module.state == ModuleLifecycleState.error) {
      final recovered = await module.recover();
      if (!recovered) {
        throw ModuleException(
          'Failed to recover module ${module.name}',
          moduleName: module.name,
        );
      }
    }

    currentModule = module.name;

    module.onActive(RouteTransitionContext(to: module));
    info('Activated module ${module.name}');

    mosaic.events.emit<String>(
      ['module_manager', 'module_activated'].join(mosaic.events.sep),
      module.name,
    );
  }

  /// Suspends a module without disposing it.
  ///
  /// **Parameters:**
  /// * [name] - Name of the module to suspend
  Future<void> suspendModule(String name) async {
    final module = _modules[name];
    if (module != null && module.active) {
      await module.suspend();
      info('Suspended module $name');
    }
  }

  /// Disposes all modules and cleans up resources.
  Future<void> disposeAll() async {
    info('Disposing all modules');

    final futures = _modules.values.map((module) => module.dispose());
    await Future.wait(futures);

    _modules.clear();
    _lazy.clear();
    _loading.clear();
    currentModule = null;
    _defaultModule = null;

    info('All modules disposed');
  }

  /// Gets module health status for monitoring.
  Map<String, Map<String, dynamic>> getHealthStatus() {
    return Map.fromEntries(
      _modules.entries.map((entry) {
        final module = entry.value;
        return MapEntry(entry.key, {
          'state': module.state.name,
          'active': module.active,
          'hasError': module.hasError,
          'lastError': module.lastError?.toString(),
          'stackDepth': module.stackDepth,
        });
      }),
    );
  }
}
