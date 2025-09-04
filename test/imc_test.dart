import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  group('IMC Tests', () {
    late IMC imc;

    setUp(() {
      imc = IMC();
    });

    tearDown(() {
      imc.dispose();
    });

    group('Registration Tests', () {
      test('should register a simple callback successfully', () {
        expect(() {
          imc.register<String, String>('user.getById', (ctx) {
            return 'User: ${ctx.params}';
          });
        }, returnsNormally);
      });

      test('should register nested paths successfully', () {
        expect(() {
          imc.register<void, void>('module.submodule.action', (ctx) {});
        }, returnsNormally);
      });

      test('should register middleware callbacks', () {
        expect(() {
          imc.register<void, String>('user', (ctx) {
            // Middleware logic
          });
          imc.register<String, String>('user.getById', (ctx) {
            return 'User: ${ctx.params}';
          });
        }, returnsNormally);
      });

      test('should allow multiple callbacks on same path prefix', () {
        expect(() {
          imc.register<void, void>('auth', (ctx) {});
          imc.register<bool, String>('auth.login', (ctx) => true);
          imc.register<void, void>('auth.logout', (ctx) {});
        }, returnsNormally);
      });
    });

    // group('Execution Tests', () {
    //   test('should execute simple callback successfully', () async {
    //     String? result;
    //     imc.register<String, String>('user.getById', (ctx) {
    //       return 'User: ${ctx.params}';
    //     });
    //
    //     result = await imc.call<String, String>('user.getById', 'user123');
    //     expect(result, equals('User: user123'));
    //   });
    //
    //   test('should execute async callback successfully', () async {
    //     imc.register<String, String>('user.getById', (ctx) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return 'User: ${ctx.params}';
    //     });
    //
    //     final result = await imc.call<String, String>(
    //       'user.getById',
    //       'user123',
    //     );
    //     expect(result, equals('User: user123'));
    //   });
    //
    //   test('should execute middleware chain correctly', () async {
    //     final executionOrder = <String>[];
    //
    //     imc.register<void, String>('user', (ctx) {
    //       executionOrder.add('middleware');
    //     });
    //
    //     imc.register<String, String>('user.getById', (ctx) {
    //       executionOrder.add('action');
    //       return 'User: ${ctx.params}';
    //     });
    //
    //     await imc.call<String, String>('user.getById', 'user123');
    //     expect(executionOrder, equals(['middleware', 'action']));
    //   });
    //
    //   test('should execute multiple middleware levels', () async {
    //     final executionOrder = <String>[];
    //
    //     imc.register<void, String>('auth', (ctx) {
    //       executionOrder.add('auth-middleware');
    //     });
    //
    //     imc.register<void, String>('auth.user', (ctx) {
    //       executionOrder.add('user-middleware');
    //     });
    //
    //     imc.register<String, String>('auth.user.getById', (ctx) {
    //       executionOrder.add('action');
    //       return 'User: ${ctx.params}';
    //     });
    //
    //     await imc.call<String, String>('auth.user.getById', 'user123');
    //     expect(
    //       executionOrder,
    //       equals(['auth-middleware', 'user-middleware', 'action']),
    //     );
    //   });
    //
    //   test('should throw ImcException for unregistered path', () async {
    //     expect(
    //       () async =>
    //           await imc.call<String, String>('nonexistent.action', 'params'),
    //       throwsA(isA<ImcException>()),
    //     );
    //   });
    //
    //   test('should handle null params correctly', () async {
    //     imc.register<String, String?>('user.getDefault', (ctx) {
    //       return ctx.params == null ? 'Default User' : 'User: ${ctx.params}';
    //     });
    //
    //     final result = await imc.call<String, String?>('user.getDefault', null);
    //     expect(result, equals('Default User'));
    //   });
    //
    //   test('should handle complex object params', () async {
    //     final testUser = TestUser('John', 25);
    //
    //     imc.register<String, TestUser>('user.create', (ctx) {
    //       return 'Created: ${ctx.params.name} (${ctx.params.age})';
    //     });
    //
    //     final result = await imc.call<String, TestUser>(
    //       'user.create',
    //       testUser,
    //     );
    //     expect(result, equals('Created: John (25)'));
    //   });
    // });

    // group('ImcContext Tests', () {
    //   test('should provide correct params in context', () async {
    //     String? receivedParams;
    //     String? receivedPath;
    //
    //     imc.register<void, String>('test.action', (ctx) {
    //       receivedParams = ctx.params;
    //       receivedPath = ctx.path;
    //     });
    //
    //     await imc.call<void, String>('test.action', 'test-params');
    //
    //     expect(receivedParams, equals('test-params'));
    //     expect(receivedPath, equals('test.action'));
    //   });
    //
    //   test('should provide dependency injector in context', () async {
    //     DependencyInjector? receivedDI;
    //
    //     imc.register<void, void>('test.action', (ctx) {
    //       receivedDI = ctx.di;
    //     });
    //
    //     await imc.call<void, void>('test.action', null);
    //
    //     expect(receivedDI, isNotNull);
    //     expect(receivedDI, isA<DependencyInjector>());
    //   });
    // });

    // group('Dependency Injection Tests', () {
    //   test(
    //     'should support dependency injection between middleware and action',
    //     () async {
    //       imc.register<void, String>('user', (ctx) {
    //         ctx.di.put(TestService(ctx.params));
    //       });
    //
    //       imc.register<String, String>('user.getById', (ctx) {
    //         final service = ctx.di.get<TestService>();
    //         return service.getData();
    //       });
    //
    //       final result = await imc.call<String, String>(
    //         'user.getById',
    //         'test-data',
    //       );
    //       expect(result, equals('Service data: test-data'));
    //     },
    //   );
    //
    //   test(
    //     'should maintain separate DI contexts for different calls',
    //     () async {
    //       imc.register<void, String>('user', (ctx) {
    //         ctx.di.put(TestService(ctx.params));
    //       });
    //
    //       imc.register<String, String>('user.getById', (ctx) {
    //         final service = ctx.di.get<TestService>();
    //         return service.getData();
    //       });
    //
    //       final result1 = await imc.call<String, String>(
    //         'user.getById',
    //         'data1',
    //       );
    //       final result2 = await imc.call<String, String>(
    //         'user.getById',
    //         'data2',
    //       );
    //
    //       expect(result1, equals('Service data: data1'));
    //       expect(result2, equals('Service data: data2'));
    //     },
    //   );
    // });

    // group('Error Handling Tests', () {
    //   test('should handle exceptions in callbacks gracefully', () async {
    //     imc.register<String, String>('user.error', (ctx) {
    //       throw Exception('Test error');
    //     });
    //
    //     expect(
    //       () async => await imc.call<String, String>('user.error', 'params'),
    //       throwsException,
    //     );
    //   });
    //
    //   test('should handle async exceptions in callbacks', () async {
    //     imc.register<String, String>('user.asyncError', (ctx) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       throw Exception('Async test error');
    //     });
    //
    //     expect(
    //       () async =>
    //           await imc.call<String, String>('user.asyncError', 'params'),
    //       throwsException,
    //     );
    //   });
    // });

    // group('Disposal Tests', () {
    //   test('should dispose successfully', () {
    //     expect(() => imc.dispose(), returnsNormally);
    //   });
    //
    //   test('should throw ImcException when used after disposal', () {
    //     imc.dispose();
    //
    //     expect(
    //       () => imc.register<void, void>('test.action', (ctx) {}),
    //       throwsA(isA<ImcException>()),
    //     );
    //   });
    //
    //   test('should not throw when disposing multiple times', () {
    //     imc.dispose();
    //     expect(() => imc.dispose(), returnsNormally);
    //   });
    // });

    // group('Edge Cases', () {
    //   test('should handle empty string path segments gracefully', () {
    //     expect(
    //       () => imc.register<void, void>('', (ctx) {}),
    //       throwsA(isA<ImcException>()),
    //     );
    //   });
    //
    //   test('should handle single segment paths', () async {
    //     imc.register<String, String>(
    //       'action',
    //       (ctx) => 'Result: ${ctx.params}',
    //     );
    //
    //     final result = await imc.call<String, String>('action', 'test');
    //     expect(result, equals('Result: test'));
    //   });
    //
    //   test('should handle very deep nested paths', () async {
    //     imc.register<String, String>(
    //       'a.b.c.d.e.f.action',
    //       (ctx) => 'Deep: ${ctx.params}',
    //     );
    //
    //     final result = await imc.call<String, String>(
    //       'a.b.c.d.e.f.action',
    //       'test',
    //     );
    //     expect(result, equals('Deep: test'));
    //   });
    // });

    // group('Type Safety Tests', () {
    // test('should work with different return types', () async {
    //   imc.register<int, String>('math.length', (ctx) => ctx.params.length);
    //   imc.register<bool, int>('math.isEven', (ctx) => ctx.params % 2 == 0);
    //   imc.register<List<String>, String>(
    //     'string.split',
    //     (ctx) => ctx.params.split(' '),
    //   );
    //
    //   expect(await imc.call<int, String>('math.length', 'hello'), equals(5));
    //   expect(await imc.call<bool, int>('math.isEven', 4), isTrue);
    //   expect(
    //     await imc.call<List<String>, String>('string.split', 'a b c'),
    //     equals(['a', 'b', 'c']),
    //   );
    // });

    // test('should work with complex generic types', () async {
    //   imc.register<Map<String, dynamic>, TestUser>('user.serialize', (ctx) {
    //     return {'name': ctx.params.name, 'age': ctx.params.age};
    //   });
    //
    //   final user = TestUser('Alice', 30);
    //   final result = await imc.call<Map<String, dynamic>, TestUser>(
    //     'user.serialize',
    //     user,
    //   );
    //
    //   expect(result, equals({'name': 'Alice', 'age': 30}));
    // });
    // });

    // group('Performance Tests', () {
    //   test('should handle multiple rapid calls efficiently', () async {
    //     imc.register<String, int>('perf.echo', (ctx) => 'Value: ${ctx.params}');
    //
    //     final futures = List.generate(
    //       100,
    //       (i) => imc.call<String, int>('perf.echo', i),
    //     );
    //
    //     final results = await Future.wait(futures);
    //
    //     expect(results.length, equals(100));
    //     expect(results[50], equals('Value: 50'));
    //   });
    // });
  });
}

// Test helper classes
class TestUser {
  final String name;
  final int age;

  TestUser(this.name, this.age);
}

class TestService {
  final String data;

  TestService(this.data);

  String getData() => 'Service data: $data';
}
