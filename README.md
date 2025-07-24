# Mosaic

[![Pub Version](https://img.shields.io/pub/v/mosaic.svg)](https://pub.dev/packages/mosaic)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D1.17.0-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.8.1-blue.svg)](https://dart.dev)

Mosaic is a powerful, modular Flutter architecture that enables clean separation of features using dynamic modules, internal event systems, UI injection, and centralized build orchestration. It helps large applications scale with ease by treating each feature as an isolated unit that can be enabled, built, and tested independently.

## Features

- ** Modular Architecture**: Organize your app into independent, reusable modules
- ** Event-Driven Communication**: Decoupled communication between modules using a robust event system
- ** Dynamic UI Injection**: Inject UI components dynamically across different modules
- ** Internal Navigation**: Module-specific routing with stack management
- ** Advanced Logging**: Multi-dispatcher logging system with file and console output
- ** Thread Safety**: Built-in mutex and semaphore utilities for concurrent operations
- ** Auto Queue**: Automatic retry mechanism for async operations
- ** Type-Safe Events**: Strongly typed event system with wildcard support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  mosaic: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Architecture Overview

Mosaic follows a modular architecture pattern where each feature is encapsulated in its own module. The architecture consists of several key components:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Module A    │    │     Module B    │    │     Module C    │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Widget  │  │    │  │   Widget  │  │    │  │   Widget  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Event System   │
                    │   • Events      │
                    │   • Router      │
                    │   • Injector    │
                    └─────────────────┘
```

## Quick Start

### 1. Define Your Modules

Create an enum for your modules:

```dart
enum ModuleEnum {
  home,
  profile,
  settings;

  static ModuleEnum? tryParse(String value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}
```

### 2. Create a Module

```dart
import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

class HomeModule extends Module {
  HomeModule() : super(name: 'home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          const Text('Welcome to Home Module'),
          // Display any injected widgets
          ...stack,
        ],
      ),
    );
  }

  @override
  Future<void> onInit() async {
    // Initialize module-specific resources
    logger.info('Home module initialized');
  }

  @override
  void onActive() {
    // Called when this module becomes active
    logger.info('Home module activated');
  }
}
```

### 3. Register and Use Modules

```dart
import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

void main() async {
  // Initialize logger
  await logger.init(
    tags: ['app', 'router', 'events'],
    dispatchers: [
      ConsoleDispatcher(),
      FileLoggerDispatcher(path: 'logs'),
    ],
  );

  // Register modules
  moduleManager.modules['home'] = HomeModule();
  moduleManager.modules['profile'] = ProfileModule();
  moduleManager.defaultModule = 'home';

  // Initialize router
  router.init(ModuleEnum.home);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mosaic Demo',
      home: ModularApp(),
    );
  }
}
```

## Event System

Mosaic includes a powerful event system for decoupled communication between modules.

### Basic Events

```dart
// Listen to events
events.on<String>('user/login', (context) {
  print('User logged in: ${context.data}');
});

// Emit events
events.emit<String>('user/login', 'john_doe');
```

### Wildcard Events

```dart
// Listen to all user events
events.on<String>('user/*', (context) {
  print('User event: ${context.name}');
});

// Listen to all events under a path
events.on<String>('user/#', (context) {
  print('Any user-related event: ${context.params}');
});
```

### Event Chains

```dart
class UserSegment extends Segment {
  UserSegment() : super('user');
}

final userEvents = UserSegment();

// Chain events
userEvents.$('profile').$('update').emit<Map<String, String>>({
  'name': 'John Doe',
  'email': 'john@example.com'
});

// Listen to chained events
userEvents.$('profile').$('update').on<Map<String, String>>((context) {
  print('Profile updated: ${context.data}');
});
```

## UI Injection

Dynamically inject UI components into different parts of your application:

```dart
// In a module, inject a widget
class ProfileModule extends Module {
  @override
  void onInit() {
    // Inject a profile widget into the home module
    injector.inject(
      'home/sidebar',
      ModularExtension(
        (context) => ListTile(
          leading: Icon(Icons.person),
          title: Text('Profile'),
          onTap: () => router.goto(ModuleEnum.profile),
        ),
        priority: 1,
      ),
    );
  }
}

// In the receiving widget
class ModularSidebar extends ModularStatefulWidget {
  const ModularSidebar({Key? key}) : super(key: key, path: ['home', 'sidebar']);

  @override
  ModularState<ModularSidebar> createState() => _ModularSidebarState();
}

class _ModularSidebarState extends ModularState<ModularSidebar> {
  _ModularSidebarState() : super('sidebar');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: extensions.map((ext) => ext.builder(context)).toList(),
    );
  }
}
```

## Navigation & Routing

Mosaic provides both module-level and internal navigation:

### Module Navigation

```dart
// Navigate to a different module
router.goto(ModuleEnum.profile);

// Go back to previous module
router.goBack();

// Clear current module's internal stack
router.clear();
```

### Internal Navigation

```dart
// Push a widget to the current module's stack
Future<String?> result = router.push<String>(
  ProfileEditPage(userId: '123')
);

// Pop from the current module's stack
router.pop<String>('Profile updated successfully');
```

## Logging System

Mosaic includes a comprehensive logging system with multiple dispatchers:

### Basic Logging

```dart
// Initialize logger with tags and dispatchers
await logger.init(
  tags: ['app', 'network', 'ui'],
  dispatchers: [
    ConsoleDispatcher(),
    FileLoggerDispatcher(
      path: 'logs',
      fileNameRole: (tag) => '${tag}_${DateTime.now().millisecondsSinceEpoch}.log',
    ),
  ],
);

// Log messages
logger.info('Application started', ['app']);
logger.error('Network request failed', ['network']);
logger.debug('UI element rendered', ['ui']);
```

### Module-Specific Logging

```dart
class HomeModule extends Module with Loggable {
  @override
  List<String> get loggerTags => ['home'];

  void someMethod() {
    info('Home module method called'); // Automatically tagged with 'home'
  }
}
```

## Thread Safety

Use Mosaic's thread-safe utilities for concurrent operations:

### Mutex

```dart
final mutex = Mutex<List<String>>(['item1', 'item2']);

// Safe read
List<String> items = await mutex.get();

// Safe write
await mutex.set(['item1', 'item2', 'item3']);

// Safe operation
await mutex.use((items) async {
  items.add('item4');
  await someAsyncOperation(items);
});
```

### Semaphore

```dart
final semaphore = Semaphore();

Future<void> criticalSection() async {
  await semaphore.lock();
  try {
    // Critical code here
  } finally {
    semaphore.release();
  }
}
```

## Auto Queue

Handle async operations with automatic retry:

```dart
final queue = InternalAutoQueue();

// Add operation to queue with automatic retry
String result = await queue.push<String>(() async {
  // This will be retried up to MAX_RETRIES times on failure
  return await someUnreliableAsyncOperation();
});
```

## Testing

Mosaic is designed with testability in mind:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  group('Module Tests', () {
    late HomeModule homeModule;

    setUp(() {
      homeModule = HomeModule();
    });

    test('should initialize correctly', () async {
      await homeModule.onInit();
      expect(homeModule.name, equals('home'));
      expect(homeModule.active, isTrue);
    });

    test('should handle navigation stack', () async {
      final widget = Container();
      final future = homeModule.push<String>(widget);
      
      expect(homeModule.stack.length, equals(1));
      
      homeModule.pop<String>('test result');
      final result = await future;
      
      expect(result, equals('test result'));
      expect(homeModule.stack.length, equals(0));
    });
  });

  group('Event System Tests', () {
    test('should emit and receive events', () async {
      String? receivedData;
      
      events.on<String>('test/event', (context) {
        receivedData = context.data;
      });
      
      events.emit<String>('test/event', 'test data');
      
      await Future.delayed(Duration.zero); // Allow event processing
      expect(receivedData, equals('test data'));
    });
  });
}
```

## API Reference

### Core Classes

- **`Module`**: Base class for creating application modules
- **`Events`**: Global event system for decoupled communication
- **`ModuleManager`**: Singleton for managing all application modules
- **`InternalRouter`**: Navigation system for module switching
- **`UIInjector`**: System for dynamic UI component injection
- **`Logger`**: Comprehensive logging system with multiple dispatchers

### Utilities

- **`Mutex<T>`**: Thread-safe data access
- **`Semaphore`**: Concurrency control
- **`InternalAutoQueue`**: Automatic retry queue for async operations
- **`Segment`**: Event path builder with chaining support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/your-repo/mosaic.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run example
cd example
flutter run
```

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Support

If you have any questions or need help, please:

1. Check the [documentation](https://pub.dev/packages/mosaic)
2. Open an [issue](https://github.com/marcomit/mosaic/issues)
3. Start a [discussion](https://github.com/marcomit/mosaic/discussions)

---

**Built with ❤️ for the Flutter community**
