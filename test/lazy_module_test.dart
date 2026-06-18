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

class _TestModule extends Module {
  _TestModule(String name) : super(name: name);

  int initCount = 0;

  @override
  Future<void> onInit() async => initCount++;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('Lazy module loading', () {
    tearDown(() async {
      await mosaic.registry.disposeAll();
      mosaic.contracts.reset();
      mosaic.features.clear();
    });

    test('registerLazy does not construct the module', () {
      var built = 0;
      mosaic.registry.registerLazy('a', () {
        built++;
        return _TestModule('a');
      });

      expect(built, 0);
      expect(mosaic.registry.isRegistered('a'), isTrue);
      expect(mosaic.registry.isLazy('a'), isTrue);
      expect(mosaic.registry.isLoaded('a'), isFalse);
    });

    test('load constructs and initializes the module', () async {
      var built = 0;
      mosaic.registry.registerLazy('a', () {
        built++;
        return _TestModule('a');
      });

      final module = await mosaic.registry.load('a') as _TestModule;

      expect(built, 1);
      expect(module.initCount, 1);
      expect(module.active, isTrue);
      expect(mosaic.registry.isLoaded('a'), isTrue);
      expect(mosaic.registry.isLazy('a'), isFalse);
    });

    test('load is idempotent', () async {
      var built = 0;
      mosaic.registry.registerLazy('a', () {
        built++;
        return _TestModule('a');
      });

      final first = await mosaic.registry.load('a');
      final second = await mosaic.registry.load('a');

      expect(built, 1);
      expect(identical(first, second), isTrue);
    });

    test('lazy dependencies load before the dependent module', () async {
      final order = <String>[];
      mosaic.registry.registerLazy('dep', () {
        order.add('dep');
        return _TestModule('dep');
      });
      mosaic.registry.registerLazy('main', () {
        order.add('main');
        return _TestModule('main');
      }, dependencies: ['dep']);

      await mosaic.registry.load('main');

      expect(order, ['dep', 'main']);
      expect(mosaic.registry.isLoaded('dep'), isTrue);
    });

    test('a disabled gate prevents loading', () async {
      mosaic.registry.registerLazy(
        'gated',
        () => _TestModule('gated'),
        gate: () => false,
      );

      expect(
        () => mosaic.registry.load('gated'),
        throwsA(isA<ModuleException>()),
      );
      expect(mosaic.registry.isLoaded('gated'), isFalse);
    });

    test('a feature flag can gate a module', () async {
      mosaic.registry.registerLazy(
        'flagged',
        () => _TestModule('flagged'),
        gate: mosaic.features.gate('flagged_on'),
      );

      expect(await mosaic.registry.isAvailable('flagged'), isFalse);

      mosaic.features.enable('flagged_on');
      expect(await mosaic.registry.isAvailable('flagged'), isTrue);
      await mosaic.registry.load('flagged');
      expect(mosaic.registry.isActive('flagged'), isTrue);
    });

    test('circular lazy dependencies are detected', () async {
      mosaic.registry.registerLazy(
        'x',
        () => _TestModule('x'),
        dependencies: ['y'],
      );
      mosaic.registry.registerLazy(
        'y',
        () => _TestModule('y'),
        dependencies: ['x'],
      );

      expect(() => mosaic.registry.load('x'), throwsA(isA<ModuleException>()));
    });

    test('duplicate registration is rejected', () {
      mosaic.registry.registerLazy('dup', () => _TestModule('dup'));
      expect(
        () => mosaic.registry.registerLazy('dup', () => _TestModule('dup')),
        throwsA(isA<ModuleException>()),
      );
    });

    test('a name mismatch from the factory is rejected', () {
      mosaic.registry.registerLazy('declared', () => _TestModule('actual'));
      expect(
        () => mosaic.registry.load('declared'),
        throwsA(isA<ModuleException>()),
      );
    });

    test('ensureActive loads then activates a lazy module', () async {
      mosaic.registry.registerLazy('e', () => _TestModule('e'));
      final module = await mosaic.registry.ensureActive('e');
      expect(module.active, isTrue);
      expect(mosaic.registry.isActive('e'), isTrue);
    });
  });
}
