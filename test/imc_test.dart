import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  late Imc imc;

  setUp(() {
    imc = Imc();
  });

  group('IMC Registration', () {
    test('should register simple callback', () {
      expect(
        () => imc.register('test.action', (ctx) => 'result'),
        returnsNormally,
      );
    });

    test('should register nested paths', () {
      expect(
        () => imc.register('module.sub.action', (ctx) => 'result'),
        returnsNormally,
      );
    });
  });

  group('IMC Execution', () {
    test('should execute single callback', () async {
      imc.register('test.action', (ctx) => 'result');

      final result = await imc('test.action', null);

      expect(result, equals('result'));
    });

    test('should pass data through context', () async {
      dynamic receivedData;

      imc.register('test.action', (ctx) {
        receivedData = ctx.data;
      });

      await imc('test.action', [1, 2, 3]);

      expect(receivedData, equals([1, 2, 3]));
    });

    test('should provide correct path in context', () async {
      List<String>? receivedPath;

      imc.register('module.sub.action', (ctx) {
        receivedPath = ctx.path;
      });

      await imc('module.sub.action', null);

      expect(receivedPath, equals(['module', 'sub', 'action']));
    });

    test('should handle async callbacks', () async {
      imc.register('test.action', (ctx) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'async result';
      });

      final result = await imc('test.action', null);

      expect(result, equals('async result'));
    });

    test('should throw ImcException for unregistered path', () async {
      expect(
        () async => imc('nonexistent.action', null),
        throwsA(isA<ImcException>()),
      );
    });

    test('should throw ImcException for partially registered path', () async {
      imc.register('test.action', (ctx) => 'result');

      expect(
        () async => imc('test.action.nested', null),
        throwsA(isA<ImcException>()),
      );
    });
  });

  group('IMC Middleware attern', () {
    test('should execute middleware before final action', () async {
      final executionOrder = <String>[];

      imc.register('auth', (ctx) {
        executionOrder.add('auth middleware');
      });

      imc.register('auth.login', (ctx) {
        executionOrder.add('login action');
        return 'logged in';
      });

      await imc('auth.login', null);

      expect(executionOrder, equals(['auth middleware', 'login action']));
    });

    test('should pass modified data through middleware chain', () async {
      imc.register('process', (ctx) {
        ctx.data = '${ctx.data}_processed';
      });

      imc.register('process.validate', (ctx) {
        ctx.data = '${ctx.data}_validated';
      });

      imc.register('process.validate.save', (ctx) {
        return ctx.data;
      });

      final result = await imc('process.validate.save', 'data');

      expect(result, equals('data_processed_validated'));
    });
  });

  group('IMC Context Behavior', () {
    test('should maintain separate context per call', () async {
      final contexts = <ImcContext>[];

      imc.register('test.action', contexts.add);

      await imc('test.action', 'data1');
      await imc('test.action', 'data2');

      expect(contexts.length, equals(2));
      expect(contexts[0].data, equals('data1'));
      expect(contexts[1].data, equals('data2'));
      expect(identical(contexts[0], contexts[1]), isFalse);
    });

    test('should increment index as path is traversed', () async {
      final indices = <String>[];

      imc.register('level1', (ctx) => indices.add(ctx.current));
      imc.register('level1.level2', (ctx) => indices.add(ctx.current));
      imc.register('level1.level2.level3', (ctx) => indices.add(ctx.current));

      await imc('level1.level2.level3', null);

      expect(indices, equals(['level1', 'level2', 'level3']));
    });
  });

  group('IMC Error Handling', () {
    test('should propagate callback exceptions', () async {
      imc.register('test.error', (ctx) {
        throw Exception('Test error');
      });

      expect(() async => imc('test.error', null), throwsException);
    });

    test('should not execute remaining callbacks after exception', () async {
      var secondCallbackExecuted = false;

      imc.register('test', (ctx) {
        throw Exception('Test error');
      });

      imc.register('test.error', (ctx) {
        secondCallbackExecuted = true;
      });

      try {
        await imc('test.error', null);
      } catch (_) {}

      expect(secondCallbackExecuted, isFalse);
    });

    test(
      'should provide helpful error message for unregistered path',
      () async {
        try {
          await imc('unregistered.path', null);
          fail('Should have thrown ImcException');
        } catch (e) {
          expect(e, isA<ImcException>());
          expect(e.toString(), contains('not registered yet'));
        }
      },
    );
  });

  group('IMC Edge Cases', () {
    test('should handle null data', () async {
      dynamic receivedData;

      imc.register('test.action', (ctx) {
        receivedData = ctx.data;
      });

      await imc('test.action', null);

      expect(receivedData, isNull);
    });

    test('should handle complex object data', () async {
      final testData = {
        'key': 'value',
        'nested': {'data': 123},
      };
      dynamic receivedData;

      imc.register('test.action', (ctx) {
        receivedData = ctx.data;
      });

      await imc('test.action', testData);

      expect(receivedData, equals(testData));
    });

    test('should handle single-segment paths', () async {
      imc.register('single', (ctx) => 'result');

      final result = await imc('single', null);

      expect(result, equals('result'));
    });

    test('should handle deeply nested paths', () async {
      imc.register('a.b.c.d.e.f', (ctx) => 'deep');

      final result = await imc('a.b.c.d.e.f', null);

      expect(result, equals('deep'));
    });

    test('should return null if no callbacks return value', () async {
      imc.register('test.action', (ctx) {
        // No return statement
      });

      final result = await imc('test.action', null);

      expect(result, isNull);
    });
  });

  group('IMC erformance', () {
    test('should handle multiple rapid sequential calls', () async {
      imc.register('test.action', (ctx) => 'result');

      final futures = List.generate(100, (i) => imc('test.action', i));

      final results = await Future.wait(futures);

      expect(results.length, equals(100));
      expect(results.every((r) => r == 'result'), isTrue);
    });

    test('should handle concurrent calls correctly', () async {
      var callCount = 0;

      imc.register('test.action', (ctx) async {
        await Future.delayed(const Duration(milliseconds: 10));
        callCount++;
        return callCount;
      });

      final futures = List.generate(10, (_) => imc('test.action', null));

      await Future.wait(futures);

      expect(callCount, equals(10));
    });
  });
}
