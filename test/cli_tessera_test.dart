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

import 'package:flutter_test/flutter_test.dart';

import '../bin/exception.dart';
import '../bin/models/tessera.dart';

Tessera _t(
  String name, {
  List<String> deps = const [],
  bool lazy = false,
  String? gate,
}) =>
    Tessera(name, path: '/tmp/$name', dependencies: deps, lazy: lazy, gate: gate);

void main() {
  group('Tessera.topologicalSort', () {
    test('orders dependencies before dependents', () {
      final sorted = Tessera.topologicalSort([
        _t('app', deps: ['auth']),
        _t('auth'),
      ]);
      final names = sorted.map((t) => t.name).toList();
      expect(names.indexOf('auth'), lessThan(names.indexOf('app')));
    });

    test('detects circular dependencies', () {
      expect(
        () => Tessera.topologicalSort([
          _t('a', deps: ['b']),
          _t('b', deps: ['a']),
        ]),
        throwsA(isA<CliException>()),
      );
    });

    test('rejects a dependency on a missing tessera', () {
      expect(
        () => Tessera.topologicalSort([_t('a', deps: ['ghost'])]),
        throwsA(isA<CliException>()),
      );
    });
  });

  group('Tessera codegen', () {
    test('eager registration uses register()', () {
      final code = _t('cart', deps: ['catalog']).generateInitialization();
      expect(code, contains('mosaic.registry.register(cart.module)'));
      expect(code, contains('cart.module.dependencies.add(catalog.module)'));
      expect(code, isNot(contains('registerLazy')));
    });

    test('lazy registration uses registerLazy() with deps', () {
      final code = _t('cart', deps: ['catalog'], lazy: true)
          .generateInitialization();
      expect(code, contains('mosaic.registry.registerLazy('));
      expect(code, contains("'cart'"));
      expect(code, contains('() => cart.CartModule()'));
      expect(code, contains("dependencies: ['catalog']"));
      expect(code, isNot(contains('gate:')));
    });

    test('a gated lazy tessera emits a feature gate', () {
      final code =
          _t('cart', lazy: true, gate: 'cart_on').generateInitialization();
      expect(code, contains("gate: mosaic.features.gate('cart_on')"));
    });
  });

  group('Tessera serialization', () {
    test('round-trips lazy and gate fields', () {
      final json = _t('cart', lazy: true, gate: 'cart_on', deps: ['x'])
          .serialize();
      expect(json['lazy'], true);
      expect(json['gate'], 'cart_on');

      final parsed = Tessera.fromJson(json, '/tmp/cart');
      expect(parsed.lazy, isTrue);
      expect(parsed.gate, 'cart_on');
      expect(parsed.dependencies, ['x']);
    });

    test('omits lazy/gate when unset', () {
      final json = _t('plain').serialize();
      expect(json.containsKey('lazy'), isFalse);
      expect(json.containsKey('gate'), isFalse);
    });

    test('defaultConfig includes lazy and gate when set', () {
      final config = _t('cart', lazy: true, gate: 'cart_on').defaultConfig;
      expect(config, contains('lazy: true'));
      expect(config, contains('gate: cart_on'));
    });
  });
}
