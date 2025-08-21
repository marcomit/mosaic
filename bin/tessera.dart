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

import 'context.dart';
import 'enviroment.dart';
import 'utils/utils.dart';
import 'exception.dart';

class Tessera {
  Tessera(
    this.name, {
    required this.path,
    this.active = false,
    this.dependencies = const [],
  });

  factory Tessera.fromJson(Map<String, dynamic> json, String path) {
    List<String> deps = [];

    _validateKeys(json);

    deps = (json['dependencies'] ?? [])
        .map<String>((e) => e.toString())
        .toList();

    return Tessera(
      json['name'] ?? '',
      active: json['active'] == true,
      dependencies: deps,
      path: path,
    );
  }

  static void _validateKeys(Map<String, dynamic> json) {
    final keys = ['dependencies', 'name', 'active'];
    final missing = utils.validateKeys(json, keys);
    if (missing.isNotEmpty) {
      throw CliException(
        'Tessera config corrupted, missing fields ${missing.join(', ')}',
      );
    }

    if (json['dependencies'] is! List?) {
      throw CliException(
        'Field dependencies must be a list, got ${json['dependencies'].runtimeType}',
      );
    }
  }

  String get defaultConfig => '''name: $name
active: true
dependencies:
''';

  bool get canDelete => dependencies.isEmpty;

  String get defaultEntry {
    final capitalized = name.capitalized;
    return '''// This is the entry point for $name
import 'package:mosaic/mosaic.dart';
import 'package:flutter/widgets.dart';

class $capitalized extends Module {
  $capitalized() : super(name: '$name');

  @override
  Future<void> onInit() async {
    // Load all services here
  }

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }

}
''';
  }

  Future<void> createEntry() async {
    final file = File(utils.join([path, 'lib', '$name.dart']));
    await file.writeAsString(defaultEntry);
  }

  Future<void> createConfig() async {
    final file = File(utils.join([path, Environment.tesseraMark]));

    if (await file.exists()) {
      throw CliException('File ${file.path} already exists');
    }

    await file.create();
    await file.writeAsString(defaultConfig);
  }

  final String name;
  final String path;
  final List<String> dependencies;
  bool active;

  Map<String, dynamic> serialize() {
    return {'name': name, 'active': active, 'dependencies': dependencies};
  }

  Future<void> enable(Context ctx) async {
    active = true;
    await save(ctx);
  }

  Future<void> disable(Context ctx) async {
    active = false;
    await save(ctx);
  }

  Future<void> delete(Context ctx) async {
    final tessera = Directory(path);

    try {
      await tessera.delete(recursive: true);
    } catch (e) {
      print('Error deleting tessera $name');
      exit(1);
    }
  }

  Future<void> save(Context ctx) async {
    try {
      await ctx.config.write(
        utils.join([path, Environment.tesseraMark]),
        serialize(),
      );
    } catch (e) {
      print('Error saving the configuration of tessera $name');
      exit(1);
    }
  }

  Future<int> create() async {
    final exitCode = await utils.cmd([
      'flutter',
      'create',
      name,
      '--template',
      'package',
    ], path: Directory(path).parent.path);

    if (exitCode != 0) return exitCode;

    await createConfig();
    await createEntry();

    await utils.install(path: path);

    return 0;
  }
}
