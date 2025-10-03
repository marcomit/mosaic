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
import 'models/tessera.dart';
import 'utils/yaml_encoding.dart';
import 'utils/utils.dart';
import 'exception.dart';
import 'models/profile.dart';

class Configuration {
  Configuration();

  static const String projectConfig = 'mosaic.yaml';

  Map<String, dynamic> _config = {};

  String? get defaultModule => _config['default'];

  Map<String, dynamic> get events => _config['events'] ?? {};

  String _getDefaultConfigFile(String name) {
    return '''# Note: this is a generated file, don't touch it!!!
name: $name
description: Entry point for the project configuration
version: 1.0.0

default: $name

events:

profiles:
  development:
    tesserae: []
    default: ''
''';
  }

  Future<void> createDefaultConfigFile(String name, String path) async {
    final file = File(utils.join([path, projectConfig]));
    if (await file.exists()) {
      throw Exception('File already exists');
    }
    await file.create(recursive: true);
    await file.writeAsString(_getDefaultConfigFile(name));
  }

  dynamic get(String name) => _config[name];
  void set(String key, dynamic value) => _config[key] = value;

  Future<void> save() async {
    final env = await Environment().root();
    final path = utils.join([env.path, Environment.projectMarker]);
    await write(path, _config);
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
    return read(utils.join([path, projectConfig]));
  }

  Future<Map<String, dynamic>> loadFromEnv() async {
    final env = await Environment().root();

    _config = await readConfig(env.path);
    return _config;
  }

  Future<void> validateConfig() async {
    final profiles = get('profiles');
    if (profiles is! Map) throw const CliException('Invalid profiles');

    profiles.entries.map(Profile.parse);

    if (get('profile') == null) {
      throw const CliException(
        'Missing \'profile\' field inside configuration file',
      );
    }
  }

  Future<Tessera> tessera(String path) async {
    final file = await read(path);
    return Tessera.fromJson(file, path);
  }
}
