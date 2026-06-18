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

/// Serializable description of the inter-module navigation state.
///
/// Maps to a URL path of `/<module>` for deep-linking and web URL sync.
class MosaicRouteState {
  const MosaicRouteState(this.module);

  /// The active module name, or `null` for the root/empty location.
  final String? module;
}

/// Parses platform route information (URLs, deep links) into a
/// [MosaicRouteState] and back.
class MosaicRouteInformationParser
    extends RouteInformationParser<MosaicRouteState> {
  @override
  Future<MosaicRouteState> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    return MosaicRouteState(segments.isEmpty ? null : segments.first);
  }

  @override
  RouteInformation? restoreRouteInformation(MosaicRouteState configuration) {
    final module = configuration.module;
    return RouteInformation(uri: Uri(path: module == null ? '/' : '/$module'));
  }
}

/// A [RouterDelegate] that renders Mosaic's inter-module history as real
/// [Navigator] pages, giving you page transitions, the system back button /
/// predictive back, and browser URL / deep-link sync.
///
/// This is an **opt-in** alternative to [MosaicScope]. It is driven by the same
/// [InternalRouter] history, so `router.go` / `router.goBack` keep working
/// exactly as before — they now also update the URL and the page stack.
///
/// ```dart
/// runApp(MaterialApp.router(
///   routerDelegate: MosaicRouterDelegate(),
///   routeInformationParser: MosaicRouteInformationParser(),
/// ));
/// ```
class MosaicRouterDelegate extends RouterDelegate<MosaicRouteState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<MosaicRouteState> {
  MosaicRouterDelegate() : navigatorKey = GlobalKey<NavigatorState>() {
    // Channel types must match how the router emits them, otherwise the
    // listener is skipped (the event bus enforces generic-type matching).
    _listeners
      ..add(mosaic.events.on<RouteTransitionContext>(
          'router/change/*', (_) => notifyListeners()))
      ..add(mosaic.events.on<String>('router/push', (_) => notifyListeners()))
      ..add(mosaic.events.on<String>('router/pop', (_) => notifyListeners()))
      ..add(mosaic.events.on<String>(
          'module_manager/module_activated', (_) => notifyListeners()));
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final List<EventListener> _listeners = [];

  @override
  MosaicRouteState get currentConfiguration {
    final history = mosaic.router.history;
    return MosaicRouteState(history.isEmpty ? null : history.last.module);
  }

  @override
  Future<void> setNewRoutePath(MosaicRouteState configuration) async {
    final module = configuration.module;
    if (module == null || !mosaic.registry.isRegistered(module)) return;

    final history = mosaic.router.history;
    if (history.isNotEmpty && history.last.module == module) return;

    await mosaic.router.go(module);
  }

  @override
  Future<bool> popRoute() async {
    // Pop within the current module first, then fall back to inter-module.
    final current = _currentModule();
    if (current != null && current.hasStack) {
      current.pop();
      return true;
    }
    return super.popRoute();
  }

  Module? _currentModule() {
    final history = mosaic.router.history;
    if (history.isEmpty) return null;
    return mosaic.registry.activeModules[history.last.module];
  }

  String _pageKey(String module, int index) => 'mosaic/$module/$index';

  @override
  Widget build(BuildContext context) {
    final history = mosaic.router.history;
    final pages = <Page<dynamic>>[];

    for (var i = 0; i < history.length; i++) {
      final name = history[i].module;
      final module = mosaic.registry.activeModules[name];
      if (module == null) continue;
      pages.add(
        MaterialPage<dynamic>(
          key: ValueKey(_pageKey(name, i)),
          fullscreenDialog: module.fullScreen,
          child: ModuleHost(module: module),
        ),
      );
    }

    if (pages.isEmpty) {
      pages.add(
        const MaterialPage<dynamic>(
          key: ValueKey('mosaic/empty'),
          child: Scaffold(body: Center(child: Text('No module selected'))),
        ),
      );
    }

    return Navigator(
      key: navigatorKey,
      pages: pages,
      onDidRemovePage: _onDidRemovePage,
    );
  }

  void _onDidRemovePage(Page<dynamic> page) {
    // Reconcile with the history. Only pop when the removed page is still the
    // current top of history (a user-initiated back); programmatic goBack has
    // already shrunk the history, so its key will no longer match here — which
    // prevents a double pop.
    final history = mosaic.router.history;
    if (history.isEmpty) return;
    final topKey = ValueKey(_pageKey(history.last.module, history.length - 1));
    if (page.key == topKey && history.length > 1) {
      mosaic.router.goBack();
    }
  }

  @override
  void dispose() {
    for (final listener in _listeners) {
      mosaic.events.deafen(listener);
    }
    super.dispose();
  }
}

/// Hosts a single module inside a [Navigator] page: its root widget plus its
/// internal (intra-module) navigation stack, rebuilt as that stack changes.
class ModuleHost extends StatefulWidget {
  const ModuleHost({super.key, required this.module});

  final Module module;

  @override
  State<ModuleHost> createState() => _ModuleHostState();
}

class _ModuleHostState extends State<ModuleHost> with Admissible {
  late final Widget _root = widget.module.build(context);

  @override
  void initState() {
    super.initState();
    on<String>('router/push', _refresh);
    on<String>('router/pop', _refresh);
  }

  void _refresh(EventContext<String> ctx) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final children = [_root, ...widget.module.stack];
    return IndexedStack(index: children.length - 1, children: children);
  }
}
