import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final entry = Main();
  await moduleManager.register(entry);
  moduleManager.defaultModule = entry.name;

  runApp(const MaterialApp(home: MosaicScope()));
}

class Main extends Module {
  Main() : super(name: 'main');

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
