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

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'enviroment.dart';
import 'tessera.dart';
import 'yaml_encoding.dart';

class Configuration {
  Configuration();

  static const String projectConfig = 'mosaic.yaml';

  Map<String, dynamic> _config = {};

  Map<String, dynamic> get config => Map.unmodifiable(_config);

  String? get defaultModule => _config['default'];

  Map<String, dynamic> get events => _config['events'] ?? {};

  String _getDefaultConfigFile(String name) {
    return '''name: $name
description: Entry point for the project configuration
version: 1.0.0
default_level: debug

debug:
  logger: debug
events:
''';
  }

  Future<void> createDefaultConfigFile(String name, String path) async {
    final file = File([path, projectConfig].join(Platform.pathSeparator));
    if (await file.exists()) {
      throw Exception('File already exists');
    }
    await file.create();
    await file.writeAsString(_getDefaultConfigFile(name));
  }

  Future<Map<String, dynamic>> read(String path) async {
    final config = File(path);

    final yamlMap = loadYaml(config.readAsStringSync());

    return jsonDecode(jsonEncode(yamlMap));
  }

  Future<void> write(String path, Map<String, dynamic> json) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('File $path does not exists');
    }
    final yaml = YamlEncoding().serialize(json);

    await file.writeAsString(yaml);
  }

  Future<Map<String, dynamic>> readConfig(String path) async {
    return read([path, projectConfig].join(Platform.pathSeparator));
  }

  Future<Map<String, dynamic>> loadFromEnv() async {
    final env = await Environment().root();

    if (env == null) {
      throw Exception('Invalid root');
    }

    _config = await readConfig(env.path);
    return _config;
  }

  Future<Tessera> tessera(String path) async {
    final file = await read(path);
    return Tessera.fromJson(file, path);
  }
}
