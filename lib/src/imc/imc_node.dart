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

class ImcNode {
  ImcNode(
    this.name, {
    this.expectedResult = dynamic,
    this.expectedParams = dynamic,
  });
  final String name;
  final Type expectedResult;
  final Type expectedParams;
  // ImcCallback? _callback;
  // final Map<String, ImcNode> _children = {};

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

  // Future<(ImcNode, T)> _executeChild<T>(String name, ImcContext context) async {
  //   if (!_children.containsKey(name)) {
  //     throw ImcException(
  //       'Invalid callback ${context.path}',
  //       cause: 'The handler is not registered',
  //       fix: ' Try to register the handler before call it',
  //     );
  //   }
  //   final child = _children[name]!;
  //
  //   T? result;
  //   if (child._callback != null) {
  //     result = await child._callback!(context);
  //   }
  //   if (result == null) {
  //     throw ImcException('Cannot use null value');
  //   }
  //
  //   return (child, result);
  // }

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
