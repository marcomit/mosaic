import 'dart:math';

import 'events.dart';
import 'modular.dart';

typedef UIInjectorCallback = EventCallback<ModularExtension>;
typedef UIInjectorListener = EventListener<ModularExtension>;

class UIInjector {
  static final _instance = UIInjector._internal();
  UIInjector._internal();
  void inject(String path, ModularExtension extension, [String? id]) {
    Random r = Random();
    id ??= r.nextInt(1000).toString();
    // final topic = [path, id];
    // events.extensions.params(topic).emit<ModularExtension>(extension, true);
  }

  EventListener<ModularExtension> on(String path, UIInjectorCallback callback) {
    return events.on(path, callback);
  }
}

final injector = UIInjector._instance;
