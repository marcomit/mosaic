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

/// Manages all modules in the application and provides centralized control
/// over module lifecycle, error handling, and state management.
class ModuleManager with Loggable {
  ModuleManager._internal();

  static final _instance = ModuleManager._internal();

  @override
  List<String> get loggerTags => ['module_manager'];

  /// Map of all registered modules indexed by name.
  // final Map<String, Module> _modules = {};

  Module? _defaultModule;

  /// Name of the currently active module.
  String? currentModule;

  /// All registered modules (read-only view).
  final Map<String, Module> _modules = {};

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

  /// The currently active module, if any.
  Module get current {
    if (currentModule == null) {
      throw ModuleException(
        'Current module does not set! Consider setting it before!',
      );
    }
    if (_modules.containsKey(currentModule)) {
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
  Future<void> initialize(Module start) async {
    _defaultModule = start;
    final sorted = _sortByDeps(modules.values);

    for (final module in sorted) {
      await module.initialize();
    }
    router.init(start.name);
  }

  List<Module> _sortByDeps(Iterable<Module> modules) {
    final sorted = <Module>[];
    final resolved = <String>{};

    void visit(Module m, [Set<String> path = const {}]) {
      if (path.contains(m.name)) {
        throw ModuleException(
          'Circular dependency detected',
          cause: 'This was the circle ${path.join(' -> ')}',
        );
      }

      if (resolved.contains(m.name)) return;

      for (final dep in m.dependencies) {
        visit(dep, {...path, m.name});
      }

      sorted.add(m);
      resolved.add(m.name);
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

    events.emit<String>('module_manager/module_activated', module.name);
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

/// Istanza globale del gestore dei moduli, accessibile ovunque.
final moduleManager = ModuleManager._instance;
