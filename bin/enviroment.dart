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

import 'dart:collection';
import 'dart:io';
import 'tessera.dart';

class Environment {
  static const String projectMarker = 'mosaic.yaml';
  static const String packageMark = 'pubspec.yaml';
  static const String tesseraMark = 'tessera.yaml';

  static String get home => Platform.isWindows
      ? Platform.environment['USERPROFILE']!
      : Platform.environment['HOME']!;

  Directory? root([String? path]) {
    Directory curr = Directory.current;

    if (path != null) curr = Directory(path);

    while (curr.path != home && curr.path != curr.parent.path) {
      if (_containsFile(curr, projectMarker)) return curr;
      curr = curr.parent;
    }

    return null;
  }

  bool isValid([String? path]) => root(path) != null;

  Future<void> walk(
    Future<bool> Function(Directory) visitor, [
    String? path,
  ]) async {
    final curr = root(path);

    if (curr == null) return;

    final queue = Queue<Directory>();

    queue.add(curr);

    while (queue.isNotEmpty) {
      final head = queue.removeFirst();

      if (!await visitor(head)) continue;

      final subdir = head.listSync().whereType<Directory>().where(
        (d) => !_isHiddenDirectory(d),
      );

      queue.addAll(subdir);
    }
  }

  Future<void> walkCmd(List<String> cmd, [String? path]) async {
    return walk((d) async {
      if (isValidPackage(path: d.path)) {
        return _command(cmd, d);
      }
      return true;
    }, path);
  }

  bool isValidPackage({String? path, String target = packageMark}) {
    Directory curr = Directory.current;
    if (path != null) curr = Directory(path);

    final files = curr.listSync().whereType<File>();

    for (final file in files) {
      if (_filename(file) == target) return true;
    }

    return false;
  }

  Future<Set<String>> getExistingTesserae([String? path]) async {
    final tesserae = <String>{};
    walk((dir) async {
      if (!isValidPackage(path: dir.path, target: tesseraMark)) return false;

      tesserae.add(dir.path);

      return true;
    }, path);
    return tesserae;
  }

  String _filename(File file) =>
      file.path.split(Platform.pathSeparator).removeLast();

  bool _isHiddenDirectory(Directory dir) {
    final name = dir.path.split(Platform.pathSeparator).last;

    final hiddens = {'node_modules', 'build'};

    return name.startsWith('.') || hiddens.contains(name);
  }

  Future<bool> _command(List<String> cmd, Directory curr) async {
    final process = await Process.start(
      cmd[0],
      cmd.sublist(1),
      workingDirectory: curr.path,
      runInShell: true,
    );

    process.stdout
        .transform(const SystemEncoding().decoder)
        .listen(stdout.write);
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderr.write);

    await process.exitCode;

    return isValidPackage(path: curr.path);
  }

  bool _containsFile(Directory path, String target) {
    try {
      if (!path.existsSync()) return false;

      return path.listSync().whereType<File>().any(
        (f) => _filename(f) == target,
      );
    } catch (e) {
      return false;
    }
  }
}
