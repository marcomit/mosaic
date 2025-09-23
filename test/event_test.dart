import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  mosaic.logger.init(tags: [], dispatchers: [ConsoleDispatcher()]);
  group('Events Core Functionality', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    group('Basic Event Operations', () {
      test('should emit and receive simple events', () {
        String? received;

        events.on<String>('test/channel', (context) {
          received = context.data;
        });

        events.emit<String>('test/channel', 'test data');

        expect(received, equals('test data'));
      });

      test('should handle events with null data', () {
        String? receivedData;
        String? receivedChannel;

        events.on<String>('null/test', (context) {
          receivedData = context.data;
          receivedChannel = context.name;
        });

        events.emit<String>('null/test');

        expect(receivedData, isNull);
        expect(receivedChannel, equals('null/test'));
      });

      test('should handle multiple listeners on same channel', () {
        final received = <String>[];

        events.on<String>('multi/test', (ctx) => received.add('listener1'));
        events.on<String>('multi/test', (ctx) => received.add('listener2'));
        events.on<String>('multi/test', (ctx) => received.add('listener3'));

        events.emit<String>('multi/test', 'data');

        expect(received, containsAll(['listener1', 'listener2', 'listener3']));
        expect(received.length, equals(3));
      });

      test('should handle different data types', () {
        int? intData;
        bool? boolData;
        Map<String, dynamic>? mapData;

        events.on<int>('type/int', (ctx) => intData = ctx.data);
        events.on<bool>('type/bool', (ctx) => boolData = ctx.data);
        events.on<Map<String, dynamic>>(
          'type/map',
          (ctx) => mapData = ctx.data,
        );

        events.emit<int>('type/int', 42);
        events.emit<bool>('type/bool', true);
        events.emit<Map<String, dynamic>>('type/map', {'key': 'value'});

        expect(intData, equals(42));
        expect(boolData, isTrue);
        expect(mapData, equals({'key': 'value'}));
      });

      test('should ignore listeners for different channels', () {
        String? received;

        events.on<String>('channel/a', (ctx) => received = ctx.data);
        events.emit<String>('channel/b', 'test data');

        expect(received, isNull);
      });
    });

    group('Wildcard Pattern Matching', () {
      test('should match single segment wildcard (*)', () {
        final received = <String>[];

        events.on<String>('user/*/update', (ctx) {
          received.add('${ctx.name}:${ctx.params[0]}');
        });

        events.emit<String>('user/profile/update', 'profile data');
        events.emit<String>('user/settings/update', 'settings data');
        events.emit<String>('user/preferences/update', 'prefs data');

        expect(received, hasLength(3));
        expect(received, contains('user/profile/update:profile'));
        expect(received, contains('user/settings/update:settings'));
        expect(received, contains('user/preferences/update:preferences'));
      });

      test('should match global wildcard (#)', () {
        final received = <List<String>>[];

        events.on<String>('api/#', (ctx) {
          received.add(ctx.params);
        });

        events.emit<String>('api/v1/users/123', 'data1');
        events.emit<String>('api/v2/posts/456/comments', 'data2');
        events.emit<String>('api/health', 'data3');

        expect(received, hasLength(3));
        expect(received[0], equals(['v1', 'users', '123']));
        expect(received[1], equals(['v2', 'posts', '456', 'comments']));
        expect(received[2], equals(['health']));
      });

      test('should handle multiple wildcards in pattern', () {
        final received = <List<String>>[];

        events.on<String>('*/api/*/data', (ctx) {
          received.add(ctx.params);
        });

        events.emit<String>('v1/api/users/data', 'user data');
        events.emit<String>('v2/api/posts/data', 'post data');
        events.emit<String>('v1/api/invalid/other', 'should not match');

        expect(received, hasLength(2));
        expect(received[0], equals(['v1', 'users']));
        expect(received[1], equals(['v2', 'posts']));
      });

      test('should handle edge cases with wildcards', () {
        final received = <String>[];

        // Empty channel should not match anything
        events.on<String>('', (ctx) => received.add('empty'));
        events.emit<String>('test', 'data');

        expect(received, isEmpty);
      });

      test('should match exact paths when no wildcards', () {
        String? received;

        events.on<String>('exact/path/match', (ctx) => received = ctx.data);

        events.emit<String>('exact/path/match', 'matched');
        events.emit<String>('exact/path/different', 'not matched');

        expect(received, equals('matched'));
      });
    });

    group('Retained Events', () {
      test('should deliver retained events to new listeners', () {
        events.emit<String>('retained/test', 'retained data', true);

        String? received;
        events.on<String>('retained/test', (ctx) => received = ctx.data);

        expect(received, equals('retained data'));
      });

      test('should deliver multiple retained events', () {
        events.emit<String>('retained/1', 'data1', true);
        events.emit<String>('retained/2', 'data2', true);
        events.emit<String>('retained/3', 'data3', true);

        final received = <String>[];
        events.on<String>('retained/*', (ctx) => received.add(ctx.data!));

        expect(received, containsAll(['data1', 'data2', 'data3']));
        expect(received.length, equals(3));
      });

      test('should not deliver non-retained events to new listeners', () {
        events.emit<String>('not/retained', 'should not receive', false);

        String? received;
        events.on<String>('not/retained', (ctx) => received = ctx.data);

        expect(received, isNull);
      });

      test('should clear retained events', () {
        events.emit<String>('retained/test', 'data', true);
        expect(events.retainedEventCount, equals(1));

        events.clearRetained();
        expect(events.retainedEventCount, equals(0));

        String? received;
        events.on<String>('retained/test', (ctx) => received = ctx.data);
        expect(received, isNull);
      });

      test('should list retained channels', () {
        events.emit<String>('retained/1', 'data1', true);
        events.emit<String>('retained/2', 'data2', true);

        final channels = events.retainedChannels;
        expect(channels, containsAll(['retained/1', 'retained/2']));
        expect(channels.length, equals(2));
      });
    });

    group('Listener Management', () {
      test('should remove specific listener', () {
        String? received;

        final listener = events.on<String>('test/remove', (ctx) {
          received = ctx.data;
        });

        events.emit<String>('test/remove', 'before removal');
        expect(received, equals('before removal'));

        events.deafen(listener);
        received = null;

        events.emit<String>('test/remove', 'after removal');
        expect(received, isNull);
      });

      test('should handle removing non-existent listener gracefully', () {
        final listener = EventListener<String>(['fake'], (ctx) {});

        expect(() => events.deafen(listener), returnsNormally);
      });

      test('should pop most recent listener', () {
        final received = <String>[];

        events.on<String>('test/pop', (ctx) => received.add('listener1'));
        events.on<String>('test/pop', (ctx) => received.add('listener2'));

        events.pop(); // Remove listener2

        events.emit<String>('test/pop', 'data');

        expect(received, equals(['listener1']));
      });

      test('should handle pop on empty listener list', () {
        expect(() => events.pop(), returnsNormally);
      });

      test('should clear all listeners and retained events', () {
        events.on<String>('test/clear', (ctx) {});
        events.emit<String>('retained/clear', 'data', true);

        expect(events.listenerCount, equals(1));
        expect(events.retainedEventCount, equals(1));

        events.clear();

        expect(events.listenerCount, equals(0));
        expect(events.retainedEventCount, equals(0));
      });

      test('should track listener count correctly', () {
        expect(events.listenerCount, equals(0));

        final listener1 = events.on<String>('test/1', (ctx) {});
        expect(events.listenerCount, equals(1));

        final listener2 = events.on<String>('test/2', (ctx) {});
        expect(events.listenerCount, equals(2));

        events.deafen(listener1);
        expect(events.listenerCount, equals(1));

        events.deafen(listener2);
        expect(events.listenerCount, equals(0));
      });
    });

    group('Once and Wait Operations', () {
      test('should handle once listener correctly', () async {
        int callCount = 0;

        events.once<String>('test/once', (ctx) {
          callCount++;
        });

        events.emit<String>('test/once', 'first');
        events.emit<String>('test/once', 'second');

        // Allow event processing
        await Future.delayed(Duration.zero);

        expect(callCount, equals(1));
      });

      // test('should wait for event and return data', () async {
      //   final futureData = events.wait<String>('test/wait');
      //
      //   events.emit<String>('test/wait', 'waited data');
      //
      //   final result = await futureData;
      //   expect(result, equals('waited data'));
      // });
      //
      // test('should handle wait with null data', () async {
      //   final futureData = events.wait<String>('test/wait/null');
      //
      //   events.emit<String>('test/wait/null');
      //
      //   // This should complete but not return data since it's null
      //   // The implementation should handle this case
      //   expectLater(futureData, completion(isNull));
      // });
    });

    group('Error Handling', () {
      test('should throw on empty channel', () {
        expect(
          () => events.on<String>('', (ctx) {}),
          throwsA(isA<EventException>()),
        );
      });

      test('should handle listener exceptions gracefully', () {
        String? received;

        events.on<String>('error/test', (ctx) {
          throw Exception('Listener error');
        });

        events.on<String>('error/test', (ctx) {
          received = ctx.data;
        });

        expect(
          () => events.emit<String>('error/test', 'test data'),
          returnsNormally,
        );

        expect(received, equals('test data'));
      });

      test('should handle retained event delivery errors', () {
        events.emit<int>('retained/error', 42, true);

        // Try to listen with wrong type - should handle gracefully
        expect(
          () => events.on<String>('retained/error', (ctx) {}),
          returnsNormally,
        );
      });

      test('should warn on empty channel emission', () {
        expect(() => events.emit<String>('', 'data'), returnsNormally);
      });
    });

    group('Advanced Scenarios', () {
      test('should handle rapid event emission', () {
        final received = <String>[];

        events.on<String>('rapid/test', (ctx) {
          received.add(ctx.data!);
        });

        for (int i = 0; i < 1000; i++) {
          events.emit<String>('rapid/test', 'data_$i');
        }

        expect(received.length, equals(1000));
        expect(received.first, equals('data_0'));
        expect(received.last, equals('data_999'));
      });

      test('should handle complex nested channels', () {
        final received = <String>[];

        events.on<String>('a/b/c/d/e/f/g', (ctx) {
          received.add(ctx.data!);
        });

        events.emit<String>('a/b/c/d/e/f/g', 'deeply nested');

        expect(received, contains('deeply nested'));
      });

      test('should handle mixed wildcard patterns', () {
        final received = <String>[];

        events.on<String>('api/*/users/#', (ctx) {
          received.add('${ctx.params[0]}:${ctx.params.skip(1).join(',')}');
        });

        events.emit<String>('api/v1/users/123/profile', 'data');
        events.emit<String>('api/v2/users/456/settings/theme', 'data');

        expect(received, hasLength(2));
        expect(received[0], equals('v1:123,profile'));
        expect(received[1], equals('v2:456,settings,theme'));
      });

      test('should handle concurrent listener modifications', () {
        final listeners = <EventListener<String>>[];

        // Add listeners
        for (int i = 0; i < 10; i++) {
          listeners.add(events.on<String>('concurrent/test', (ctx) {}));
        }

        expect(events.listenerCount, equals(10));

        // Remove listeners while emitting
        events.emit<String>('concurrent/test', 'data');

        for (final listener in listeners) {
          events.deafen(listener);
        }

        expect(events.listenerCount, equals(0));
      });

      test('should maintain listener order', () {
        final received = <String>[];

        events.on<String>('order/test', (ctx) => received.add('first'));
        events.on<String>('order/test', (ctx) => received.add('second'));
        events.on<String>('order/test', (ctx) => received.add('third'));

        events.emit<String>('order/test', 'data');

        expect(received, equals(['first', 'second', 'third']));
      });
    });

    group('Custom Separator', () {
      test('should work with custom separator', () {
        final customEvents = Events('.');
        String? received;

        customEvents.on<String>('user.profile.update', (ctx) {
          received = ctx.data;
        });

        customEvents.emit<String>('user.profile.update', 'custom separator');

        expect(received, equals('custom separator'));
        customEvents.clear();
      });

      test('should handle wildcards with custom separator', () {
        final customEvents = Events('::');
        final received = <String>[];

        customEvents.on<String>('module::*::action', (ctx) {
          received.add(ctx.params[0]);
        });

        customEvents.emit<String>('module::user::action', 'data');
        customEvents.emit<String>('module::admin::action', 'data');

        expect(received, equals(['user', 'admin']));
        customEvents.clear();
      });
    });

    group('Event Context Validation', () {
      test('should provide correct context information', () {
        String? receivedName;
        String? receivedData;
        List<String>? receivedParams;

        events.on<String>('context/*/test', (ctx) {
          receivedName = ctx.name;
          receivedData = ctx.data;
          receivedParams = ctx.params;
        });

        events.emit<String>('context/validation/test', 'context data');

        expect(receivedName, equals('context/validation/test'));
        expect(receivedData, equals('context data'));
        expect(receivedParams, equals(['validation']));
      });

      test('should handle context toString', () {
        String? contextString;

        events.on<String>('context/string', (ctx) {
          contextString = ctx.toString();
        });

        events.emit<String>('context/string', 'test data');

        expect(contextString, contains('EventContext'));
        expect(contextString, contains('context/string'));
        expect(contextString, contains('test data'));
      });
    });

    group('Memory Management', () {
      test('should not leak memory with many listeners', () {
        final listeners = <EventListener<String>>[];

        // Create many listeners
        for (int i = 0; i < 1000; i++) {
          listeners.add(events.on<String>('memory/test', (ctx) {}));
        }

        expect(events.listenerCount, equals(1000));

        // Remove all listeners
        for (final listener in listeners) {
          events.deafen(listener);
        }

        expect(events.listenerCount, equals(0));
      });

      test('should handle large retained event counts', () {
        for (int i = 0; i < 100; i++) {
          events.emit<String>('retained/$i', 'data_$i', true);
        }

        expect(events.retainedEventCount, equals(100));

        events.clearRetained();
        expect(events.retainedEventCount, equals(0));
      });
    });
  });

  group('Event Listener Class', () {
    test('should create listener with correct properties', () {
      final callback = (EventContext<String> ctx) {};
      final listener = EventListener<String>(['user', 'profile'], callback);

      expect(listener.path, equals(['user', 'profile']));
      expect(listener.callback, equals(callback));
    });

    test('should have meaningful toString', () {
      final listener = EventListener<String>(['user', 'profile'], (ctx) {});
      final string = listener.toString();

      expect(string, contains('EventListener'));
      expect(string, contains('user/profile'));
    });
  });
}
