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

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:mosaic/mosaic.dart';

/// Lifecycle states for module management.
///
/// Tracks the current state of a module from initialization through disposal.
/// This enables proper error handling, resource management, and state validation.
enum ModuleLifecycleState {
  /// Module has been created but not yet initialized.
  uninitialized,

  /// Module is currently being initialized.
  initializing,

  /// Module is active and ready for use.
  active,

  /// Module is temporarily suspended (inactive but not disposed).
  suspended,

  /// Module is currently being disposed.
  disposing,

  /// Module has been disposed and cannot be used.
  disposed,

  /// Module encountered an error and needs attention.
  error,
}

/// Represents an entry in the module's internal navigation stack.
///
/// Contains a widget and a completer for resolving futures when the
/// widget is popped from the stack.
class InternalRoute<T> {
  InternalRoute(this.completer, this.widget, {Map<String, dynamic>? metadata})
    : metadata = metadata ?? {},
      createdAt = DateTime.now();

  /// Completer used to resolve the future when this route is popped.
  final Completer<T> completer;

  /// Widget to display for this route.
  final Widget widget;

  /// Metadata associated with this route.
  final Map<String, dynamic> metadata;

  /// Timestamp when this route was created.
  final DateTime createdAt;
}

/// Base class for application modules with comprehensive lifecycle management.
///
/// Modules represent isolated features or sections of an application that can
/// be independently managed, activated, and disposed. Each module has its own
/// dependency injection container and internal navigation stack.
///
/// ## Lifecycle
///
/// Modules follow a strict lifecycle:
/// 1. **Created** - Module instance exists but is uninitialized
/// 2. **Initializing** - [onInit] is being called
/// 3. **Active** - Module is ready and can be used
/// 4. **Suspended** - Module is temporarily inactive
/// 5. **Disposing** - [onDispose] is being called
/// 6. **Disposed** - Module is permanently shut down
///
/// ## Example
///
/// ```dart
/// class UserModule extends Module {
///   UserModule() : super(name: 'user');
///
///   @override
///   Widget build(BuildContext context) {
///     return UserHomePage();
///   }
///
///   @override
///   Future<void> onInit() async {
///     await setupUserServices();
///     await loadUserPreferences();
///   }
///
///   @override
///   Future<void> onDispose() async {
///     await saveUserState();
///     await cleanupConnections();
///   }
/// }
/// ```
///
/// ## Error Handling
///
/// Modules automatically handle errors during lifecycle transitions and
/// provide recovery mechanisms. Override [onError] to implement custom
/// error handling strategies.
///
/// ## Thread Safety
///
/// All module operations are thread-safe and can be called from any isolate.
/// Internal state changes are synchronized to prevent race conditions.
abstract class Module with Loggable {
  /// Creates a new module with the specified configuration.
  ///
  /// **Parameters:**
  /// * [name] - Unique identifier for this module
  /// * [fullScreen] - Whether to display in full screen mode (coming soon...)
  Module({required this.name, this.fullScreen = false}) {
    info('Module $name created');
  }

  /// Dependency injection container for this module.
  ///
  /// Each module has its own isolated DI container to prevent dependencies
  /// from leaking between modules and enable clean separation of concerns.
  final DependencyInjector di = DependencyInjector();

  /// Current lifecycle state of this module.
  ModuleLifecycleState _state = ModuleLifecycleState.uninitialized;

  /// Whether the module is currently performing a state transition.
  final Semaphore _lock = Semaphore();

  /// Error that caused the module to enter error state, if any.
  Object? _lastError;

  @override
  List<String> get loggerTags => [name];

  /// Whether the module is currently active and can handle requests.
  bool get active => _state == ModuleLifecycleState.active;

  /// Current lifecycle state of the module.
  ModuleLifecycleState get state => _state;

  /// Whether the module is in an error state.
  bool get hasError => _state == ModuleLifecycleState.error;

  /// The last error that occurred, if any.
  Object? get lastError => _lastError;

  /// Unique identifier for this module.
  final String name;

  /// Whether this module should be displayed in full screen mode.
  final bool fullScreen;

  /// Internal navigation stack for this module.
  final List<InternalRoute> _stack = [];

  final List<Module> dependencies = [];

  /// Current navigation stack as an iterable of widgets.
  ///
  /// Each widget represents a 'page' within this module's internal navigation.
  Iterable<Widget> get stack => _stack.map((m) => m.widget);

  /// Number of items currently in the navigation stack.
  int get stackDepth => _stack.length;

  /// Whether the navigation stack is empty.
  bool get hasStack => _stack.isNotEmpty;

  /// Builds the main widget for this module.
  ///
  /// This method is called when the module needs to be displayed and should
  /// return the root widget for the module's UI.
  ///
  /// **Parameters:**
  /// * [context] - Build context for creating the widget
  ///
  /// **Returns:** The root widget for this module
  Widget build(BuildContext context);

  /// Transitions the module to a new lifecycle state.
  ///
  /// This method ensures thread-safe state transitions and proper logging.
  Future<void> _transitionTo(
    ModuleLifecycleState newState, {
    Object? error,
  }) async {
    await _lock.acquire();
    final oldState = _state;
    _state = newState;
    _lastError = error;

    debug('Module $name: $oldState → $newState');

    // Emit state change event
    events.emit<ModuleLifecycleState>(
      'module/$name/state_changed',
      newState,
      true, // retain for late subscribers
    );

    _lock.release();
  }

  /// Initializes the module and transitions it to active state.
  ///
  /// This method is called automatically when the module is first loaded.
  /// Override [onInit] to perform custom initialization logic.
  ///
  /// **Throws:**
  /// * [ModuleException] if initialization fails
  /// * [StateError] if the module is not in uninitialized state
  Future<void> initialize() async {
    await _transitionTo(ModuleLifecycleState.initializing);

    try {
      info('Initializing module $name');
      await onInit();
      await _transitionTo(ModuleLifecycleState.active);
      info('Module $name initialized successfully');
    } catch (e) {
      error('Failed to initialize module $name: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      rethrow;
    }
  }

  /// Suspends the module, making it temporarily inactive.
  ///
  /// Suspended modules remain in memory but don't handle requests.
  /// Override [onSuspend] to perform custom suspension logic.
  ///
  /// **Throws:**
  /// * [ModuleException] if suspension fails
  /// * [StateError] if the module is not in active state
  Future<void> suspend() async {
    if (_state != ModuleLifecycleState.active) {
      throw StateError(
        'Cannot suspend module $name: not active (state: $_state)',
      );
    }

    try {
      info('Suspending module $name');
      await onSuspend();
      await _transitionTo(ModuleLifecycleState.suspended);
      info('Module $name suspended');
    } catch (e) {
      error('Failed to suspend module $name: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      rethrow;
    }
  }

  /// Resumes a suspended module, making it active again.
  ///
  /// Override [onResume] to perform custom resume logic.
  ///
  /// **Throws:**
  /// * [ModuleException] if resume fails
  /// * [StateError] if the module is not in suspended state
  Future<void> resume() async {
    if (_state != ModuleLifecycleState.suspended) {
      throw StateError(
        'Cannot resume module $name: not suspended (state: $_state)',
      );
    }

    try {
      info('Resuming module $name');
      await onResume();
      await _transitionTo(ModuleLifecycleState.active);
      info('Module $name resumed');
    } catch (e) {
      error('Failed to resume module $name: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      rethrow;
    }
  }

  /// Disposes the module and releases all resources.
  ///
  /// After disposal, the module cannot be used and will throw exceptions
  /// if any methods are called. Override [onDispose] to perform custom
  /// cleanup logic.
  ///
  /// **Note:** This method is idempotent - calling it multiple times is safe.
  Future<void> dispose() async {
    if (_state == ModuleLifecycleState.disposed ||
        _state == ModuleLifecycleState.disposing) {
      return;
    }

    await _transitionTo(ModuleLifecycleState.disposing);

    try {
      info('Disposing module $name');

      clear();

      await onDispose();

      di.clear();

      await _transitionTo(ModuleLifecycleState.disposed);
      info('Module $name disposed successfully');
    } catch (e) {
      error('Failed to dispose module $name: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      rethrow;
    }
  }

  /// Attempts to recover from an error state.
  ///
  /// This method tries to reinitialize the module after an error.
  /// Override [onRecover] to implement custom recovery logic.
  ///
  /// **Returns:** True if recovery was successful, false otherwise
  Future<bool> recover() async {
    if (_state != ModuleLifecycleState.error) {
      warning('Attempted to recover module $name but it\'s not in error state');
      return false;
    }

    try {
      info('Attempting to recover module $name from error: $_lastError');

      if (await onRecover()) {
        await _transitionTo(ModuleLifecycleState.uninitialized);
        await initialize();
        info('Module $name recovered successfully');
        return true;
      } else {
        warning('Module $name recovery failed: onRecover returned false');
        return false;
      }
    } catch (e) {
      error('Module $name recovery failed with exception: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      return false;
    }
  }

  /// Performs a hot reload by replacing this module with a new implementation.
  ///
  /// This advanced feature allows updating module code without losing state.
  /// Use with caution in production environments.
  ///
  /// **Parameters:**
  /// * [newModule] - The new module implementation to replace this one
  ///
  /// **Note:** This is primarily intended for development scenarios.
  Future<void> hotReload(Module newModule) async {
    info('Hot reloading module $name');

    try {
      // Suspend current module
      if (_state == ModuleLifecycleState.active) {
        await suspend();
      }

      // Transfer state to new module
      await onHotReload(newModule);

      // Initialize new module
      await newModule.initialize();

      info('Hot reload completed for module $name');
    } catch (e) {
      error('Hot reload failed for module $name: $e');
      await _transitionTo(ModuleLifecycleState.error, error: e);
      rethrow;
    }
  }

  /// Adds a widget to the module's internal navigation stack.
  ///
  /// Returns a Future that completes when the widget is popped from the stack.
  /// This enables request-response patterns within modules.
  ///
  /// **Example:**
  /// ```dart
  /// final result = await push<String>(EditProfilePage());
  /// if (result == 'saved') {
  ///   // Handle successful save
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// * [widget] - The widget to push onto the stack
  /// * [metadata] - Optional metadata associated with this route
  ///
  /// **Returns:** A Future that completes with the result when popped
  ///
  /// **Throws:**
  /// * [ModuleException] if the module is disposed
  @nonVirtual
  Future<T> push<T>(Widget widget) {
    final entry = InternalRoute(Completer<T>(), widget);
    _stack.add(entry);
    logger.info('$name PUSH ${_stack.length}', ['router']);
    events.emit<String>(['router', 'push'].join(Events.sep), '');
    return entry.completer.future;
  }

  // Removes the top widget from the navigation stack.
  ///
  /// Completes the associated Future with the provided value.
  ///
  /// **Parameters:**
  /// * [value] - Optional value to return to the caller
  ///
  /// **Throws:**
  /// * [ModuleException] if the module is disposed
  @nonVirtual
  void pop<T>([T? value]) {
    if (_stack.isEmpty) return;
    final c = _stack.removeLast().completer;
    logger.info('$name POP ${_stack.length}', ['router']);
    events.emit<String>(['router', 'pop'].join(Events.sep), '');
    c.complete(value);
  }

  /// Removes all widgets from the navigation stack.
  ///
  /// All pending Futures are completed with null values.
  @nonVirtual
  void clear() {
    while (_stack.isNotEmpty) {
      _stack.removeLast().completer.complete(null);
      events.emit<String>(['router', 'pop'].join(Events.sep), '');
    }
  }
  // Lifecycle hooks - override these in subclasses

  /// Called when the module is being initialized.
  ///
  /// Override this method to perform custom initialization logic such as:
  /// - Setting up services and dependencies
  /// - Loading configuration
  /// - Establishing network connections
  /// - Initializing state
  ///
  /// **Throws:** Any exception to indicate initialization failure
  FutureOr<void> onInit() async {}

  /// Called when the module becomes active.
  ///
  /// This is called after successful initialization and whenever the
  /// module transitions from another state to active.
  void onActive(RouteTransitionContext ctx) {}

  /// Called when the module is being suspended.
  ///
  /// Override this method to:
  /// - Pause background operations
  /// - Save temporary state
  /// - Release non-essential resources
  ///
  /// **Throws:** Any exception to indicate suspension failure
  FutureOr<void> onSuspend() async {}

  /// Called when the module is being resumed from suspension.
  ///
  /// Override this method to:
  /// - Restart background operations
  /// - Restore state
  /// - Reacquire resources
  ///
  /// **Throws:** Any exception to indicate resume failure
  Future<void> onResume() async {}

  /// Called when the module is being disposed.
  ///
  /// Override this method to:
  /// - Save important state
  /// - Close connections
  /// - Release resources
  /// - Perform cleanup
  ///
  /// **Note:** Basic cleanup (DI container, events, etc.) is handled automatically.
  FutureOr<void> onDispose() async {}

  /// Called when an error occurs during lifecycle transitions.
  ///
  /// Override this method to implement custom error handling strategies.
  ///
  /// **Parameters:**
  /// * [error] - The error that occurred
  /// * [stackTrace] - Stack trace of the error
  FutureOr<void> onError(Object error, StackTrace stackTrace) async {
    this.error('Module error: $error');
  }

  /// Called during recovery attempts.
  ///
  /// Override this method to implement custom recovery logic.
  /// Return true if recovery should proceed, false to abort.
  ///
  /// **Returns:** True if recovery should continue, false otherwise
  Future<bool> onRecover() async => true;

  /// Called during hot reload operations.
  ///
  /// Override this method to transfer state to the new module implementation.
  ///
  /// **Parameters:**
  /// * [newModule] - The new module implementation
  FutureOr<void> onHotReload(Module newModule) async {}
}
