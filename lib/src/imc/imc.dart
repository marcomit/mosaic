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
import 'dart:math';

import 'package:mosaic/exceptions.dart';
import 'package:mosaic/mosaic.dart';

/// Callback function signature for IMC actions.
///
/// Receives an [ImcContext] containing request data and execution state.
/// Can return any value, which becomes available in [ImcContext.last] for
/// subsequent callbacks in the chain.
///
/// **Example:**
/// ```dart
/// ImcCallback authMiddleware = (ctx) async {
///   final token = ctx.data as String;
///   return await validateToken(token);
/// };
/// ```
typedef ImcCallback = FutureOr<dynamic> Function(ImcContext);

/// Execution context passed to each callback in an IMC action chain.
///
/// Contains the initial request data, execution path information, and results
/// from previous callbacks. Automatically advances through the path as each
/// callback executes.
///
/// **Properties:**
/// - [data]: Initial parameters passed to [Imc.call]
/// - [last]: Return value from the most recent callback
/// - [path]: Complete action path as a list (e.g., ['user', 'auth', 'login'])
/// - [current]: Current path segment being processed
///
/// **Example:**
/// ```dart
/// imc.register('api.v1.users', (ctx) {
///   print(ctx.path);    // ['api', 'v1', 'users']
///   print(ctx.current); // 'users' (if last segment)
///   return processUsers(ctx.data);
/// });
/// ```
class ImcContext {
  /// Creates a new context with the given [data] and action [path].
  ImcContext(this.data, this.path);

  /// The complete action path split by separator (e.g., ['user', 'update']).
  final List<String> path;

  /// The initial data/parameters passed to [Imc.call].
  ///
  /// This value persists throughout the entire callback chain and should
  /// be treated as the primary input data.
  dynamic data;

  /// The return value from the most recently executed callback.
  ///
  /// Middleware can use this to pass data forward in the chain:
  /// ```dart
  /// imc.register('user', (ctx) => fetchUser(ctx.data));
  /// imc.register('user.validate', (ctx) {
  ///   final user = ctx.last; // Result from 'user' callback
  ///   return user.isValid;
  /// });
  /// ```
  dynamic last;

  /// Internal index tracking the current position in [path].
  int _index = 0;

  /// Returns the current path segment being processed.
  ///
  /// Corresponds to `path[_index]` but provides a clearer interface.
  String get current => path[_index];
}

/// Internal tree node representing a segment in an action path.
///
/// Each node can have child nodes (forming the path hierarchy) and an
/// optional callback. Nodes without callbacks act as intermediary path
/// segments (e.g., 'user' in 'user.auth.login').
class _ImcNode {
  /// Creates a node with the given [name].
  _ImcNode(this.name);

  /// The path segment name this node represents.
  final String name;

  /// Child nodes indexed by their segment names.
  final Map<String, _ImcNode> children = {};

  /// Optional callback executed when this node is reached during traversal.
  ///
  /// Null for intermediate path segments that serve only as organizational
  /// structure (middleware without logic).
  ImcCallback? callback;

  /// Calculates Levenshtein distance between two strings.
  ///
  /// Used for suggesting similar action names when a path segment isn't found.
  /// This is a recursive implementation with O(n*m) time complexity.
  ///
  /// **Parameters:**
  /// - [a]: First string to compare
  /// - [b]: Second string to compare
  ///
  /// **Returns:** The minimum number of single-character edits (insertions,
  /// deletions, or substitutions) needed to transform [a] into [b].
  int _getDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final trimmedA = a.substring(0, a.length - 1);
    final trimmedB = b.substring(0, b.length - 1);
    if (a[a.length - 1] == b[b.length - 1]) {
      return _getDistance(trimmedA, trimmedB);
    }

    int res = _getDistance(trimmedA, b);
    res = min(res, _getDistance(a, trimmedB));
    res = min(res, _getDistance(trimmedA, trimmedB));

    return 1 + res;
  }

  /// Finds the child name most similar to [name] using edit distance.
  ///
  /// Used to suggest alternatives when an action path segment doesn't exist.
  ///
  /// **Returns:** The closest matching child name, or null if no children exist.
  String? _getClosestMatch(String name) {
    int minDistance = 1 << 31;
    String? closest;

    for (final child in children.keys) {
      final distance = _getDistance(child, name);
      if (distance < minDistance) {
        minDistance = distance;
        closest = child;
      }
    }

    return closest;
  }

  /// Traverses the action path, executing callbacks in order.
  ///
  /// Walks from this node through each segment in [path], executing any
  /// registered callbacks. The context accumulates results via [ImcContext.last].
  ///
  /// **Parameters:**
  /// - [path]: Remaining path segments to traverse
  /// - [data]: Initial data passed through [ImcContext.data]
  ///
  /// **Returns:** The result from the final callback in the chain.
  ///
  /// **Throws:**
  /// - [ImcException] if any path segment doesn't exist, with a suggestion
  ///   for the closest matching segment.
  Future<dynamic> _walk(List<String> path, dynamic data) async {
    _ImcNode curr = this;
    final context = ImcContext(data, path);
    for (final segment in path) {
      if (!curr.children.containsKey(segment)) {
        final closest = curr._getClosestMatch(segment);
        throw ImcException(
          'The action $segment of $path is not registered yet',
          fix: closest == null
              ? 'Try to register it before'
              : 'Did you mean $closest instead of $segment?',
        );
      }
      curr = curr.children[segment]!;
      await curr._execute(context);
      context._index++;
    }
    return context.last;
  }

  /// Executes this node's callback if one exists.
  ///
  /// Updates [ImcContext.last] with the callback's return value.
  Future<void> _execute(ImcContext ctx) async {
    if (callback == null) return;
    ctx.last = await callback!(ctx);
  }

  /// Registers a callback at the specified path, creating nodes as needed.
  ///
  /// Builds the tree structure by creating intermediate nodes for any
  /// path segments that don't exist yet.
  ///
  /// **Throws:**
  /// - [ImcException] if a callback is already registered at this exact path.
  void _register(List<String> path, ImcCallback callback) {
    _ImcNode curr = this;
    for (final segment in path) {
      if (!curr.children.containsKey(segment)) {
        curr.children[segment] = _ImcNode(segment);
      }
      curr = curr.children[segment]!;
    }

    if (curr.callback != null) {
      throw ImcException('Callback for $path already registered');
    }
    curr.callback = callback;
  }
}

/// Inter-Module Communication container for decoupled action dispatching.
///
/// Provides a flexible, middleware-based system for registering and executing
/// actions without direct module dependencies. Actions are hierarchical paths
/// that can include intermediate callbacks for cross-cutting concerns like
/// authentication, logging, or validation.
///
/// **Thread Safety:** Not thread-safe. Use separate instances per isolate
/// or add external synchronization.
///
/// **Example:**
/// ```dart
/// final imc = Imc();
///
/// // Authentication middleware for all 'api' actions
/// imc.register('api', (ctx) async {
///   final token = ctx.data['token'];
///   if (!await verifyToken(token)) throw UnauthorizedException();
/// });
///
/// // Specific endpoint handler
/// imc.register('api.users.list', (ctx) async {
///   return await fetchUsers(limit: ctx.data['limit']);
/// });
///
/// // Execute the chain
/// final users = await imc.call('api.users.list', {'token': 'abc', 'limit': 50});
/// ```
class Imc {
  /// Creates an IMC container with a custom path [sep]arator.
  ///
  /// **Parameters:**
  /// - [sep]: Character(s) used to split action paths (default: '.')
  ///
  /// **Example:**
  /// ```dart
  /// final imc = Imc('/'); // Use slash separator
  /// imc.register('api/v1/users', callback);
  /// ```
  Imc([String sep = '.']) : _sep = sep;

  /// Root node of the action tree.
  final _root = _ImcNode('root');

  /// Separator character(s) used to split action paths.
  final String _sep;

  /// Splits an action string into path segments.
  List<String> _path(String action) => action.split(_sep);

  /// Registers a callback for the specified action path.
  ///
  /// Actions are hierarchical paths separated by [_sep] (default '.').
  /// All callbacks along the path execute in order, creating a middleware
  /// chain where each callback can:
  /// - Validate or transform data
  /// - Perform side effects (logging, metrics, etc.)
  /// - Return values accessible to subsequent callbacks via [ImcContext.last]
  /// - Throw exceptions to halt the chain
  ///
  /// **Parameters:**
  /// - [name]: Dot-separated action path (e.g., 'user.auth.login')
  /// - [callback]: Function receiving [ImcContext] with:
  ///   - `data`: Initial parameters from [call]
  ///   - `last`: Result from previous callback
  ///   - `path`: Complete path as list
  ///   - `current`: Current segment being processed
  ///
  /// **Execution Order:** For 'a.b.c', callbacks execute as:
  /// 1. 'a' callback
  /// 2. 'a.b' callback
  /// 3. 'a.b.c' callback
  ///
  /// **Throws:**
  /// - [ImcException] if [name] is already registered
  ///
  /// **Example:**
  /// ```dart
  /// // Middleware: runs for all 'user.*' actions
  /// imc.register('user', (ctx) async {
  ///   final userId = ctx.data;
  ///   final user = await fetchUser(userId);
  ///   if (user == null) throw UserNotFoundException();
  ///   return user; // Available in ctx.last for child callbacks
  /// });
  ///
  /// // Endpoint: executes after 'user' middleware
  /// imc.register('user.permissions', (ctx) {
  ///   final user = ctx.last; // From 'user' callback
  ///   return user.permissions;
  /// });
  ///
  /// // Execute: user middleware runs first, then permissions
  /// final perms = await imc.call('user.permissions', userId);
  /// ```
  void register(String name, ImcCallback callback) {
    final path = _path(name);
    _root._register(path, callback);
  }

  /// Executes all callbacks along the action path.
  ///
  /// Traverses the action tree from root to leaf, executing each registered
  /// callback in sequence. Each callback receives the context with results
  /// from previous callbacks accessible via [ImcContext.last].
  ///
  /// **Parameters:**
  /// - [action]: Hierarchical action path (e.g., 'api.v1.users.create')
  /// - [params]: Data passed to callbacks via [ImcContext.data]
  ///
  /// **Returns:** The return value from the final callback in the chain.
  ///
  /// **Throws:**
  /// - [ImcException] if any path segment isn't registered, with a
  ///   Levenshtein distance-based suggestion for the closest match
  ///
  /// **Example:**
  /// ```dart
  /// // Register middleware chain
  /// imc.register('api', authMiddleware);
  /// imc.register('api.users', rateLimitMiddleware);
  /// imc.register('api.users.get', getUserHandler);
  ///
  /// // Execute chain: auth -> rateLimit -> getUser
  /// final user = await imc.call('api.users.get', userId);
  ///
  /// // Typo handling
  /// try {
  ///   await imc.call('api.user.get', userId); // Wrong: 'user' not 'users'
  /// } catch (e) {
  ///   // ImcException: Did you mean 'users' instead of 'user'?
  /// }
  /// ```
  Future<dynamic> call(String action, dynamic params) async {
    final path = _path(action);
    return _root._walk(path, params);
  }
}
