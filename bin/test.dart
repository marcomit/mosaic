import 'gesso.dart';

void main() {
  final error = Gesso().brightRed.italic.blink;

  final warning = Gesso().yellow.bold;

  final info = Gesso().brightBlue.bold.italic;

  print(error('errore'));
  print(warning('errore'));
  print(info('errore'));
  print(info('Bel messagio'));
}
