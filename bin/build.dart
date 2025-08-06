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

import 'package:args/args.dart';
import 'package:yaml_edit/yaml_edit.dart';

const String moduleEnv = 'config.json';
const String moduleDir = 'modules';

class _Module {
  _Module(this.name, [this.active = false, this.dependencies = const []]);

  factory _Module.fromJson(Map<String, dynamic> json) {
    final m = _Module(
      json['name'].toString(),
      json['active'] == true,
      (json['dependencies'] ?? []).map<String>((s) => s.toString()).toList(),
    );

    m._checkDependencies();

    return m;
  }

  final String name;
  bool active;
  final List<String> dependencies;

  bool _checkDependencies() {
    final res = dependsOn(name);
    if (res) {
      print('Invalid dependency: It cannot depend on itself');
      exit(1);
    }
    return res;
  }

  bool dependsOn(String name) {
    return dependencies.contains(name);
  }

  Map<String, dynamic> get json => {
    'name': name,
    'active': active,
    'dependencies': dependencies,
  };
}

class _ModuleManager {
  _ModuleManager(this.modules, this.defaultModule);

  factory _ModuleManager.fromJson(Map<String, dynamic> json) {
    final List<_Module> modules = [];
    for (dynamic m in json['modules']) {
      modules.add(_Module.fromJson(m));
    }

    return _ModuleManager(modules, json['defaultModule']);
  }

  List<_Module> modules;
  String? defaultModule;

  Map<String, dynamic> get json => {
    'defaultModule': defaultModule,
    'modules': modules.map((m) => m.json).toList(),
  };

  void add(String name) => modules.add(_Module(name));

  /// It checks if there are any modules that depends on it
  bool dependsOn(String name) {
    bool res = true;
    for (final m in modules) {
      if (!m.active) continue;
      if (m.dependsOn(name)) {
        print(
          '$name cannot be removed or disabled becase it depends on ${m.name}',
        );
        res = false;
      }
    }
    return res;
  }

  void remove(String name) => modules.removeWhere((m) => m.name == name);

  Future<void> save(String name) async {
    final file = File(name);
    final content = await file.readAsString();
    final parsed = jsonDecode(content);
    parsed['modules'] = json;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(parsed),
    );
  }

  Future loadFile() async {
    final imports = modules
        .map((m) => 'import \'package:${m.name}/${m.name}.dart\' as ${m.name};')
        .join('\n');
    final loader = [];
    if (defaultModule != null) {
      loader.add('moduleManager.defaultModule = ModuleEnum.$defaultModule;');
      loader.add('router.init(ModuleEnum.$defaultModule);');
    }
    for (final m in modules) {
      loader.add('''
  ${m.name}.module.active = ${m.active}; 
  moduleManager.modules[ModuleEnum.${m.name}] = ${m.name}.module;
''');
    }
    final content =
        '''
import 'package:modules/modules.dart';
import 'package:modules/automodule.dart';
import 'package:modules/router.dart';
$imports

Future<void> load() async {
  ${loader.join('\n\t')}
}
    ''';
    final load = File('apps/impronto/lib/load.dart');
    await load.writeAsString(content);
  }

  Future<void> modifyPubspec() async {
    final pubspec = File('apps/impronto/pubspec.yaml');
    final content = await pubspec.readAsString();
    final yaml = YamlEditor(content);

    // bool has(List<String> path) {
    //   try {
    //     yaml.parseAt(path);
    //     return true;
    //   } catch (ex) {
    //     return false;
    //   }
    // }
    //
    // final dependencies = yaml.parseAt(['dependencies']).value;

    // for (final dependency in dependencies) {}

    for (final module in modules) {
      yaml.update(
        ['dependencies', module.name],
        {'path': '../../modules/${module.name}'},
      );
    }
    await pubspec.writeAsString(yaml.toString());
  }

  _Module? get(String name) {
    for (final m in modules) {
      if (m.name == name) return m;
    }
    return null;
  }

  Future<void> generateEnum() async {
    final file = File('core/modules/lib/automodule.dart');
    String content = '';
    final String m = modules.map((x) => '\t${x.name}').join(',\n');

    content +=
        '''
enum ModuleEnum {
$m;

  static ModuleEnum? tryParse(String value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}
  ''';
    await file.writeAsString(content);
  }
}

Future<void> build() async {
  final _ModuleManager manager = await _loadModules();
  await manager.loadFile();
  await manager.modifyPubspec();
  await manager.generateEnum();

  try {
    final bootstrap = await Process.run('melos', ['bootstrap']);
    print(bootstrap.stdout.toString());
  } catch (err) {
    print('Trying to call \'melos bootstrab\' but an error occured');
  }
}

Future<_ModuleManager> _loadModules() async {
  final file = File(moduleEnv);
  if (!await file.exists()) {
    print('$moduleEnv not found');
    exit(1);
  }
  dynamic json = await file.readAsString();
  json = jsonDecode(json);
  return _ModuleManager.fromJson(json['modules']);
}

Future<void> _setModule(ArgResults? res, bool active) async {
  if (res == null) return;
  final manager = await _loadModules();
  final name = res.arguments.last;
  final module = manager.get(name);
  if (module == null) return;
  module.active = active;
  await manager.save(moduleEnv);
  await manager.loadFile();
}

Future<void> enable(ArgResults? res) async => _setModule(res, true);

Future<void> disable(ArgResults? res) async {
  if (res == null) {
    print('Required module name is missing');
    return;
  }
  final manager = await _loadModules();
  final name = res.arguments.last;
  final module = manager.get(name);
  if (module == null) {
    print('Module not found');
    return;
  }
  if (!manager.dependsOn(name)) {
    print(
      'You cannot disable this module because there are some modules that depend on this',
    );
    return;
  }
  _setModule(res, false);
}

Future<void> addModule(ArgResults? res) async {
  if (res == null) {
    print('res nullo');
    return;
  }
  final name = res.arguments.last;
  final manager = await _loadModules();
  manager.add(name);
  final dir = Directory('$moduleDir/$name');
  if (!(await dir.exists())) {
    await Process.run('flutter', [
      'create',
      name,
      '--template',
      'package',
    ], workingDirectory: moduleDir);
  }
  await manager.save(moduleEnv);
  await build();
}

Future<void> setDefault(ArgResults? res) async {
  if (res == null) {
    print('res nullo');
    return;
  }
  final name = res.arguments.last;
  final manager = await _loadModules();
  if (manager.get(name) == null) {
    print('There\'s no module $name in the module list');
    return;
  }
  manager.defaultModule = name;
  await manager.save(moduleEnv);
  await manager.loadFile();
}

Future<void> listModules(ArgResults? res) async {
  final list = await _loadModules();
  bool curr;
  print('The possible modules are:');
  for (int i = 0; i < list.modules.length; i++) {
    final module = list.modules[i];
    String desc = '';
    if (module.dependencies.isNotEmpty) {
      desc += '[${module.dependencies.join(', ')}]';
    }

    curr = (module.name == list.defaultModule);
    print(
      '$i) ${curr ? '*' : ' '}${module.name.padRight(20)}${module.active ? 'enabled ' : 'disabled'} $desc',
    );
  }
}

Future<void> removeModule(ArgResults? res) async {
  if (res == null) {
    print('res nullo');
  }
  final name = res!.arguments.last;
  final manager = await _loadModules();

  if (manager.dependsOn(name)) {
    manager.remove(name);
  }

  // final dir = Directory('modules/$name');
  // await dir.delete(recursive: true);
  await manager.save(moduleEnv);
  await build();
}
