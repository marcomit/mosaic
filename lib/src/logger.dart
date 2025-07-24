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

import 'dart:async';
import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:modules/modules.dart';
// import 'package:api/api.dart';
import 'package:flutter/cupertino.dart';

import 'modules.dart';
import 'mutex.dart';
import 'semaphore.dart';

enum LogType { debug, info, warning, error }

typedef LoggerWrapperCallback = String Function(String, LogType, List<String>);

final logger = Logger();

/// This is the main logger class
/// ## Tags
/// Tags are used to see only the log you need
/// They should be used for testing a specific features without seeing a large amount of logs
/// You can add or remove `tags` at any time and set some default tags.
/// NOTE: if the tags are empty the logger logs everything
///
/// ## Dispatchers
/// Dipatchers are used to `print` the log in different ways.
/// For now the supported dispatchers are: [console, file, server]
///
/// ## Wrappers
/// Wrappers are used to wrap the message to add a prefix or suffix or modify the message itself.
class Logger {
  /// Tags to 'filter' logs
  final Set<String> _tags = {};

  /// Dispatchers
  final Map<String, LoggerDispatcher> _dispatchers = {};

  /// A list of default tags to avoid writing tags everytime
  final Set<String> _defaultTags = {};

  /// Wrappers are used to manipulate the message before dispatched
  final _wrapper = LoggerWrapper();
  // final List<LoggerWrapperCallback> _wrappers = [];

  /// Wrapper function that add the type of the log
  static String addType(String message, LogType type, List<String> tags) {
    return "${type.name}: $message";
  }

  /// Wrapper function that add the `DateTime`
  static String addData(String message, LogType type, List<String> tags) {
    return "${DateTime.now().toIso8601String()} $message";
  }

  static String addTags(String message, LogType type, List<String> tags) {
    return "[${tags.join(',')}] $message";
  }

  /// Wrapper function that add the current module
  static String addCurrentModule(String message, LogType type) {
    return "${moduleManager.current?.name} $message";
  }

  Logger copy([List<String> defaultTags = const []]) {
    Logger res = Logger();
    res._defaultTags.addAll(_defaultTags);
    res._defaultTags.addAll(defaultTags);
    res.init(tags: _tags.toList(), dispatchers: _dispatchers.values.toList());
    return res;
  }

  /// The init method should be called at the start of the app
  /// Tags are the allowed tags such that the logs that have one of these tags are sent to the dispatchers
  /// Dispatchers are the default dispatchers (they can be modified later)
  /// defaultTags are the tags that must be put in every log (it is useful to create a logger for each module)
  Future<void> init({
    required List<String> tags,
    required List<LoggerDispatcher> dispatchers,
    List<String>? defaultTags,
  }) async {
    _tags.clear();
    _tags.addAll(tags);

    _defaultTags.clear();
    if (defaultTags != null) _defaultTags.addAll(defaultTags);

    _dispatchers.clear();
    for (final dispatcher in dispatchers) {
      addDispatcher(dispatcher);
      await dispatcher.init();
    }
  }

  void addTag(String tag) => _tags.add(tag);
  void removeTag(String tag) => _tags.remove(tag);

  void addDispatcher(LoggerDispatcher dispatcher) {
    _dispatchers[dispatcher.name] = dispatcher;
  }

  void setDispatcher(String name, bool active) {
    if (!_dispatchers.containsKey(name)) return;
    _dispatchers[name]!.active = active;
  }

  void removeDispatcher(LoggerDispatcher dispatcher) {
    _dispatchers.remove(dispatcher.name);
  }

  void addWrapper(LoggerWrapperCallback c) => _wrapper.addWrapper(c);

  void removeWrapper() => _wrapper.removeWrapper();

  bool _canDispatch(List<String> tags) {
    if (_tags.isEmpty) return true;
    for (final tag in tags) {
      if (_tags.contains(tag)) return true;
    }
    return false;
  }

  Future<void> _dispatch(
    String message,
    LogType type,
    List<String> tags,
  ) async {
    bool res = _canDispatch(tags);
    if (!res) return;

    for (final func in _dispatchers.values) {
      if (!func.active) continue;
      await func.log(message, type, tags);
    }
  }

  Future<void> log(
    String message, {
    LogType type = LogType.debug,
    List<String> tags = const [],
  }) async {
    message = _wrapper.wrap(message, type, tags);

    await _dispatch(message, type, [..._defaultTags, ...tags]);
  }

  Future<void> debug(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.debug, tags: tags);
  }

  Future<void> info(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.info, tags: tags);
  }

  Future<void> warning(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.warning, tags: tags);
  }

  Future<void> error(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.error, tags: tags);
  }
}

class LoggerWrapper {
  final List<LoggerWrapperCallback> _wrappers = [];

  String wrap(String message, LogType type, List<String> tags) {
    for (final wrapper in _wrappers) {
      message = wrapper(message, type, tags);
    }
    return message;
  }

  addWrapper(LoggerWrapperCallback callback) {
    _wrappers.add(callback);
  }

  removeWrapper() {
    if (_wrappers.isNotEmpty) _wrappers.removeLast();
  }
}

/// Mixin to have builtin method of logger class
mixin Loggable {
  /// This field can be overrided such that by default uses those tags to log
  final List<String> loggerTags = [];

  log(
    String message, {
    LogType type = LogType.info,
    List<String> tags = const [],
  }) {
    logger.log(message, type: type, tags: [...loggerTags, ...tags]);
  }

  Future<void> debug(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.debug, tags: tags);
  }

  Future<void> info(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.info, tags: tags);
  }

  Future<void> warning(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.warning, tags: tags);
  }

  Future<void> error(String message, [List<String> tags = const []]) async {
    await log(message, type: LogType.error, tags: tags);
  }
}

/// LoggerDispatcher is the abstract class for log in different mode.
/// It is used by the Logger class when it dispatch a log.
/// When the log function of logger is called it execute `secureCall` that it cannot be overrided.
abstract class LoggerDispatcher {
  final String name;
  bool active = true;

  final LoggerWrapper _wrapper = LoggerWrapper();

  LoggerDispatcher({required this.name});

  /// Initialize the LoggerDispatcher
  Future<void> init() async {}

  Future<void> secureCall(
    String message,
    LogType type,
    List<String> tags,
  ) async {
    message = _wrapper.wrap(message, type, tags);
    await log(message, type, tags);
  }

  Future<void> log(String message, LogType type, List<String> tags);
}

class ConsoleDispatcher extends LoggerDispatcher {
  final _s = Semaphore();
  ConsoleDispatcher() : super(name: "console");

  @override
  Future<void> log(String message, LogType type, List<String> tags) async {
    await _s.lock();
    debugPrint(message);
    _s.release();
  }
}

/// FileLoggerDispatcher is used to log in files
/// The goal of this logger dispatcher is to write logs in different files
/// splitted per tags. By default it writes all logs in one file and one file per tags
/// Allowing to write a log in multiple files.
/// For now it saves the file with the following format by defalt:
/// [tag]_[year]_[month]_[day].log
/// Such that there's one file (for the same tag) per day.
/// But its format is defined by the [fileNameRole] that you can pass in the constructor.
class FileLoggerDispatcher extends LoggerDispatcher {
  final String path;
  final bool relative;
  final Mutex<Map<String, Mutex<File>>> _files = Mutex({});

  /// Function that you can modify to choose the name of the file log
  final String Function(String) fileNameRole;

  String get _path => [relative ? Directory.current.path : "", path].join('/');

  FileLoggerDispatcher({
    this.path = "",
    this.relative = true,
    this.fileNameRole = FileLoggerDispatcher.defaultFileNameRole,
  }) : super(name: "file");

  static String defaultFileNameRole(String tag) {
    final date = DateTime.now();

    String pad(int n, [int len = 2]) => n.toString().padLeft(2, '0');

    return "${tag}_${date.year}_${pad(date.month)}_${pad(date.day)}.log";
  }

  Future<Mutex<File>> _createIfAbsent(String tag) async {
    final files = await _files.lock();
    if (files.containsKey(tag)) return files[tag]!;
    final file = File([_path, fileNameRole(tag)].join('/'));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    files[tag] = Mutex(file);
    _files.release();
    return files[tag]!;
  }

  Future<void> _writeFile(String message, String tag) async {
    final mutex = await _createIfAbsent(tag);
    final f = await mutex.lock();

    try {
      await f.writeAsString("$message\n", mode: FileMode.append);
    } finally {
      mutex.release();
    }
  }

  @override
  Future<void> log(String message, LogType type, List<String> tags) async {
    await _writeFile(message, 'all-logs');
    for (final tag in tags) {
      await _writeFile(message, tag);
    }
  }
}
