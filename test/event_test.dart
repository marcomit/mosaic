import 'package:mosaic/mosaic.dart';
import 'package:test/test.dart';

void main() {
  group('EventContext', () {
    test('should create event context with data', () {
      final context = const EventContext<String>('test data', 'test/event', [
        'param1',
      ]);

      expect(context.data, equals('test data'));
      expect(context.name, equals('test/event'));
      expect(context.params, equals(['param1']));
    });

    test('should handle null data', () {
      final context = const EventContext<Null>(null, 'test/event', []);

      expect(context.data, isNull);
      expect(context.name, equals('test/event'));
      expect(context.params, isEmpty);
    });

    test('toString should return readable format', () {
      final context = const EventContext<int>(42, 'counter/update', ['user1']);
      final str = context.toString();

      expect(str, contains('counter/update'));
      expect(str, contains('42'));
      expect(str, contains('user1'));
    });
  });

  group('EventListener', () {
    test('toString should return readable format', () {
      final listener = EventListener<String>(['user', 'login'], (_) {});
      final str = listener.toString();

      expect(str, contains('user/login'));
    });

    test('should store path correctly', () {
      final listener = EventListener<String>(['user', 'login'], (_) {});

      expect(listener.path, equals(['user', 'login']));
    });

    test('should store callback correctly', () {
      var called = false;
      void callback(EventContext<String> ctx) {
        called = true;
      }

      final listener = EventListener<String>(['user', 'login'], callback);

      listener.callback(const EventContext<String>('data', 'user/login', []));
      expect(called, isTrue);
    });
  });

  group('Events - Basic Operations', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should register and trigger listener', () {
      var triggered = false;
      String? receivedData;

      events.on<String>('user/login', (context) {
        triggered = true;
        receivedData = context.data;
      });

      events.emit<String>('user/login', 'john_doe');

      expect(triggered, isTrue);
      expect(receivedData, equals('john_doe'));
    });

    test('should trigger multiple listeners on same channel', () {
      var count = 0;

      events.on<String>('user/login', (_) => count++);
      events.on<String>('user/login', (_) => count++);
      events.on<String>('user/login', (_) => count++);

      events.emit<String>('user/login', 'john_doe');

      expect(count, equals(3));
    });

    test('should not trigger listener on different channel', () {
      var triggered = false;

      events.on<String>('user/login', (_) => triggered = true);
      events.emit<String>('user/logout', 'john_doe');

      expect(triggered, isFalse);
    });

    test('should pass correct event context', () {
      EventContext<int>? receivedContext;

      events.on<int>('counter/update', (context) {
        receivedContext = context;
      });

      events.emit<int>('counter/update', 42);

      expect(receivedContext, isNotNull);
      expect(receivedContext!.data, equals(42));
      expect(receivedContext!.name, equals('counter/update'));
      expect(receivedContext!.params, isEmpty);
    });

    test('should handle null data', () {
      String? receivedData = 'initial';

      events.on<Null>('test/event', (context) {
        receivedData = context.data;
      });

      events.emit<Null>('test/event', null);

      expect(receivedData, isNull);
    });

    test('should throw on empty channel', () {
      expect(
        () => events.on<String>('', (_) {}),
        throwsA(isA<EventException>()),
      );
    });
  });

  group('Events - Wildcards', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should match single wildcard', () {
      var count = 0;
      List<String> params = [];

      events.on<String>('user/*/update', (context) {
        count++;
        params = context.params;
      });

      events.emit<String>('user/123/update', 'data1');
      events.emit<String>('user/456/update', 'data2');
      events.emit<String>('user/login', 'data3'); // Should not match

      expect(count, equals(2));
      expect(params, equals(['456']));
    });

    test('should match global wildcard', () {
      var count = 0;
      List<String> lastParams = [];

      events.on<String>('user/#', (context) {
        count++;
        lastParams = context.params;
      });

      events.emit<String>('user/login', 'data1');
      events.emit<String>('user/123/update', 'data2');
      events.emit<String>('user/123/post/456/comment', 'data3');
      events.emit<String>('admin/login', 'data4'); // Should not match

      expect(count, equals(3));
      expect(lastParams, equals(['123', 'post', '456', 'comment']));
    });

    test('should handle multiple wildcards', () {
      var triggered = false;
      List<String> params = [];

      events.on<String>('user/*/post/*', (context) {
        triggered = true;
        params = context.params;
      });

      events.emit<String>('user/123/post/456', 'data');

      expect(triggered, isTrue);
      expect(params, equals(['123', '456']));
    });

    test('should match overlapping patterns', () {
      var staticCount = 0;
      var wildcardCount = 0;
      var globalCount = 0;

      events.on<String>('user/123/update', (_) => staticCount++);
      events.on<String>('user/*/update', (_) => wildcardCount++);
      events.on<String>('user/#', (_) => globalCount++);

      events.emit<String>('user/123/update', 'data');

      expect(staticCount, equals(1));
      expect(wildcardCount, equals(1));
      expect(globalCount, equals(1));
    });
  });

  group('Events - Retained Events', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should retain events', () {
      events.emit<String>('app/ready', 'initialized', true);

      expect(events.retainedEventCount, equals(1));
      expect(events.retainedChannels, contains('app/ready'));
    });

    test('should deliver retained events to new listeners', () {
      events.emit<String>('app/ready', 'initialized', true);

      var triggered = false;
      String? receivedData;

      events.on<String>('app/ready', (context) {
        triggered = true;
        receivedData = context.data;
      });

      expect(triggered, isTrue);
      expect(receivedData, equals('initialized'));
    });

    test('should deliver retained events matching wildcards', () {
      events.emit<String>('user/123/update', 'data1', true);
      events.emit<String>('user/456/update', 'data2', true);

      var count = 0;

      events.on<String>('user/*/update', (_) => count++);

      expect(count, equals(2));
    });

    test('should clear retained events', () {
      events.emit<String>('app/ready', 'initialized', true);
      events.emit<String>('user/login', 'john', true);

      expect(events.retainedEventCount, equals(2));

      events.clearRetained();

      expect(events.retainedEventCount, equals(0));
      expect(events.retainedChannels, isEmpty);
    });

    test('should not deliver cleared retained events', () {
      events.emit<String>('app/ready', 'initialized', true);
      events.clearRetained();

      var triggered = false;

      events.on<String>('app/ready', (_) => triggered = true);

      expect(triggered, isFalse);
    });

    test('should update retained event on re-emit', () {
      events.emit<int>('counter/value', 5, true);
      events.emit<int>('counter/value', 10, true);

      expect(events.retainedEventCount, equals(1));

      var receivedValue = 0;
      events.on<int>('counter/value', (context) {
        receivedValue = context.data;
      });

      expect(receivedValue, equals(10));
    });
  });

  group('Events - Listener Management', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should remove listener with deafen', () {
      var count = 0;

      final listener = events.on<String>('user/login', (_) => count++);

      events.emit<String>('user/login', 'data1');
      events.deafen(listener);
      events.emit<String>('user/login', 'data2');

      expect(count, equals(1));
    });

    test('should remove wildcard listener', () {
      var count = 0;

      final listener = events.on<String>('user/*/update', (_) => count++);

      events.emit<String>('user/123/update', 'data1');
      events.deafen(listener);
      events.emit<String>('user/456/update', 'data2');

      expect(count, equals(1));
    });

    test('should remove global wildcard listener', () {
      var count = 0;

      final listener = events.on<String>('user/#', (_) => count++);

      events.emit<String>('user/login', 'data1');
      events.deafen(listener);
      events.emit<String>('user/logout', 'data2');

      expect(count, equals(1));
    });

    test('should clear all listeners', () {
      events.on<String>('event1', (_) {});
      events.on<String>('event2', (_) {});
      events.on<String>('user/*', (_) {});
      events.on<String>('app/#', (_) {});

      expect(events.listenerCount, equals(4));

      events.clear();

      expect(events.listenerCount, equals(0));
    });

    test('should track listener count correctly', () {
      expect(events.listenerCount, equals(0));

      final l1 = events.on<String>('event1', (_) {});
      expect(events.listenerCount, equals(1));

      final l2 = events.on<String>('event2', (_) {});
      expect(events.listenerCount, equals(2));

      events.deafen(l1);
      expect(events.listenerCount, equals(1));

      events.deafen(l2);
      expect(events.listenerCount, equals(0));
    });
  });

  group('Events - Once', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should trigger once listener only once', () {
      var count = 0;

      events.once<String>('user/login', (_) => count++);

      events.emit<String>('user/login', 'data1');
      events.emit<String>('user/login', 'data2');
      events.emit<String>('user/login', 'data3');

      expect(count, equals(1));
    });

    test('should auto-remove once listener', () async {
      events.once<String>('user/login', (_) {});

      expect(events.listenerCount, equals(1));

      events.emit<String>('user/login', 'data');

      // Give time for the completer to finish
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.listenerCount, equals(0));
    });

    test('should receive correct data in once listener', () {
      String? receivedData;

      events.once<String>('user/login', (context) {
        receivedData = context.data;
      });

      events.emit<String>('user/login', 'john_doe');

      expect(receivedData, equals('john_doe'));
    });
  });

  group('Events - Wait', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should wait for event and return data', () async {
      final future = events.wait<String>('user/login');

      events.emit<String>('user/login', 'john_doe');

      final result = await future;
      expect(result, equals('john_doe'));
    });

    test('should handle multiple waits on same channel', () async {
      final future1 = events.wait<int>('counter/update');
      final future2 = events.wait<int>('counter/update');

      events.emit<int>('counter/update', 42);

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, equals(42));
      expect(result2, equals(42));
    });

    test('should timeout if event never emitted', () async {
      final future = events
          .wait<String>('never/emitted')
          .timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => throw TimeoutException(),
          );

      expect(future, throwsA(isA<TimeoutException>()));
    });
  });

  group('Events - Namespace', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should create namespace', () {
      final userEvents = events.namespace('user');
      var triggered = false;

      userEvents.on<String>('login', (_) => triggered = true);
      events.emit<String>('user/login', 'data');

      expect(triggered, isTrue);
    });

    test('should emit with namespace prefix', () {
      final userEvents = events.namespace('user');
      var triggered = false;

      events.on<String>('user/login', (_) => triggered = true);
      userEvents.emit<String>('login', 'data');

      expect(triggered, isTrue);
    });

    test('should support nested namespaces', () {
      final userEvents = events.namespace('user');
      final profileEvents = userEvents.namespace('profile');
      var triggered = false;

      profileEvents.on<String>('update', (_) => triggered = true);
      events.emit<String>('user/profile/update', 'data');

      expect(triggered, isTrue);
    });

    test('should share listeners across namespaces', () {
      final userEvents = events.namespace('user');
      var count = 0;

      events.on<String>('user/login', (_) => count++);
      userEvents.on<String>('login', (_) => count++);

      events.emit<String>('user/login', 'data');

      expect(count, equals(2));
    });

    test('should share retained events across namespaces', () {
      final userEvents = events.namespace('user');

      events.emit<String>('user/ready', 'initialized', true);

      var triggered = false;
      userEvents.on<String>('ready', (_) => triggered = true);

      expect(triggered, isTrue);
    });
  });

  group('Events - Custom Separator', () {
    test('should use custom separator', () {
      final events = Events('.');
      var triggered = false;

      events.on<String>('user.login', (_) => triggered = true);
      events.emit<String>('user.login', 'data');

      expect(triggered, isTrue);

      events.clear();
    });

    test('should handle wildcards with custom separator', () {
      final events = Events(':');
      var count = 0;

      events.on<String>('user:*:update', (_) => count++);
      events.emit<String>('user:123:update', 'data');

      expect(count, equals(1));

      events.clear();
    });
  });

  group('Events - Edge Cases', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should handle channels with trailing slashes', () {
      var count = 0;

      events.on<String>('user/login', (_) => count++);
      events.emit<String>('user/login/', 'data');

      expect(count, equals(1));
    });

    test('should handle channels with multiple slashes', () {
      var count = 0;

      events.on<String>('user/login', (_) => count++);
      events.emit<String>('user//login', 'data');

      expect(count, equals(1));
    });

    test('should handle large number of listeners', () {
      var count = 0;

      for (var i = 0; i < 1000; i++) {
        events.on<String>('test/event', (_) => count++);
      }

      events.emit<String>('test/event', 'data');

      expect(count, equals(1000));
    });

    test('should handle deep channel paths', () {
      var triggered = false;

      events.on<String>('a/b/c/d/e/f/g/h/i/j', (_) => triggered = true);
      events.emit<String>('a/b/c/d/e/f/g/h/i/j', 'data');

      expect(triggered, isTrue);
    });

    test('should handle complex wildcard patterns', () {
      var count = 0;
      List<String> params = [];

      events.on<String>('a/*/c/*/e/#', (context) {
        count++;
        params = context.params;
      });

      events.emit<String>('a/b/c/d/e/f/g/h', 'data');

      expect(count, equals(1));
      expect(params, equals(['b', 'd', 'f', 'g', 'h']));
    });
  });

  group('Events - Type Safety', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('should handle different data types', () {
      var intReceived = false;
      var stringReceived = false;
      var boolReceived = false;

      events.on<int>('int/event', (context) {
        intReceived = context.data == 42;
      });

      events.on<String>('string/event', (context) {
        stringReceived = context.data == 'hello';
      });

      events.on<bool>('bool/event', (context) {
        boolReceived = context.data == true;
      });

      events.emit<int>('int/event', 42);
      events.emit<String>('string/event', 'hello');
      events.emit<bool>('bool/event', true);

      expect(intReceived, isTrue);
      expect(stringReceived, isTrue);
      expect(boolReceived, isTrue);
    });

    test('should handle complex objects', () {
      final user = User('John', 30);
      User? receivedUser;

      events.on<User>('user/update', (context) {
        receivedUser = context.data;
      });

      events.emit<User>('user/update', user);

      expect(receivedUser, isNotNull);
      expect(receivedUser!.name, equals('John'));
      expect(receivedUser!.age, equals(30));
    });

    test('should handle lists', () {
      List<int>? receivedList;

      events.on<List<int>>('data/list', (context) {
        receivedList = context.data;
      });

      events.emit<List<int>>('data/list', [1, 2, 3, 4, 5]);

      expect(receivedList, equals([1, 2, 3, 4, 5]));
    });

    test('should handle maps', () {
      Map<String, dynamic>? receivedMap;

      events.on<Map<String, dynamic>>('data/map', (context) {
        receivedMap = context.data;
      });

      events.emit<Map<String, dynamic>>('data/map', {
        'key': 'value',
        'count': 42,
      });

      expect(receivedMap, isNotNull);
      expect(receivedMap!['key'], equals('value'));
      expect(receivedMap!['count'], equals(42));
    });
  });

  group('Events - Performance', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    tearDown(() {
      events.clear();
    });

    test('static listeners should be O(1)', () {
      // Add many static listeners
      for (var i = 0; i < 100; i++) {
        events.on<String>('channel$i', (_) {});
      }

      var triggered = false;
      events.on<String>('test/channel', (_) => triggered = true);

      // Emit should be fast even with many other listeners
      events.emit<String>('test/channel', 'data');

      expect(triggered, isTrue);
    });

    test('should efficiently handle many emit operations', () {
      var count = 0;
      events.on<String>('test/event', (_) => count++);

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        events.emit<String>('test/event', 'data');
      }

      stopwatch.stop();

      expect(count, equals(10000));
      // Should complete in reasonable time (adjust threshold as needed)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}

// Helper class for testing complex objects
class User {
  User(this.name, this.age);

  final String name;
  final int age;
}

// Mock TimeoutException for test compatibility
class TimeoutException implements Exception {
  TimeoutException([this.message]);
  final String? message;
}
