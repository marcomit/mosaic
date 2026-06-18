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

abstract class GreeterContract extends ModuleContract {
  String greet();
}

class _GreeterApi implements GreeterContract {
  _GreeterApi(this.word);
  final String word;
  @override
  String greet() => word;
}

/// Provides [GreeterContract].
class _ProviderModule extends Module {
  _ProviderModule() : super(name: 'greeter');

  @override
  void provideContracts(ContractRegistry contracts) {
    contracts.provide<GreeterContract>(_GreeterApi('hello'), provider: name);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Requires [GreeterContract].
class _ConsumerModule extends Module {
  _ConsumerModule() : super(name: 'consumer');

  String? captured;

  @override
  List<Type> get requiredContracts => [GreeterContract];

  @override
  Future<void> onInit() async {
    captured = mosaic.contracts.of<GreeterContract>().greet();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

abstract class CalcContract extends ModuleContract {
  Future<int> add(int x);
}

class _CalcApi extends ModuleContract
    with MiddlewareContract
    implements CalcContract {
  @override
  String get channel => 'calc';

  @override
  Future<int> add(int x) => dispatch('add', x);
}

void main() {
  group('MiddlewareContract', () {
    test('dispatches through the IMC middleware chain', () async {
      final calls = <String>[];
      // Middleware on the channel runs before the handler.
      mosaic.imc.register('calc', (ctx) => calls.add('middleware'));
      mosaic.imc.register('calc.add', (ctx) {
        calls.add('handler');
        return (ctx.data as int) + 1;
      });

      final api = _CalcApi();
      final result = await api.add(41);

      expect(result, 42);
      expect(calls, ['middleware', 'handler']);
    });
  });

  group('ContractRegistry', () {
    late ContractRegistry registry;
    setUp(() => registry = ContractRegistry());

    test('provide then of resolves the contract', () {
      registry.provide<GreeterContract>(_GreeterApi('hi'), provider: 'g');
      expect(registry.of<GreeterContract>().greet(), 'hi');
      expect(registry.isProvided<GreeterContract>(), isTrue);
    });

    test('of throws a ContractException when unprovided', () {
      expect(
        () => registry.of<GreeterContract>(),
        throwsA(isA<ContractException>()),
      );
    });

    test('maybe returns null when unprovided', () {
      expect(registry.maybe<GreeterContract>(), isNull);
    });

    test('two providers for the same contract conflict', () {
      registry.provide<GreeterContract>(_GreeterApi('a'), provider: 'one');
      expect(
        () =>
            registry.provide<GreeterContract>(_GreeterApi('b'), provider: 'two'),
        throwsA(isA<ContractException>()),
      );
    });

    test('revokeByProvider removes the contract', () {
      registry.provide<GreeterContract>(_GreeterApi('a'), provider: 'one');
      registry.revokeByProvider('one');
      expect(registry.isProvided<GreeterContract>(), isFalse);
    });
  });

  group('Contracts + module lifecycle', () {
    tearDown(() async {
      await mosaic.registry.disposeAll();
      mosaic.contracts.reset();
      mosaic.features.clear();
    });

    test('a module provides its contracts on init and revokes on dispose',
        () async {
      final module = _ProviderModule();
      await mosaic.registry.register(module);
      await module.initialize();

      expect(mosaic.contracts.isProvided<GreeterContract>(), isTrue);
      expect(mosaic.contracts.of<GreeterContract>().greet(), 'hello');

      await mosaic.registry.unregister(module);
      expect(mosaic.contracts.isProvided<GreeterContract>(), isFalse);
    });

    test('a consumer initializes once its required contract is available',
        () async {
      final provider = _ProviderModule();
      await mosaic.registry.register(provider);
      await provider.initialize();

      final consumer = _ConsumerModule();
      await mosaic.registry.register(consumer);
      await consumer.initialize();

      expect(consumer.captured, 'hello');
    });

    test('a consumer fails fast when a required contract is missing', () async {
      final consumer = _ConsumerModule();
      await mosaic.registry.register(consumer);

      await expectLater(
        consumer.initialize(),
        throwsA(isA<ContractException>()),
      );
    });

    test('requiring a contract auto-loads its declared lazy provider',
        () async {
      mosaic.registry.registerLazy(
        'greeter',
        _ProviderModule.new,
        provides: [GreeterContract],
      );

      final consumer = _ConsumerModule();
      await mosaic.registry.register(consumer);
      await consumer.initialize();

      expect(mosaic.registry.isLoaded('greeter'), isTrue);
      expect(consumer.captured, 'hello');
    });

    test('resolve loads the declared lazy provider on demand', () async {
      mosaic.registry.registerLazy(
        'greeter',
        _ProviderModule.new,
        provides: [GreeterContract],
      );

      final api = await mosaic.contracts.resolve<GreeterContract>();
      expect(api.greet(), 'hello');
      expect(mosaic.registry.isLoaded('greeter'), isTrue);
    });
  });
}
