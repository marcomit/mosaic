import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'events.dart';
import 'logger.dart';

/// Rappresenta una voce nello stack interno di un modulo.
/// Contiene un widget e un Completer per completare una future quando viene fatto il pop.
class InternalRoute<T> {
  /// Completer associato alla route, usato per risolvere la future al momento del pop.
  Completer<T> completer;

  /// Widget da mostrare per questa route.
  Widget widget;

  InternalRoute(this.completer, this.widget);
}

/// Rappresenta un modulo dell'applicazione con il proprio stack di navigazione interno.
abstract class Module with Loggable {
  /// Enumeratore per tipizzare i moduli disponibili
  // final ModuleEnum enumerator;

  @override
  List<String> get loggerTags => [name];

  /// Indica se il modulo è attivo.
  bool active;

  /// Nome identificativo del modulo.
  final String name;

  final bool fullScreen;

  final List<InternalRoute> _stack = [];

  /// Stack corrente dei widget all'interno del modulo.
  /// Ogni widget rappresenta una "pagina" interna del modulo.
  Iterable<Widget> get stack => _stack.map((m) => m.widget);

  Module({
    required this.name,
    // required this.enumerator,
    this.active = true,
    this.fullScreen = false,
  });

  /// Funzione che restituisce il widget principale del modulo.
  Widget build(BuildContext context);

  /// Callback asincrono opzionale da eseguire quando il modulo viene inizializzato.
  Future<void> onInit() async {}

  /// Callback che viene richiamata ogni volta che si passa da un modulo qualsiasi a questo modulo
  void onActive() {}

  /// Aggiunge un widget allo stack del modulo e ritorna una [Future]
  /// che sarà completata quando quel widget verrà rimosso con [pop].
  @nonVirtual
  Future<T> push<T>(Widget widget) {
    final entry = InternalRoute(Completer<T>(), widget);
    _stack.add(entry);
    logger.info("$name PUSH ${_stack.length}", ["router"]);
    events.emit<String>(['router', 'push'].join(Events.SEP), '');
    return entry.completer.future;
  }

  /// Rimuove l'ultimo widget dallo stack e completa la [Future]
  /// associata con un valore opzionale.
  @nonVirtual
  void pop<T>([T? value]) {
    if (_stack.isEmpty) return;
    final c = _stack.removeLast().completer;
    logger.info("$name POP ${_stack.length}", ["router"]);
    events.emit<int>(['router', 'pop'].join(Events.SEP), 1);
    c.complete(value);
  }

  /// Rimuove tutte le voci dallo stack del modulo.
  @nonVirtual
  void clear() {
    while (_stack.isNotEmpty) {
      _stack.removeLast().completer.complete(null);
      events.emit(['router', 'pop'].join(Events.SEP), 1);
    }
  }
}

/// Singleton che gestisce tutti i moduli dell'app.
/// Tiene traccia del modulo attuale e del modulo di default.
class ModuleManager {
  static final _instance = ModuleManager._internal();

  /// Mappa contenente tutti i moduli registrati, indicizzati per nome.
  Map<String, Module> modules = {};

  /// Nome del modulo di default, da usare se non è specificato altro.
  String? defaultModule;

  /// Nome del modulo attualmente attivo.
  String? currentModule;

  Map<String, Module> get actives {
    final Map<String, Module> res = {};
    for (final entry in modules.entries) {
      if (!entry.value.active) continue;
      res[entry.key] = entry.value;
    }
    return res;
  }

  /// Restituisce il modulo attualmente attivo, se esiste.
  Module? get current => modules[currentModule];

  ModuleManager._internal();
}

/// Istanza globale del gestore dei moduli, accessibile ovunque.
final moduleManager = ModuleManager._instance;
