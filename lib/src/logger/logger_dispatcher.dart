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
import 'dart:io';

import 'package:flutter/cupertino.dart';
import '../thread_safety/mutex.dart';
import 'logger.dart';
import 'logger_wrapper.dart';
import '../thread_safety/semaphore.dart';

/// LoggerDispatcher is the abstract class for log in different mode.
/// It is used by the Logger class when it dispatch a log.
/// When the log function of logger is called it execute `secureCall` that it cannot be overrided.
abstract class LoggerDispatcher {
  bool _disposed = false;
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

  Future<void> dispose() async {
    if (_disposed) _disposed = true;
  }
}

class ConsoleDispatcher extends LoggerDispatcher {
  final _s = Semaphore();
  ConsoleDispatcher() : super(name: "console");

  @override
  Future<void> log(String message, LogType type, List<String> tags) async {
    try {
      await _s.lock();
      debugPrint(message);
    } finally {
      _s.release();
    }
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
    return await _files.use((files) async {
      if (files.containsKey(tag)) return files[tag]!;
      try {
        final file = File([_path, fileNameRole(tag)].join('/'));
        if (!await file.exists()) {
          await file.create(recursive: true);
        }
        files[tag] = Mutex(file);
      } finally {}
      return files[tag]!;
    });
  }

  Future<void> _writeFile(String message, String tag) async {
    final mutex = await _createIfAbsent(tag);

    try {
      final f = await mutex.lock();
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
