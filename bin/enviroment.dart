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
import 'utils/utils.dart';

class Environment {
  static const String projectMarker = 'mosaic.yaml';
  static const String packageMark = 'pubspec.yaml';
  static const String tesseraMark = 'tessera.yaml';

  Future<Directory> root([String? path]) async {
    final res = await utils.ancestor(projectMarker);
    return res!;
  }

  Future<bool> isValid() async => await utils.ancestor(projectMarker) != null;

  Future<void> walk(
    Future<bool> Function(Directory) visitor, [
    String? path,
  ]) async {
    await utils.walk<bool>((acc, c) async {
      final visited = await visitor(c);
      if (!visited) return null;
      return visited;
    }, path: path);
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
      if (utils.last(file.path) == target) return true;
    }

    return false;
  }

  Future<Set<String>> getExistingTesserae([String? path]) async {
    final tesserae = <String>{};
    await walk((dir) async {
      if (!isValidPackage(path: dir.path, target: tesseraMark)) return true;

      tesserae.add(dir.path);

      return false;
    }, path);
    return tesserae;
  }

  Future<bool> exists(String name) async {
    final tesserae = await getExistingTesserae();
    for (final tessera in tesserae) {
      if (utils.last(tessera) == name) return true;
    }
    return false;
  }

  Future<bool> _command(List<String> cmd, Directory curr) async {
    await utils.cmd(cmd, path: curr.path);
    return isValidPackage(path: curr.path);
  }

  Future<Map<String, String>> getAllPackages([String? path]) async {
    final packages = <String, String>{};
    await walk((dir) async {
      if (!isValidPackage(path: dir.path, target: packageMark)) return true;

      packages[utils.last(dir.path)] = dir.path;

      return false;
    }, path);
    return packages;
  }
}
