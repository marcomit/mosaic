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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

class _M extends Module {
  _M(String name) : super(name: name);
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifecyclePolicy', () {
    tearDown(() async {
      await mosaic.registry.disposeAll();
      mosaic.reset();
    });

    test('memory policy suspends modules outside the keepAlive window', () async {
      final a = _M('a');
      final b = _M('b');
      final c = _M('c');
      for (final m in [a, b, c]) {
        await mosaic.registry.register(m);
      }
      await mosaic.registry.initialize(a, [a, b, c]);

      // Navigate a -> b -> c so history is [a, b, c].
      await mosaic.router.go('b');
      await mosaic.router.go('c');

      final policy = LifecyclePolicy(keepAlive: 1);
      await policy.enforceMemoryPolicy();

      // Current is c (kept); a and b are outside the keepAlive=1 window.
      expect(c.active, isTrue);
      expect(a.state, ModuleLifecycleState.suspended);
      expect(b.state, ModuleLifecycleState.suspended);
    });

    test('suspends the current module on background and resumes it', () async {
      final a = _M('a');
      await mosaic.registry.register(a);
      await mosaic.registry.initialize(a, [a]);

      final policy = LifecyclePolicy();
      policy.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(a.state, ModuleLifecycleState.suspended);

      policy.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(a.active, isTrue);
    });
  });
}
