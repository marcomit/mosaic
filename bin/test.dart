// import "package:modules/modules.dart";
// import "package:modules/router.dart";
// import "package:planner/planner.dart" as planner;
// import "package:cassa/cassa.dart" as cassa;
// import "package:banco/banco.dart" as banco;
// import "package:home/home.dart" as home;
// import "package:settings/settings.dart" as settings;
//
// class GeneratedModuleRegistry {
//   static final String defaultModule = 'home';
//   static final Map<String, Module> factories = {
//     "planner": planner.module,
//     "cassa": cassa.module,
//     "banco": banco.module,
//     "home": home.module,
//     "settings": settings.module,
//   };
//
//   static final Map<String, bool> activeStates = {
//     "planner": true,
//     "cassa": true,
//     "banco": true,
//     "home": true,
//     "settings": true,
//   };
//
//   static final Map<String, List<String>> dependencies = {
//     'planner': [],
//     'cassa': [],
//     'banco': [],
//     'home': [],
//     'settings': [],
//   };
// }
//
// Future<void> load() async {
//   moduleManager.defaultModule = GeneratedModuleRegistry.defaultModule;
//
//   final loadOrder = Module.sortByDeps(
//     GeneratedModuleRegistry.factories.values.toList(),
//   );
//   for (final module in loadOrder) {
//     module.active = GeneratedModuleRegistry.activeStates[module.name] ?? false;
//     module.dependencies =
//         GeneratedModuleRegistry.dependencies[module.name] ?? [];
//     await moduleManager.register(module);
//   }
//   router.init(moduleManager.defaultModule);
// }

