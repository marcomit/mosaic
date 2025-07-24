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
