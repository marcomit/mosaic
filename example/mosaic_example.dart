import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MaterialApp(home: MosaicScope()));
}
