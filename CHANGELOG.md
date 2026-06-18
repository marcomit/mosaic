## 1.0.0

- Initial version.

## 0.2.0

- Introduced Mosaic CLI.
- Created IMC (Inter Module Communication)
- Removed unused fields.
- Created yaml_encoding to encode json into yaml files

## 0.2.1
- Added support for initialize only actives module
- Commented topological sort

## 0.2.2
- Fixed topological sort
- Fixed sync command

## 0.2.3
- Router fix

## 0.2.4
- Router pop generic type

## 0.2.5
- tidy command generates pubspec_overrides


## 1.0.0
- Introducing profiles configuration

## 1.0.1
- Fixed argument parsing for profile's commands

## 1.0.2
- Grouped singletons in all one container (also DI container)

## 1.0.3
- Added mosaic service mixin

## 1.0.4
- Added walk command in the CLI
- Deleted debug print
## 1.0.5
- Introduced Imc system
## 1.0.6
- Removed sync command CLI
## 1.0.7
- Optimized look up event listeners
- Introduced namespace support for events
- Fixed empty path events
## 1.0.8
- UI Injection fixedf priority order

## 1.0.9
- CLI mosaic status fixed.
- Added 'no-comment' option to omit comment in generated code.

## 1.0.10
- Fixed bug 'nc'

## 1.1.0

A large feature and correctness release. All changes are backward-compatible.

### Added
- **Lazy / dynamic module loading:** `registry.registerLazy`, `load`, `ensureActive` with depth-first lazy dependency resolution and cycle detection. Modules load transparently when navigated to via `router.go`.
- **Feature flags:** reactive `mosaic.features` store with local overrides and async remote resolvers; flags can gate lazy modules.
- **Module Contracts:** `mosaic.contracts` — typed public APIs provided/revoked over the module lifecycle, with `requiredContracts` boundary enforcement and lazy provider auto-loading. `MiddlewareContract` routes typed contract calls through the IMC middleware chain.
- **Scoped container:** `MosaicContainer` is now instantiable with `MosaicProvider` / `MosaicContainer.of(context)` and a `reset()` for test isolation; the global `mosaic` remains the default root scope.
- **Navigator 2.0 routing (opt-in):** `MosaicRouterDelegate` + `MosaicRouteInformationParser` render the module history as real `Navigator` pages with URL/deep-link sync, system back, and transitions. `Module.fullScreen` now presents the page as a full-screen dialog.
- **DI enhancements:** named/qualified bindings (`name:`) and async providers (`putAsync`/`getAsync`).
- **State persistence:** `MosaicStorage` backend (default `InMemoryStorage`) + `Persistable` mixin with debounced save and rehydrate-on-init, built on signals.
- **Runtime inspector:** `MosaicInspector` panel + `MosaicInspectorOverlay` showing module states, contracts, feature flags, and a live event log.
- **Lifecycle policy:** `LifecyclePolicy` auto-suspends modules outside a recency window and suspends/resumes on app background/foreground; added `ModuleManager.resumeModule`.
- **Typed event channels:** optional `EventChannel<T>` descriptors for compile-time-checked emit/listen, alongside the existing string API.
- A "choosing a communication primitive" guide (`doc/communication.md`).

### CLI
- `mosaic doctor` — diagnoses the project: dangling/circular dependencies, missing entry files, mis-configured gates, and invalid profiles.
- `mosaic tessera remove <name>` — deletes a tessera (refuses if other tesserae still depend on it).
- `mosaic tessera add` gained `--lazy` and `--gate <flag>`; the `init.dart` codegen now emits `registerLazy(...)` (with dependencies and an optional feature gate) for lazy tesserae and omits them from the eager init list.
- `mosaic version` / `--version`.
- `tidy` and `walk` now honor `--resolution` (global/profile/tesserae); `tidy` previously had no handler at all.

### Fixed
- `DependencyInjector`: `lazy()` now caches the instance after first access (previously rebuilt on every `get`); `factory()`/`lazy()` doc comments corrected; `instances` now returns resolved objects instead of builder closures.
- `Injectable.lazy` registered the builder closure as a singleton instead of a lazy dependency.
- `ModuleManager.currentModule` setter threw when cleared to `null`.
- `Signal.notify` no longer silently swallows listener errors; they are forwarded to the current zone's error handler.
- CLI: `utils.upward` no longer loops forever when run outside the home directory (now stops at the filesystem root).
- CLI: `Tessera.save`/`delete` throw `CliException` instead of calling `exit()` from inside the model; `mosaic tessera list` reads the `--path` option instead of a nonexistent positional.
- Removed a stale lint reference (`avoid_returning_null_for_future`, removed in Dart 3.3) so the package analyzes clean.
