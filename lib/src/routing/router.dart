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

import 'package:flutter/cupertino.dart';
import 'package:mosaic/mosaic.dart';

class InternalRouter with Loggable {
  @override
  List<String> get loggerTags => ['router'];

  final Semaphore _navigation = Semaphore();

  bool _disposed = false;

  final List<RouteHistoryEntry> _history = [];

  /// This is the stack of the navigation history throw modules
  ///
  /// When you change the module, an entry will pushed here
  /// When you go to the previous module with (calling [goBack]) the entry will popped
  /// and the [push] call will be completed
  List<RouteHistoryEntry> get history => List.unmodifiable(_history);

  Module get _current => mosaic.registry.current;

  /// Returns the current module
  ///
  /// By default it is null and setted during initialization
  /// If it is not initialized it throws [RouterException]
  String get current {
    if (_history.isEmpty) {
      throw RouterException(
        'Current module does not exists',
        cause: 'Stack history has no entries',
        fix: 'Push something before',
      );
    }
    return _history.last.module;
  }

  /// Initialize the router with the default module
  ///
  /// It ensure that the history has one entry.
  /// This function should be called during module initialization
  void init(String defaultModule) {
    final entry = RouteHistoryEntry(defaultModule);
    mosaic.router._history.add(entry);
  }

  /// Push a widget into the current module
  ///
  /// Call this function to push a page in the stack of the module
  /// Parameters:
  /// * [widget] is the widget to be rendered
  /// Returns a [Future] and return the value passed from the [pop] function (the value is optional)
  Future<T> push<T>(Widget widget) => _current.push(widget);

  /// It pops the last entry from the current module stack
  ///
  /// It removes the last entry.
  /// Parameters:
  /// * [value] it is the value that will be passed to the corresponding [push] function
  void pop<T>([T? value]) => _current.pop(value);

  /// Function to change the current module
  ///
  /// Push an entry into the global stack and change the current module into the passed [moduleName]
  /// Parameters:
  /// * [moduleName] the module you want to go
  /// * [value] you can pass data through modules' transition
  ///
  /// If the router is disposed throws [RouterException]
  Future<void> go<T>(String moduleName, [T? value]) async {
    if (_disposed) {
      throw RouterException('Router was disposed');
    }
    await _navigation.lock();
    try {
      Module? from;
      if (_history.isNotEmpty) {
        from = _tryGetModule(_history.last.module);
      }
      _handleMaxHistoryEntries();
      _history.add(RouteHistoryEntry(moduleName));

      _goto(from: from, params: value);
    } finally {
      _navigation.release();
    }
  }

  void _validateModuleStatus(Module module) {
    if (module.state != ModuleLifecycleState.active) {
      throw RouterException(
        'Module ${module.name} is not active',
        fix: 'Activate the module by calling ${module.name}.activate()',
      );
    }
  }

  void _handleMaxHistoryEntries() {
    if (_history.length <= RouteHistoryEntry.maxDepth) return;
    final count = _history.length - RouteHistoryEntry.maxDepth;
    for (int i = 0; i < count; i++) {
      _history.removeAt(0);
    }
  }

  void _goto<T>({Module? from, T? params}) {
    if (_history.isEmpty) return;
    final module = _history.last.module;
    if (!mosaic.registry.activeModules.containsKey(module)) return;

    info('current module ${_history.last.module}');

    final to = _tryGetModule(module);

    _validateModuleStatus(to);

    final ctx = RouteTransitionContext(from: from, to: to, params: params);

    mosaic.registry.currentModule = _history.last.module;
    mosaic.events.emit<RouteTransitionContext>(
      ['router', 'change', module].join(mosaic.events.separator),
      ctx,
    );
  }

  Module _tryGetModule(String m) {
    if (!mosaic.registry.activeModules.containsKey(m)) {
      throw RouterException(
        'Module $m not registered or not active.',
        cause: 'Bad initialization or deactivated by configuration',
        fix: 'try to activate the module $m',
      );
    }
    return mosaic.registry.activeModules[m]!;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw RouterException('Router was disposed');
    }
  }

  /// This is used to go to the previous module
  ///
  /// Parameters:
  /// * [value] Value passed into this function will be available from the corresponding [go] call
  /// that will be completed
  /// If you call this function after dispose it throws [RouterException]
  void goBack<T>([T? value]) {
    _checkDisposed();
    if (_history.isEmpty) {
      throw RouterException('Cannot go back', cause: 'Stack history is empty');
    }

    info('Before go back ${_history.map((c) => c.module)}');

    final from = _history.removeLast();

    info('Go back to ${_history.last.module}');

    _goto(from: _tryGetModule(from.module), params: value);
    if (from.completer.isCompleted) {
      throw RouterException('Bad state, ${from.module} is already completed');
    }
    from.completer.complete(value);
  }

  /// This method clear the navigation stack of the current module
  ///
  /// Use this method to return to the initial page of the module
  /// By calling this function all the Future of [Module.push] will be completed.
  void clear() {
    info('Clearing the module ${_current.name}');
    _current.clear();
  }

  /// Dispose all the entries accumulated and clear the stack.
  ///
  /// All Future will be completed and cleared.
  /// Each stack of the module will be deleted.
  /// After colling this function the router will be unusable because every operation will throws [RouterException]
  void dispose() {
    if (_disposed) {
      warning('Router already disposed');
      return;
    }
    _disposed = true;
    for (final entry in _history) {
      entry.completer.complete();
    }
    _history.clear();
    _navigation.release();
  }
}
