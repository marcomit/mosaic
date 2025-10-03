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
import 'package:mosaic/mosaic.dart';

// import 'package:mosaic/src/dependency_injection/dependency_injector.dart';

typedef ImcCallback = FutureOr<dynamic> Function(ImcContext);

class ImcContext {
  ImcContext(this.data, this.path);
  final List<String> path;
  dynamic data;
  dynamic last;
  int _index = 0;
  String get current => path[_index];
}

class _ImcNode {
  _ImcNode(this.name);
  final String name;
  final Map<String, _ImcNode> children = {};
  final List<ImcCallback> callbacks = [];

  Future<dynamic> _walk(List<String> path, dynamic data) async {
    _ImcNode curr = this;
    final context = ImcContext(data, path);
    for (final segment in path) {
      if (!curr.children.containsKey(segment)) {
        throw ImcException(
          'The action $segment of $path is not registered yet',
          fix: 'Try to register a callback in this path before calling it',
        );
      }
      curr = curr.children[segment]!;
      await curr._execute(context);
      context._index++;
    }
    return context.last;
  }

  Future<void> _execute(ImcContext ctx) async {
    for (final callback in callbacks) {
      ctx.last = await callback(ctx);
    }
  }

  void _register(List<String> path, ImcCallback callback) {
    _ImcNode curr = this;
    for (final segment in path) {
      if (!curr.children.containsKey(segment)) {
        curr.children[segment] = _ImcNode(segment);
      }
      curr = curr.children[segment]!;
    }
    curr.callbacks.add(callback);
  }
}

class Imc {
  final _root = _ImcNode('root');
  final String sep = '.';

  void register(String name, ImcCallback callback) {
    final path = name.split(sep);
    _root._register(path, callback);
  }

  Future<dynamic> call(String action, dynamic params) async {
    final path = action.split(sep);
    return _root._walk(path, params);
  }
}

class ImcException extends MosaicException {
  ImcException(super.message, {super.cause, super.fix});
  @override
  String get name => 'ImcException';
}

void main() async {
  final imc = Imc();
  imc.register('test.test01', (ctx) {
    // print(ctx.path);
    // print(ctx.current);
    // print(ctx.data);
    return 'pippo';
  });
  imc.register('test.test01', (ctx) {
    // print(ctx.data);
    print(ctx.current);
    return 'dai';
  });

  final result = await imc('test.test01', [1, 2, 3, 4]);
  print('Result $result');
}
