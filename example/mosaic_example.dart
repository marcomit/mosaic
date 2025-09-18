import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';
import 'package:mosaic/src/mosaic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final entry = Main();
  await mosaic.registry.register(entry);
  mosaic.registry.initialize(entry, [entry]);

  runApp(const MaterialApp(home: MosaicScope()));
}

class Main extends Module {
  Main() : super(name: 'main');

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
