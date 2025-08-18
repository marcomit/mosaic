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

import 'package:flutter/material.dart';

import 'package:mosaic/mosaic.dart';
import 'package:mosaic/src/events/events_mixin.dart';
import 'package:mosaic/src/modules/module_manager.dart';
import 'package:mosaic/src/routing/route_context.dart';

class MosaicScope extends StatefulWidget {
  const MosaicScope({super.key});

  @override
  State<MosaicScope> createState() => _MosaicScopeState();
}

class _MosaicScopeState extends State<MosaicScope> with Admissible {
  int _currentIndex = -1;
  List<Widget> modules = [];
  String? get _currentModule => moduleManager.currentModule;

  set _currentModule(String? value) {
    moduleManager.currentModule = value;
  }

  void _triggerListener(RouteTransitionContext ctx) {
    if (_currentModule == null) return;
    final module = moduleManager.activeModules[_currentModule];
    if (module == null) return;
    module.onActive(ctx);
  }

  @override
  void initState() {
    super.initState();

    _currentModule = moduleManager.defaultModule;
    _setIndex();

    on<Key>('router/push', _refresh);
    on<Key>('router/pop', _refresh);
    on<RouteTransitionContext>('router/change/*', changeRoute);

    for (final module in moduleManager.activeModules.values) {
      modules.add(module.build(context));
    }
  }

  void changeRoute(EventContext<RouteTransitionContext> ctx) {
    if (!context.mounted) return;
    final transition = ctx.data;

    if (transition == null) return;

    _currentModule = ctx.params[0];

    _triggerListener(transition);
    _setIndex();
    _refresh(ctx);
  }

  void _refresh<T>(EventContext<T> ctx) {
    if (mounted) setState(() {});
  }

  void _setIndex() {
    final keys = moduleManager.activeModules.keys;
    for (int i = 0; i < keys.length; i++) {
      if (_currentModule == keys.elementAt(i)) {
        _currentIndex = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listModules = moduleManager.activeModules.values.toList();

    return Scaffold(
      body: IndexedStack(
        index: _currentModule == null ? 0 : _currentIndex + 1,
        children: [defaultPage(), ...listModules.indexed.map(stack)],
      ),
    );
  }

  Widget stack((int, Module) tuple) {
    final (index, module) = tuple;
    final children = [modules[index], ...module.stack];
    if (children.isEmpty) return const SizedBox();
    return IndexedStack(index: children.length - 1, children: children);
  }

  Widget defaultPage() {
    return const Center(child: Text('No module selected'));
  }
}
