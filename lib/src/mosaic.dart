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
import 'package:mosaic/src/dependency_injection/dependency_container.dart';

/// Root container that wires together every Mosaic subsystem (events, router,
/// IMC, module registry, DI, feature flags, contracts, logger).
///
/// The global [mosaic] instance is the default *root scope* and is what every
/// subsystem resolves against internally. Application code is encouraged to
/// reach the container through [MosaicContainer.of] (backed by [MosaicProvider])
/// rather than the hard global reference, which decouples widgets from the
/// global and makes future per-scope isolation a drop-in change.
class MosaicContainer with Injectable {
  /// Creates an independent container with a fresh set of subsystems.
  ///
  /// Useful in tests that want an isolated instance. Note that subsystems still
  /// resolve cross-references (e.g. router → events) against the [mosaic] root
  /// scope today; full per-scope subsystem isolation is planned.
  MosaicContainer() {
    _register();
  }

  void _register() {
    put(Events());
    put(InternalRouter());
    put(Logger());
    put(Imc());
    put(ModuleManager());
    put(UIInjector());
    put(FeatureFlags());
    put(ContractRegistry());
    put<MosaicStorage>(InMemoryStorage());
  }

  /// Rebuilds every subsystem from scratch, discarding all state.
  ///
  /// Intended for test `tearDown`/`setUp` to guarantee isolation between tests
  /// that share the [mosaic] root scope.
  void reset() {
    clear();
    _register();
  }

  /// Resolves the nearest [MosaicContainer] from the widget tree, falling back
  /// to the global [mosaic] root scope when no [MosaicProvider] is present.
  static MosaicContainer of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MosaicProvider>();
    return provider?.container ?? mosaic;
  }

  Events get events => get<Events>();
  InternalRouter get router => get<InternalRouter>();
  Imc get imc => get<Imc>();
  ModuleManager get registry => get<ModuleManager>();
  UIInjector get injector => get<UIInjector>();

  /// Runtime feature-flag store used for staged rollouts, A/B tests, and gating
  /// lazy modules behind a flag.
  FeatureFlags get features => get<FeatureFlags>();

  /// Registry of typed module contracts (each module's public API surface).
  ContractRegistry get contracts => get<ContractRegistry>();

  /// Key/value storage backend used by the persistence layer (the [Persistable]
  /// mixin). Defaults to [InMemoryStorage]; override with
  /// `mosaic.override<MosaicStorage>(impl)`.
  MosaicStorage get storage => get<MosaicStorage>();

  /// Global logger instance for application-wide logging.
  ///
  /// This singleton provides a convenient way to access logging functionality
  /// from anywhere in your application without dependency injection.
  ///
  /// **Example:**
  /// ```dart
  /// logger.info('Application started');
  /// logger.error('Failed to connect to database');
  /// ```
  Logger get logger => get<Logger>();
}

mixin MosaicServices {
  Events get events => mosaic.events;
  InternalRouter get router => mosaic.router;
  Imc get imc => mosaic.imc;
  ModuleManager get registry => mosaic.registry;
  Logger get logger => mosaic.logger;
  FeatureFlags get features => mosaic.features;
  ContractRegistry get contracts => mosaic.contracts;
  MosaicStorage get storage => mosaic.storage;
}

/// The default root [MosaicContainer] scope used throughout the application.
final mosaic = MosaicContainer();

/// Provides a [MosaicContainer] to a widget subtree.
///
/// Wrap your app (or a subtree) to make `MosaicContainer.of(context)` resolve to
/// a specific container instead of the global [mosaic] root scope:
///
/// ```dart
/// MosaicProvider(
///   container: myScopedContainer,
///   child: MosaicScope(),
/// );
/// ```
class MosaicProvider extends InheritedWidget {
  const MosaicProvider({
    super.key,
    required this.container,
    required super.child,
  });

  /// The container exposed to descendants.
  final MosaicContainer container;

  @override
  bool updateShouldNotify(MosaicProvider oldWidget) =>
      container != oldWidget.container;
}
