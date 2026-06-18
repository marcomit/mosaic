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

import 'package:mosaic/mosaic.dart';

/// Marker base class for a module's public, typed API surface.
///
/// A contract is an abstract interface that a module exposes to the rest of the
/// application. Consumers depend on the *contract*, never on the concrete
/// module class, which keeps modules independently replaceable and prevents one
/// module from reaching into another's internals.
///
/// ## Defining a contract
///
/// ```dart
/// abstract class AuthContract extends ModuleContract {
///   Future<bool> isLoggedIn();
///   Future<void> logout();
/// }
/// ```
///
/// ## Providing it from a module
///
/// ```dart
/// class AuthModule extends Module {
///   AuthModule() : super(name: 'auth');
///
///   @override
///   void provideContracts(ContractRegistry contracts) {
///     contracts.provide<AuthContract>(_AuthApi(), provider: name);
///   }
/// }
/// ```
///
/// ## Consuming it elsewhere
///
/// ```dart
/// final auth = mosaic.contracts.of<AuthContract>();
/// if (await auth.isLoggedIn()) { ... }
/// ```
abstract class ModuleContract {}

/// Mixin that routes a contract's calls through the IMC middleware chain.
///
/// Contracts are the *typed public surface* of a module; IMC is the
/// *cross-cutting transport* (auth, logging, validation middleware). Mix this in
/// when a contract's methods should pass through that middleware instead of
/// calling module internals directly.
///
/// The provider registers IMC handlers under [channel] (typically the module
/// name) and the contract's typed methods delegate to [dispatch], so every
/// registered middleware on the channel runs.
///
/// ```dart
/// class _AuthApi extends ModuleContract
///     with MiddlewareContract
///     implements AuthContract {
///   @override
///   String get channel => 'auth';
///
///   @override
///   Future<bool> login(Credentials c) => dispatch('login', c);
/// }
///
/// // In the providing module:
/// register('login', (ctx) => _doLogin(ctx.data)); // ImcCallable, channel 'auth'
/// ```
mixin MiddlewareContract on ModuleContract {
  /// IMC namespace this contract dispatches through (usually the module name).
  String get channel;

  /// Invokes [action] under [channel] through the IMC middleware chain.
  Future<R> dispatch<R>(String action, [dynamic params]) async {
    final result = await mosaic.imc(
      [channel, action].join(mosaic.imc.separator),
      params,
    );
    return result as R;
  }
}

/// Central registry that maps a [ModuleContract] type to its live provider.
///
/// The registry enforces module boundaries at runtime:
/// * Contracts are registered when their providing module activates and revoked
///   when it is disposed, so a consumer can never hold a stale reference.
/// * Lazy modules can declare which contracts they provide; requesting such a
///   contract via [resolve] transparently loads the providing module.
class ContractRegistry with Loggable {
  @override
  List<String> get loggerTags => ['contracts'];

  /// Live contracts keyed by their declared interface type.
  final Map<Type, ModuleContract> _live = {};

  /// Maps a live contract type to the module that provided it (for revocation).
  final Map<Type, String> _providerOf = {};

  /// Maps a contract type to the lazy module declared to provide it.
  final Map<Type, String> _lazyProviders = {};

  /// Read-only view of the currently provided contracts and their providers.
  ///
  /// Useful for diagnostics and a runtime inspector.
  Map<Type, String> get providers => Map.unmodifiable(_providerOf);

  /// Registers [contract] under its interface type [C].
  ///
  /// Call this from [Module.provideContracts]. The explicit type argument [C]
  /// is what consumers resolve against, so always provide it:
  ///
  /// ```dart
  /// contracts.provide<AuthContract>(impl, provider: name);
  /// ```
  ///
  /// **Parameters:**
  /// * [contract] - the implementation instance to expose
  /// * [provider] - name of the providing module (used for revocation)
  ///
  /// **Throws:** [ContractException] if [C] is already provided by a different
  /// module.
  void provide<C extends ModuleContract>(C contract, {required String provider}) {
    final existing = _providerOf[C];
    if (existing != null && existing != provider) {
      throw ContractException(
        'Contract $C is already provided by module "$existing"',
        cause: 'Module "$provider" tried to provide the same contract',
        fix: 'Only one module may provide a given contract type',
      );
    }
    _live[C] = contract;
    _providerOf[C] = provider;
    debug('Contract $C provided by $provider');
    mosaic.events.emit<String>(
      ['contracts', 'provided', C.toString()].join(mosaic.events.sep),
      provider,
    );
  }

  /// Declares that the lazy module [moduleName] provides contract type [C].
  ///
  /// This lets [resolve] load the right module on demand the first time the
  /// contract is requested. Called automatically by
  /// [ModuleManager.registerLazy] when `provides:` is supplied.
  void declareLazyProvider<C extends ModuleContract>(String moduleName) {
    _lazyProviders[C] = moduleName;
  }

  /// Type-erased variant of [declareLazyProvider].
  ///
  /// Used by [ModuleManager.registerLazy] which receives contract types as a
  /// `List<Type>` and cannot supply a static type argument.
  void declareLazyProviderType(Type contractType, String moduleName) {
    _lazyProviders[contractType] = moduleName;
  }

  /// Synchronously resolves the live contract of type [C].
  ///
  /// **Throws:** [ContractException] if no module currently provides [C]. The
  /// message lists available contracts to aid debugging.
  C of<C extends ModuleContract>() {
    final contract = _live[C];
    if (contract == null) {
      final available = _live.keys.map((t) => t.toString()).toList()..sort();
      throw ContractException(
        'No provider for contract $C',
        cause: _lazyProviders.containsKey(C)
            ? 'Module "${_lazyProviders[C]}" provides it but is not loaded yet'
            : 'No registered module exposes this contract',
        fix: _lazyProviders.containsKey(C)
            ? 'Use mosaic.contracts.resolve<$C>() to load it on demand'
            : 'Available contracts: ${available.isEmpty ? '<none>' : available.join(', ')}',
      );
    }
    return contract as C;
  }

  /// Returns the live contract of type [C], or `null` if none is provided.
  C? maybe<C extends ModuleContract>() => _live[C] as C?;

  /// Resolves [C], loading its declared lazy provider module if necessary.
  ///
  /// If the contract is already live it is returned immediately. Otherwise, if a
  /// lazy provider was declared, that module is loaded and activated first.
  ///
  /// **Throws:** [ContractException] if the contract cannot be resolved even
  /// after loading the declared provider.
  Future<C> resolve<C extends ModuleContract>() async {
    final live = _live[C];
    if (live != null) return live as C;

    final provider = _lazyProviders[C];
    if (provider != null) {
      info('Loading module "$provider" to resolve contract $C');
      await mosaic.registry.ensureActive(provider);
    }
    return of<C>();
  }

  /// Whether contract type [C] currently has a live provider.
  bool isProvided<C extends ModuleContract>() => _live.containsKey(C);

  /// Whether the contract [type] currently has a live provider.
  ///
  /// Type-erased variant of [isProvided] for use with reflectionless [Type]
  /// values (e.g. [Module.requiredContracts]).
  bool isProvidedType(Type type) => _live.containsKey(type);

  /// Whether a lazy provider has been declared for contract [type].
  bool hasProviderFor(Type type) =>
      _live.containsKey(type) || _lazyProviders.containsKey(type);

  /// The lazy module declared to provide contract [type], if any.
  String? lazyProviderFor(Type type) => _lazyProviders[type];

  /// Revokes every contract provided by [moduleName].
  ///
  /// Called automatically when a module is disposed so consumers fail loudly
  /// rather than using a dead reference.
  void revokeByProvider(String moduleName) {
    final revoked = _providerOf.entries
        .where((e) => e.value == moduleName)
        .map((e) => e.key)
        .toList();
    for (final type in revoked) {
      _live.remove(type);
      _providerOf.remove(type);
      mosaic.events.emit<String>(
        ['contracts', 'revoked', type.toString()].join(mosaic.events.sep),
        moduleName,
      );
    }
    if (revoked.isNotEmpty) {
      debug('Revoked ${revoked.length} contract(s) from $moduleName');
    }
  }

  /// Removes all live contracts and declarations. Primarily for testing.
  void reset() {
    _live.clear();
    _providerOf.clear();
    _lazyProviders.clear();
  }
}
