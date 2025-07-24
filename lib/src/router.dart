import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'automodule.dart';
import 'events.dart';
import 'logger.dart';
import 'modules.dart';

class InternalRouter with Loggable {
  static final _instance = InternalRouter._internal();

  @override
  List<String> get loggerTags => ["router"];

  final List<ModuleEnum> _history = [];

  Module get _current => moduleManager.current!;

  ModuleEnum? get current => _history.lastOrNull;

  InternalRouter._internal();

  void init(ModuleEnum defaultModule) {
    router._history.add(defaultModule);
  }

  Future<T> push<T>(Widget widget) => _current.push(widget);

  void pop<T>([T? value]) => _current.pop(value);

  goto(ModuleEnum moduleName) {
    _history.add(moduleName);
    _goto();
  }

  _goto() {
    if (_history.isEmpty) return;
    if (!moduleManager.actives.containsKey(_history.last.name)) return;
    info('current module ${_history.last.name}');
    events.emit<String>(
      ['router', 'change', _history.last.name].join(Events.sep),
      '',
    );
    // events.router.change.id(_history.last.name).emit<String>('');
  }

  goBack() {
    if (_history.isEmpty) {
      throw Exception(
        "Stai provando a tornare indietro quando lo stack e' vuoto",
      );
    }
    info('Before go back ${_history.map((c) => c.name)}');
    _history.removeLast();
    info("Go back to ${_history.last.name}");
    _goto();
  }

  clear() {
    info("Clearing the module ${_current.name}");
    _current.clear();
  }
}

final router = InternalRouter._instance;
