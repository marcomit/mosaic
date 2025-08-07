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
import 'package:mosaic/src/modules/module_manager.dart';
import 'package:mosaic/src/routing/route_context.dart';
import 'package:mosaic/src/routing/route_history_entry.dart';

class InternalRouter with Loggable {
  InternalRouter._internal();
  static final _instance = InternalRouter._internal();

  @override
  List<String> get loggerTags => ['souter'];

  final Semaphore _navigation = Semaphore();

  bool _disposed = false;

  final List<RouteHistoryEntry> _history = [];

  Module get _current => moduleManager.current;

  ModuleEnum get current {
    if (_history.isEmpty) {
      throw RouterException(
        'Current module does not exists',
        cause: 'Stack history has no entries',
        fix: 'Push something before',
      );
    }
    return _history.last.module;
  }

  void init(ModuleEnum defaultModule) {
    final entry = RouteHistoryEntry(defaultModule);
    router._history.add(entry);
  }

  Future<T> push<T>(Widget widget) => _current.push(widget);

  void pop<T>([T? value]) => _current.pop(value);

  Future<void> go<T>(ModuleEnum moduleName, [T? value]) async {
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
    if (!moduleManager.activeModules.containsKey(module.name)) return;

    info('current module ${_history.last.module.name}');

    final to = _tryGetModule(module);

    _validateModuleStatus(to);

    final ctx = RouteTransitionContext(from: from, to: to, params: params);

    events.emit<RouteTransitionContext>(
      ['router', 'change', module.name].join(Events.sep),
      ctx,
    );
  }

  Module _tryGetModule(ModuleEnum m) {
    if (!moduleManager.activeModules.containsKey(m.name)) {
      throw RouterException(
        'Module ${m.name} not registered or not active.',
        cause: 'Bad initialization or deactivated by configuration',
        fix: 'try to activate the module ${m.name}',
      );
    }
    return moduleManager.activeModules[m.name]!;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw RouterException('Router was disposed');
    }
  }

  void goBack<T>([T? value]) {
    _checkDisposed();
    if (_history.isEmpty) {
      throw RouterException('Cannot go back', cause: 'Stack history is empty');
    }

    info('Before go back ${_history.map((c) => c.module.name)}');

    final from = _history.removeLast();

    info('Go back to ${_history.last.module.name}');

    _goto(from: _tryGetModule(from.module), params: value);
    if (from.completer.isCompleted) {
      throw RouterException(
        'Bad state, ${from.module.name} is already completed',
      );
    }
    from.completer.complete(value);
  }

  void clear() {
    info('Clearing the module ${_current.name}');
    _current.clear();
  }

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

final router = InternalRouter._instance;
