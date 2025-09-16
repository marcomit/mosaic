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
// import 'package:mosaic/src/dependency_injection/dependency_injector.dart';

class TypedCallback {
  TypedCallback(this.callback, this.resultType, this.paramsType);

  final ImcCallback callback;
  final Type resultType;
  final Type paramsType;
}

class ImcContract {
  ImcContract(String name) : _name = name;

  final String _name;
  final Map<String, TypedCallback> _callbacks = {};

  void register<TResult, TParams>(
    String action,
    ImcCallback<TResult, TParams> callback,
  ) {
    if (_callbacks.containsKey(action)) {
      throw ImcException(
        'Callback $action inside $_name is already registered',
      );
    }

    _callbacks[action] = TypedCallback(
      // Wrap the typed callback to match ImcCallback signature
      (ImcContext ctx) async {
        // Cast context to correct type
        final typedCtx = ImcContext<TParams>(ctx.path, ctx.params as TParams);
        return await callback(typedCtx);
      },
      TResult,
      TParams,
    );
  }
}

/// Context of the [IMCCallback].
///
/// It contains the params you pass when you call the imc call.
/// When you create the call you must define a callback that takes this context.
class ImcContext<T> {
  ImcContext(this.path, this.params);

  /// Params of the callback.
  /// Assigned when a call will be executed.
  /// and handled by the callback you've defined before.
  final T params;
  final String path;
  // bool _next = false;

  // void next() => _next = true;
}

typedef ImcCallback<TResult, TParams> =
    FutureOr<TResult> Function(ImcContext<TParams>);

class ImcNode {
  ImcNode(
    this.name, {
    this.expectedResult = dynamic,
    this.expectedParams = dynamic,
  });
  final String name;
  final Type expectedResult;
  final Type expectedParams;
  ImcCallback? _callback;
  final Map<String, ImcNode> _children = {};

  // ImcNode _on(ImcCallback callback) {
  //   if (_callback != null) {
  //     throw ImcException('Callback already registered');
  //   }
  //   _callback = _ImcTypedCallback(callback);
  //   return this;
  // }

  // ImcNode _sub(String name) {
  //   if (_children.containsKey(name)) {
  //     throw ImcException('Node $name already registered');
  //   }
  //   final child = ImcNode(name);
  //   _children[name] = child;
  //   return child;
  // }

  Future<(ImcNode, T)> _executeChild<T>(String name, ImcContext context) async {
    if (!_children.containsKey(name)) {
      throw ImcException(
        'Invalid callback ${context.path}',
        cause: 'The handler is not registered',
        fix: ' Try to register the handler before call it',
      );
    }
    final child = _children[name]!;

    T? result;
    if (child._callback != null) {
      result = await child._callback!(context);
    }
    if (result == null) {
      throw ImcException('Cannot use null value');
    }

    return (child, result);
  }

  // Future _exec(String args, dynamic params) async {
  //   final path = args.split(Imc.sep);
  //   final ctx = ImcContext(args, params);
  //   dynamic result;
  //
  //   ImcNode current = this;
  //   for (final segment in path) {
  //     (current, result) = await current._executeChild(segment, ctx);
  //   }
  //
  //   return result;
  // }
}

/// IMC (Inter-Module Communication)
/// It permit to call methods through different modules without depending on it
///
/// Example:
/// ```dart
/// class UserModule exetnds Module {
///   @override
///   void onInit() {
///     imc.register('user.getUserById', (ctx) {
///       // Put your logic here
///     });
///   }
///   ...
/// }
///
/// // inside another module widget
/// onPressed: () => imc('user.getUserById', 'myid');
/// ```
///
/// [IMC] also supports:
/// * Middleware
/// ```dart
/// imc.register('user', (ctx) {
///   // All functions under the 'user' path execute this function before
///   validateAuthorization(ctx.params);
/// });
/// imc.register('user.getUserById', (ctx) {
///   // This the user is authorized
/// });
/// ```
/// * Dependency Injection
/// ```dart
/// imc.register('user', (ctx) { ctx.di.put(UserService(ctx.params)); });
/// imc.register('user.getUserById', (ctx) async {
///   final userService = ctx.di.get<UserService>();
///   // use your service here
/// });
/// ```
class Imc {
  final ImcNode _root = ImcNode('root');
  final Map<String, ImcContract> _contracts = {};
  bool _disposed = false;

  static const String sep = '.';

  void _checkDispose() {
    if (_disposed) {
      throw ImcException('Operation not permitted', cause: 'Object disposed');
    }
  }

  void handshake(ImcContract contract) {
    if (_contracts.containsKey(contract._name)) {
      throw ImcException('Contract ${contract._name} already registered');
    }

    _contracts[contract._name] = contract;
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
    String call,
    ImcCallback<TResult, TParams> callback,
  ) {
    _checkDispose();
    //
    //   final path = call.split(sep);
    //
    //   ImcNode current = _root;
    //
    //   for (final segment in path) {
    //     if (!current._children.containsKey(segment)) {
    //       current._sub(segment);
    //     }
    //     current = current._children[segment]!;
    //   }
    //   print(current);
    //
    //   final ImcNode curr = current;
    //   (curr)._on(callback);
  }

  /// Methods to execute raw call (String based instead of contracts).
  ///
  /// Alloj ws to call the imc by passing the action and the params
  /// If the action doesn't exists or there's a mismath from the passed and the expected types it throws an [ImcException].
  /// The action must be following the format 'moduleName.actionName'. See [register] for more details.
  /// So this has more restriction than using [IMCContract] with [put] and [get] but offer more isolation between modules
  ///
  /// **Example:**
  /// ```dart
  /// final user = await imc('user.getUserById', 'user1'); // this is not typed and should be throws into an error
  /// final user = await imc<User?, String>('user.getUserById', 'user1'); // this is fully typed.
  /// ```
  FutureOr<TResult> call<TResult, TParams>(
    String action, [
    TParams? params,
  ]) async {
    return await execute(action, params);
  }

  FutureOr<TResult> execute<TResult, TParams>(
    String action, [
    TParams? params,
  ]) async {
    return await _checkContract(action, params);
  }

  FutureOr<TResult> _checkContract<TResult, TParams>(
    String action,
    TParams params,
  ) async {
    final ctx = ImcContext(action, params);
    final path = action.split(sep);

    print(path);
    if (path.length != 2) {
      throw ImcException(
        'Invalid Imc action',
        cause: 'It must be a format like \'contract${sep}action\'',
      );
    }

    final contract = _contracts[path[0]];

    print(contract);
    if (contract == null) {
      throw ImcException(
        'Contract ${path[0]} not found',
        fix: 'Try to register a contract \'${path[0]}\'',
      );
    }

    print(contract._callbacks);

    final typedCallback = contract._callbacks[path[1]]!;

    if (TParams != dynamic && typedCallback.paramsType != TParams) {
      throw ImcException(
        'Parameter type mismatch: expected ${typedCallback.paramsType}, got $TParams',
      );
    }

    if (TResult != dynamic && typedCallback.resultType != TResult) {
      throw ImcException(
        'Return type mismatch: expected ${typedCallback.resultType}, got $TResult',
      );
    }

    final result = await typedCallback.callback(ctx);

    if (result is! TResult && TResult != dynamic) {
      throw ImcException(
        'Runtime result type mismatch: expected $TResult, got ${result.runtimeType}',
      );
    }

    return result as TResult;
  }

  /// Clear all the actions and contracts registered.
  ///
  /// After you call this the instance cannot be used anymore
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _root._children.clear();
  }
}
