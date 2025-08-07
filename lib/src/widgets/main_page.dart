import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';
import 'package:mosaic/src/modules/module_manager.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = -1;
  List<Widget> modules = [];
  bool _semaphore = false;
  String? get _currentModule => moduleManager.currentModule;

  set _currentModule(String? value) {
    moduleManager.currentModule = value;
  }

  void _triggerListener() {
    if (_currentModule == null) return;
    if (!moduleManager.activeModules.containsKey(_currentModule)) return;
    moduleManager.activeModules[_currentModule]!.onActive();
  }

  @override
  void initState() {
    super.initState();

    _currentModule = moduleManager.defaultModule;
    setIndex();

    events.on<String>('router/push', wrapper(refresh));
    events.on<int>('router/pop', wrapper(refresh));
    events.on<String>('router/change/*', wrapper(changeRoute));

    for (final module in moduleManager.activeModules.values) {
      modules.add(module.build(context));
    }
  }

  void mutex<T>(EventCallback<T> callback, EventContext<T> ctx) {
    if (_semaphore) return;
    _semaphore = true;
    callback(ctx);
    _semaphore = false;
  }

  EventCallback<T> wrapper<T>(EventCallback<T> callback) {
    return (EventContext<T> ctx) => mutex(callback, ctx);
  }

  void changeRoute(EventContext<String> ctx) {
    if (!context.mounted) return;
    _currentModule = ctx.params[0];
    _triggerListener();
    setIndex();
    if (mounted) setState(() {});
  }

  void refresh<T>(EventContext<T> ctx) async => setState(() {});

  void setIndex() {
    final keys = moduleManager.activeModules.keys;
    for (int i = 0; i < keys.length; i++) {
      if (_currentModule == keys.elementAt(i)) {
        _currentIndex = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listModules = moduleManager.activeModules.values.toList();

    return Scaffold(
      body: IndexedStack(
        index: _currentModule == null ? 0 : _currentIndex + 1,
        children: [defaultPage(), ...listModules.indexed.map(stack)],
      ),
    );
  }

  Widget stack((int, Module) tuple) {
    final (index, module) = tuple;
    final children = [modules[index], ...module.stack];
    if (children.isEmpty) return const SizedBox();
    return IndexedStack(index: children.length - 1, children: children);
  }

  Widget defaultPage() {
    return const Center(child: Text('No module selected'));
  }
}
