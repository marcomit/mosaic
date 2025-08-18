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

import 'package:flutter/widgets.dart';
import 'package:mosaic/mosaic.dart';
import 'package:mosaic/src/events/events_mixin.dart';
import 'package:mosaic/src/routing/route_context.dart';

class MosaicScope extends StatefulWidget {
  const MosaicScope({super.key});

  @override
  State<MosaicScope> createState() => _MosaicScopeState();
}

class _MosaicScopeState extends State<MosaicScope> with Admissible {
  final _lock = Semaphore();
  @override
  void initState() {
    super.initState();
    on<RouteTransitionContext>('router/change/*', _changeRoute);
    on<RouteTransitionContext>('router/push', _transit);
    on<RouteTransitionContext>('router/pop', _transit);
  }

  void _transit<T>(EventContext<T> ctx) async {
    if (!mounted || !context.mounted) return;
    await _lock.acquire();
    setState(() {});
    _lock.release();
  }

  void _changeRoute(EventContext<RouteTransitionContext> ctx) {
    final transition = ctx.data;
    if (transition == null) return;
    final target = transition.to;
    target.onActive(transition);
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Navigator(pages: [], onDidRemovePage: (page) {});
  }
}

class ModulePage<T extends Object> extends Page<T> {
  const ModulePage({super.key, required this.moduleName, required this.child});

  final String moduleName;
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
    );
  }
}

class ModuleRouteBuilder extends PageRouteBuilder {
  ModuleRouteBuilder({
    super.settings,
    super.requestFocus,
    super.pageBuilder,
    super.transitionsBuilder,
    super.transitionDuration,
    super.reverseTransitionDuration,
  });
}

class ModuleRoute<T> extends Route<T> {}
