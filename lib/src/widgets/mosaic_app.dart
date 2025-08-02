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
import 'package:mosaic/src/events/events.dart';
import 'package:mosaic/src/modules/modules.dart';
import 'package:mosaic/src/routing/route_context.dart';

class MosaicApp extends StatefulWidget {
  const MosaicApp({super.key, required this.modules, this.defaultModule});

  final List<Module> modules;
  final String? defaultModule;

  @override
  State<MosaicApp> createState() => _MosaicAppState();
}

class _MosaicAppState extends State<MosaicApp> {
  final List<EventListener> _listeners = [];

  @override
  void initState() {
    super.initState();
    final change = events.on<RouteTransitionContext>('router/change', _refresh);
    final push = events.on<RouteTransitionContext>('router/push', _refresh);
    final pop = events.on<RouteTransitionContext>('router/pop', _refresh);
    _listeners.add(change);
    _listeners.add(push);
    _listeners.add(pop);
  }

  @override
  void dispose() {
    _listeners.forEach(events.deafen);
    super.dispose();
  }

  void _refresh<T>(EventContext<T> ctx) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(children: widget.modules.map(moduleEntry).toList()),
    );
  }

  Widget moduleEntry(Module module) {
    final children = [module.build(context), ...module.stack];
    return IndexedStack(index: children.length - 1, children: children);
  }
}
