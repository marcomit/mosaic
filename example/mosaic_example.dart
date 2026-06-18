import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A feature flag controls whether the lazy "profile" module is available.
  mosaic.features.enable('profile_enabled');

  // The home module is eager: registered and initialized up front.
  final home = HomeModule();
  await mosaic.registry.register(home);

  // The auth module is lazy and exposes a contract. It is only constructed the
  // first time the contract is resolved or the module is navigated to.
  mosaic.registry.registerLazy(
    'auth',
    AuthModule.new,
    provides: [AuthContract],
  );

  // The profile module is lazy, depends on auth, and is gated behind a flag.
  mosaic.registry.registerLazy(
    'profile',
    ProfileModule.new,
    dependencies: ['auth'],
    gate: mosaic.features.gate('profile_enabled'),
  );

  mosaic.registry.initialize(home, [home]);

  runApp(const MaterialApp(home: MosaicScope()));
}

/// The public API that [AuthModule] exposes to the rest of the app.
abstract class AuthContract extends ModuleContract {
  bool get isLoggedIn;
}

class _AuthApi implements AuthContract {
  @override
  bool get isLoggedIn => true;
}

class HomeModule extends Module {
  HomeModule() : super(name: 'home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        // Navigating loads the lazy profile module on demand.
        child: ElevatedButton(
          onPressed: () => mosaic.router.go('profile'),
          child: const Text('Open profile'),
        ),
      ),
    );
  }
}

class AuthModule extends Module {
  AuthModule() : super(name: 'auth');

  @override
  void provideContracts(ContractRegistry contracts) {
    contracts.provide<AuthContract>(_AuthApi(), provider: name);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class ProfileModule extends Module {
  ProfileModule() : super(name: 'profile');

  // Initialization fails fast if AuthContract is not available — and because
  // auth declares `provides: [AuthContract]`, it is loaded automatically.
  @override
  List<Type> get requiredContracts => [AuthContract];

  @override
  Widget build(BuildContext context) {
    final auth = contracts.of<AuthContract>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Text(auth.isLoggedIn ? 'Logged in' : 'Logged out'),
      ),
    );
  }
}
