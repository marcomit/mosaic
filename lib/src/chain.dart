import 'dart:async';

import 'events.dart';

abstract class Segment {
  String topic;
  Segment(this.topic);

  Segment $(String data) {
    if (topic.isNotEmpty) topic += Events.SEP;
    topic += data;
    return this;
  }

  void emit<T>([T? data, bool retain = false]) =>
      events.emit<T>(topic, data, retain);

  EventListener<T> on<T>(EventCallback<T> callback) =>
      events.on<T>(topic, callback);

  Future<void> wait<T>(EventCallback<T> callback) async {
    Completer c = Completer();

    final listener = on(callback);

    await c.future;

    events.deafen(listener);
  }
}

mixin Id on Segment {
  id(String param) => $(param);
}

mixin Param on Segment {
  Segment params(List<String> params) {
    topic = [topic, ...params].join(Events.SEP);
    return this;
  }
}
