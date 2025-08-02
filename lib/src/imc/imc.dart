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

import 'package:mosaic/exceptions.dart';
import 'package:mosaic/src/dependency_injection/dependency_injector.dart';

/// Utility class to make the callback type-safe.
///
/// Allows checking the expected result of the call [TResult]
/// and the params you pass to the callback [TParams].
class _ImpTypedCallback<TResult, TParams> {
  _ImpTypedCallback(this.callback);

  /// callback that handle the call.
  final IMCCallback<TResult, TParams> callback;

  /// Result type of the given callback
  final Type result = TResult;

  /// Params type of the given callback
  final Type params = TParams;
}

/// Base class that represend the contract.
///
/// Allows you to create custom contracts and register they into the IMC
/// Use [IMCContract] if you want the highest type-safe level from the [IMC].
///
/// Example:
/// ```dart
/// class UserContract extends IMCContract {
///   UserContract() : super("user");
///   User? getUserById(String id) async {...}
/// }
///
/// // inside the module
/// imc.put(UsrContract());
///
/// // And you can call the contract in other modules
/// final userContract = imc.get<UserContract>();
/// await userContract.getUserById('user1'); // expected type User?
/// ```
///
/// **Performance Note:**
/// String-based calls have runtime overhead for path parsing and type validation.
/// Use contracts for better performance in high-frequency scenarios.
///
/// **When to use:**
/// - Use contracts ([put]/[get]) for type safety within your team
/// - Use string calls ([register]/[call]) for loose coupling between modules
///
/// Shorthand for [call] method - allows using IMC instance as a function
///
/// Example: `await imc<User, String>('user.getUser', 'id123')`
abstract class IMCContract {
  IMCContract(this.moduleName);

  /// Represent the name of the module.
  final String moduleName;
}

/// Context of the [IMCCallback].
///
/// It contains the params you pass when you call the imc call.
/// When you create the call you must define a callback that takes this context.
class ImcContext<T> {
  ImcContext(this.params);

  /// Params of the callback.
  /// Assigned when a call will be executed.
  /// and handled by the callback you've defined before.
  final T params;
}

typedef IMCCallback<TResult, TParams> =
    FutureOr<TResult> Function(ImcContext<TParams>);

/// IMC (Inter-Module Communication)
/// It permit to call methods through different modules without depending on it
class IMC {
  final DependencyInjector _container = DependencyInjector();
  final Map<String, Map<String, _ImpTypedCallback>> _calls = {};
  bool _disposed = false;

  void _checkDispose() {
    if (_disposed) {
      throw ImcException("Operation not permitted", cause: "Object disposed");
    }
  }

  /// This allows to insert [IMCContract] inside the IMC.
  ///
  /// **Parameters:**
  ///   - [contract] is the instance of the contract that will be registered
  ///
  /// **Throws:**
  ///   - [ImcException] if it was already disposed
  ///   - [DependencyException] if it contains a [IMCContract] already registered
  void put<T extends IMCContract>(T contract) {
    _checkDispose();
    _container.put<T>(contract);
  }

  /// Function to retrieve a registered contract
  ///
  /// It takes a type argument [T] that is an [IMCContract].
  /// if there's no contract with the type you passed it throws an [ImcException]
  ///
  /// **Example:**
  /// ```dart
  /// imc.put(UserContract()); // register the Contract
  /// imc.get<UserContract>(); // give the registered contract
  /// ```
  T get<T extends IMCContract>() {
    _checkDispose();
    if (!_container.contains<T>()) {
      throw ImcException(
        "Contract $T not found",
        fix: "Try to add it using put<$T>(instance)",
      );
    }
    return _container.get<T>();
  }

  /// Register a call by string name.
  ///
  /// **Note:** If you want a more type-safety use [IMCContract] by calling [get] and [put]
  /// If you want more flexibility and isolated modules use this.
  /// **Params:**
  ///   - [path]:
  ///     Must be with 'moduleName.actionName', if it's not following this format throws [ImcException].
  ///   - [callback]:
  ///     This is the callback that will be associated to the call, so when you call this action the callback will be executed
  ///
  /// **Example:**
  /// ```dart
  /// imc.register('user.getUserById', (ctx) async {...}); // warning: this is not type safe
  /// imc.register<User?, String>('user.getUserById', (ctx) {
  ///  ctx.params // now it has type String
  /// }); // Now you know that the return type is User?
  /// ```
  void register<TResult, TParams>(
    String path,
    IMCCallback<TResult, TParams> callback,
  ) {
    _checkDispose();
    _validateAction(path);
    final [name, action] = path.split('.');
    _insertAction<TResult, TParams>(name, action, callback);
  }

  void _validateAction(String action) {
    final path = action.split('.');
    if (path.length != 2) {
      throw ImcException(
        '$action is an invalid call',
        fix: 'Register with moduleName.action',
      );
    }
  }

  void _insertAction<TResult, TParams>(
    String module,
    String action,
    IMCCallback<TResult, TParams> callback,
  ) {
    if (!_calls.containsKey(module)) {
      _calls[module] = {};
    }
    if (_calls[module]!.containsKey(action)) {
      throw ImcException("No action '$action' found in module '$module'");
    }

    final typed = _ImpTypedCallback(callback);

    _calls[module] = {..._calls[module]!, action: typed};
  }

  /// Methods to execute raw call (String based instead of contracts).
  ///
  /// Allows to call the imc by passing the action and the params
  /// If the action doesn't exists or there's a mismath from the passed and the expected types it throws an [ImcException].
  /// The action must be following the format 'moduleName.actionName'. See [register] for more details.
  /// So this has more restriction than using [IMCContract] with [put] and [get] but offer more isolation between modules
  ///
  /// **Example:**
  /// ```dart
  /// final user = await imc('user.getUserById', 'user1'); // this is not typed and should be throws into an error
  /// final user = await imc<User?, String>('user.getUserById', 'user1'); // this is fully typed.
  /// ```
  Future<TResult> call<TResult, TParams>(String action, TParams params) async {
    _checkDispose();
    _validateAction(action);

    final [name, act] = action.split('.');

    if (!_calls.containsKey(name)) {
      throw ImcException("Unknown module $name");
    }
    if (!_calls[name]!.containsKey(act)) {
      throw ImcException("There's not actions $act in module $name");
    }
    final typed = _calls[name]![act]!;
    final context = ImcContext(params);

    if (typed.params is! TParams) {
      throw ImcException("Expected params $TParams, got ${typed.params}");
    }
    if (typed.result is! TResult) {
      throw ImcException("Expected result $TResult, got ${typed.result}");
    }

    final result = await typed.callback(context);
    if (result is! TResult) {
      throw ImcException(
        "Mismatch return type",
        cause:
            "Your expected type is $TResult but the actual type is ${result.runtimeType}",
      );
    }
    return result;
  }

  /// Clear all the actions and contracts registered.
  ///
  /// After you call this the instance cannot be used anymore
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _calls.clear();
    _container.clear();
  }
}
