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

/// Drives module lifecycle transitions automatically so capabilities like
/// suspend/resume actually get used.
///
/// Two policies, both opt-in via [attach]:
/// * **Memory** — suspends active modules that have fallen outside the most
///   recent [keepAlive] navigation-history entries (now meaningful since lazy
///   modules can also be unloaded).
/// * **App lifecycle** — suspends the current module when the app is
///   backgrounded and resumes it on the foreground.
///
/// ```dart
/// final policy = LifecyclePolicy(keepAlive: 3)..attach();
/// // ... on shutdown:
/// policy.detach();
/// ```
class LifecyclePolicy with WidgetsBindingObserver {
  LifecyclePolicy({
    this.keepAlive = 3,
    this.suspendOnBackground = true,
  });

  /// How many of the most recent history modules stay active. Older active
  /// modules are suspended. The current module is always kept.
  final int keepAlive;

  /// Whether to suspend the current module when the app is backgrounded.
  final bool suspendOnBackground;

  EventListener? _routeListener;
  String? _suspendedOnBackground;

  /// Starts enforcing the policy.
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _routeListener = mosaic.events.on<RouteTransitionContext>(
      'router/change/*',
      (_) => enforceMemoryPolicy(),
    );
  }

  /// Stops enforcing the policy and releases listeners.
  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    final listener = _routeListener;
    if (listener != null) mosaic.events.deafen(listener);
    _routeListener = null;
  }

  /// Suspends active modules that are no longer within the [keepAlive] window
  /// of the navigation history (never the current module).
  Future<void> enforceMemoryPolicy() async {
    final recent = mosaic.router.history.reversed
        .map((e) => e.module)
        .take(keepAlive)
        .toSet();
    final current = mosaic.registry.currentModule;

    for (final name in mosaic.registry.activeModules.keys.toList()) {
      if (name == current || recent.contains(name)) continue;
      await mosaic.registry.suspendModule(name);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!suspendOnBackground) return;
    switch (state) {
      case AppLifecycleState.paused:
        _suspendCurrent();
      case AppLifecycleState.resumed:
        _resumeBackgrounded();
      default:
        break;
    }
  }

  Future<void> _suspendCurrent() async {
    final current = mosaic.registry.currentModule;
    if (current == null) return;
    if (mosaic.registry.isActive(current)) {
      _suspendedOnBackground = current;
      await mosaic.registry.suspendModule(current);
    }
  }

  Future<void> _resumeBackgrounded() async {
    final name = _suspendedOnBackground;
    _suspendedOnBackground = null;
    if (name != null) {
      await mosaic.registry.resumeModule(name);
    }
  }
}
