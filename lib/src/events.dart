/* 
* BSD 3-Clause License
* 
* Copyright (c) 2025, Marco Menegazzi
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* 1. Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice,
*  this list of conditions and the following disclaimer in the documentation
*  and/or other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its
*  contributors may be used to endorse or promote products derived from
*  this software without specific prior written permission.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:math';

// import 'event_tree.dart';
import 'logger.dart';

/// Contiene le informazioni passate a un listener al momento dell'emissione di un evento.
///
/// [T] rappresenta il tipo opzionale dei dati associati all'evento.
class EventContext<T> {
  /// Dato passato all'evento, può essere null.
  final T? data;

  /// Nome (o canale completo) dell'evento emesso.
  final String name;

  /// Parametri estratti dalla path, se presenti (in corrispondenza di `*` o `#`).
  final List<String> params;

  EventContext(this.data, this.name, this.params);
}

/// Rappresenta un listener registrato a uno specifico canale o pattern.
///
/// Supporta pattern dinamici tramite i caratteri speciali:
/// - `*`: corrisponde a un segmento qualsiasi.
/// - `#`: corrisponde a tutti i segmenti restanti (match "globale").
class EventListener<T> {
  /// Rappresentazione del canale come lista di segmenti.
  List<String> path;

  /// Callback invocata quando l'evento corrispondente viene emesso.
  EventCallback<T> callback;

  EventListener(this.path, this.callback);

  /// Verifica se un canale fornito corrisponde a questo listener.
  ///
  /// Supporta wildcard `*` e `#`.
  bool _verify(List<String> channel) {
    int len = min(channel.length, path.length);
    for (int i = 0; i < len; i++) {
      if (path[i] == "#") return true;
      if (path[i] == "*") continue;
      if (channel[i] != path[i]) return false;
    }
    return channel.length == path.length;
  }

  /// Estrae i parametri dinamici dalla path dell'evento
  /// quando vengono usati `*` o `#`.
  List<String> _getParams(List<String> channel) {
    List<String> res = [];
    for (int i = 0; i < path.length; i++) {
      if (path[i] == '#') return [...res, ...channel.sublist(i)];
      if (path[i] == '*') res.add(channel[i]);
    }
    return res;
  }
}

/// Tipo per una funzione callback che riceve un contesto evento.
typedef EventCallback<T> = void Function(EventContext<T>);

/// Gestore globale di eventi con supporto per canali dinamici.
///
/// Usa un singleton accessibile tramite [events].
class Events {
  /// Separatore dei segmenti del canale (default: `/`).
  static String sep = "/";

  static final _instance = Events._internal();

  final List<EventListener> _listeners = [];

  final Map<String, dynamic> _retained = {};

  Events._internal();

  /// Registra un listener su un canale specifico.
  ///
  /// Il canale può contenere `*` per un segmento jolly o `#` per tutti i segmenti restanti.
  /// Il callback riceverà un [EventContext] al momento dell'emit.
  EventListener<T> on<T>(String channel, EventCallback<T> callback) {
    final listener = EventListener<T>(channel.split(sep), callback);

    for (final route in _retained.keys) {
      final path = route.split(sep);

      if (!listener._verify(path)) continue;

      final data = _retained[route]! as T;
      final context = EventContext<T>(data, channel, listener._getParams(path));

      listener.callback(context);
    }

    _listeners.add(listener);
    return listener;
  }

  /// Emette un evento sul canale specificato.
  ///
  /// - [channel]: stringa con segmenti separati da `/`.
  /// - [data]: valore opzionale da passare al contesto.
  /// - [retain]: parametro attualmente ignorato, riservato per futura gestione eventi persistenti.
  void emit<T>(String channel, [T? data, bool retain = false]) {
    final path = channel.split(sep);
    logger.info("Emitting on $path ${retain ? "retained" : ""}", ['events']);
    EventContext<T> context;

    if (retain) {
      _retained[channel] = data;
    }

    for (final listener in _listeners) {
      if (!listener._verify(path)) continue;
      context = EventContext(data, channel, listener._getParams(path));
      // if (listener is EventListener<T>) {
      //   listener.callback(context);
      // }
      final l = listener as EventListener<T>;
      l.callback(context);
    }
  }

  /// Rimuove un listener in base alla funzione di callback specificata.
  void deafen<T>(EventListener<T> listener) {
    logger.info("Deafen listener ${_listeners.length}", ["banco"]);
    _listeners.remove(listener);
    logger.info("Deafen listener ${_listeners.length}", ["banco"]);
  }

  /// Rimuove l'ultimo listener registrato.
  void pop() => _listeners.removeLast();
}

/// Istanza globale del gestore eventi.
final events = Events._instance;
