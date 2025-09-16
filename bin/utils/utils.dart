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
import 'dart:collection';
import 'dart:io';

final utils = Utils._instance;

class Utils {
  Utils._internal();
  static final _instance = Utils._internal();

  static final String sep = Platform.pathSeparator;

  static String get home => Platform.isWindows
      ? Platform.environment['USERPROFILE']!
      : Platform.environment['HOME']!;

  String join(List<String> paths) {
    return paths.join(sep);
  }

  List<String> split(String path) => path.split(sep);

  List<String> validateKeys(Map<String, dynamic> json, List<String> keys) {
    final res = <String>[];
    for (final key in keys) {
      if (!json.containsKey(key)) res.add(key);
    }
    return res;
  }

  String last(String path) => split(path).last;

  bool isHiddenDir(Directory dir) {
    final name = last(dir.path);

    final hiddens = {'node_modules', 'build'};

    return name.startsWith('.') || hiddens.contains(name);
  }

  Future<bool> containsFile(Directory path, String target) async {
    try {
      if (!await path.exists()) return false;

      return path.listSync().whereType<File>().any(
        (f) => utils.last(f.path) == target,
      );
    } catch (e) {
      return false;
    }
  }

  List<Directory> subdir(Directory current) {
    return current
        .listSync()
        .whereType<Directory>()
        .where((d) => !isHiddenDir(d))
        .toList();
  }

  Future<int> cmd(
    List<String> command, {
    String? path,
    bool out = false,
  }) async {
    path ??= Directory.current.path;

    final process = await Process.start(
      command[0],
      command.sublist(1),
      workingDirectory: path,
    );

    if (out) {
      stdout.addStream(process.stdout);
      stderr.addStream(process.stderr);
    }

    return process.exitCode;
  }

  Future<T?> walk<T>(
    Future<T?> Function(T?, Directory) visitor, {
    String? path,
    T? initial,
  }) async {
    T? accumulated = initial;
    Directory curr = Directory.current;

    if (path != null) curr = Directory(path);

    final queue = Queue<Directory>();

    queue.add(curr);

    while (queue.isNotEmpty) {
      final head = queue.removeFirst();

      accumulated = await visitor(accumulated, head);
      if (accumulated == null) continue;

      queue.addAll(utils.subdir(head));
    }
    return accumulated;
  }

  Future<T?> upward<T>(
    FutureOr<T?> Function(T?, Directory) visitor, {
    String? path,
    T? initial,
  }) async {
    T? accumulated = initial;

    Directory curr = Directory.current;
    if (path != null) curr = Directory(path);

    while (curr.path != home) {
      accumulated = await visitor(accumulated, curr);
      curr = curr.parent;
    }

    return accumulated;
  }

  Future<Directory?> ancestor(String name, [String? path]) async {
    return upward((acc, dir) async {
      if (acc != null) return acc;
      if (await containsFile(dir, name)) return dir;
      return null;
    }, path: path);
  }

  Future<int> install({
    String? path,
    String name = 'mosaic',
    String? packagePath,
  }) async {
    final args = ['flutter', 'pub', 'add', name];

    if (packagePath != null) args.addAll(['--path', packagePath]);

    return utils.cmd(args, path: path, out: true);
  }

  String parent(String path) => Directory(path).parent.path;

  Future<String> ensureExistsParent(String path) async {
    final splitted = split(path);
    if (splitted.length == 1) return path;
    final dir = Directory(join(splitted.sublist(0, splitted.length - 1)));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return splitted.last;
  }

  Future<File> ensureExists(String file) async {
    final f = File(file);
    if (await f.exists()) return f;
    await f.create(recursive: true);
    return f;
  }

  List<String> parseCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return [];

    final spaceIndex = trimmed.indexOf(' ');
    if (spaceIndex == -1) {
      return [trimmed];
    }

    final executable = trimmed.substring(0, spaceIndex);
    final args = trimmed.substring(spaceIndex + 1).trim();

    return args.isEmpty ? [executable] : [executable, args];
  }
}

extension StringExtension on String {
  String get capitalized {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
