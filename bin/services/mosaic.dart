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

import 'package:argv/argv.dart';
import 'package:path/path.dart' as p;

import '../context.dart';
import '../models/profile.dart';
import '../models/tessera.dart';
import '../utils/gesso.dart';
import '../exception.dart';
import '../utils/utils.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class MosaicService {
  /// Resolves the package directories targeted by a `--resolution` value:
  /// * `global` (default) — every package in the project
  /// * `tesserae` — only tessera packages
  /// * `profile` — tesserae belonging to the current profile
  Future<List<String>> _resolvePackagePaths(
    Context ctx,
    String resolution,
  ) async {
    switch (resolution) {
      case 'tesserae':
        return (await ctx.tesserae()).map((t) => t.path).toList();
      case 'profile':
        final current = ctx.config.get('profile');
        final profiles = ctx.config.get('profiles') as Map? ?? {};
        if (current == null || !profiles.containsKey(current)) {
          throw const CliException('No current profile set');
        }
        final profile = Profile.parse(MapEntry(current, profiles[current]));
        final all = await ctx.tesserae();
        return all
            .where((t) => profile.tesserae.contains(t.name))
            .map((t) => t.path)
            .toList();
      case 'global':
      default:
        return (await ctx.env.getAllPackages()).values.toList();
    }
  }

  Future<void> tidy(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final resolution = cli.option('resolution') ?? 'global';
    final paths = await _resolvePackagePaths(ctx, resolution);

    print('');
    for (final path in paths) {
      print(utils.last(path).bold.green);
      await utils.cmd(['flutter', 'pub', 'get'], path: path);
    }

    print('');
    print('✓ Dependencies resolved across ${paths.length} package(s)'.green);
  }

  Future<void> run(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final root = await ctx.env.root();
    final name = ctx.config.get('name');
    if (name == null) {
      throw ArgvException('Missing name field inside the mosaic.yaml file');
    }

    await utils.cmd([
      'flutter',
      'run',
      '-t',
      utils.join([root.path, name]),
    ]);
  }

  Future<void> sync(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final tesserae = await ctx.tesserae();

    if (tesserae.isEmpty) {
      throw const CliException('No tesserae found in this mosaic');
    }

    await ctx.writeInitializationFile(
      tesserae.toList(),
      tesserae.elementAt(0).name,
      comment: cli.flag('no-comment'),
    );
  }

  Future<void> setDefault(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('name');
    if (name == null) {
      final initial = ctx.config.get('default');
      if (initial == null) {
        print('Default tessera not found');
        return;
      }
      print('Initial tessera: $initial');
      return;
    }

    final exists = await ctx.env.exists(name);

    if (!exists) {
      print('$name does not an existing tessera');
      return;
    }

    print('');
    ctx.config.set('default', name);
    await ctx.config.save();
    print('✓ Default tessera set to '.green + name.bold.green);
  }

  Future<void> create(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    String? name = cli.positional('name');
    if (name == null) throw ArgvException('Missing project name');

    if (await ctx.env.isValid()) {
      throw ArgvException(
        'Already inside a mosaic project (sub-mosaics coming soon)',
      );
    }

    name = await utils.ensureExistsParent(name);

    final root = Directory(name);
    if (await root.exists()) {
      throw ArgvException('Mosaic $name already exists');
    }

    print('');

    print('✓ Project configurations'.green);

    await ctx.config.createDefaultConfigFile(name, root.path);

    await utils.cmd(['flutter', 'create', name], path: root.path);
    print('✓ Project structure created'.green);

    final code = await utils.install(path: utils.join([root.path, name]));
    print('Cod: $code');

    print('✓ Mosaic marker initialized'.green);
    print('');
    print('Next steps:'.bold.cyan);
    print('  cd $name'.dim);
    print('  mosaic tessera add <tessera-name>'.cyan);
  }

  Future<void> walk(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    final command = cli.positional('command');
    if (command == null) throw ArgvException('Missing command to execute');

    final resolution = cli.option('resolution') ?? 'global';
    final paths = await _resolvePackagePaths(ctx, resolution);
    final parsed = utils.parseCommand(command);
    final out = cli.flag('output');

    print('');
    for (final path in paths) {
      print(utils.last(path).bold.green);
      await utils.cmd(parsed, path: path, out: out);
      if (out) print('');
    }

    print('');
    print('✓ Command executed across ${paths.length} package(s)'.green);
  }

  Future<void> list(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final showPath = cli.option('path');

    print('');

    final existing = await ctx.tesserae();
    final defaultModule = ctx.config.get('default');

    if (existing.isNotEmpty) {
      print('${'Available Tesserae'.bold.cyan}:');
      print('');

      for (final tessera in existing) {
        final isDefault = tessera.name == defaultModule;

        String prefix = '○'.brightBlack;
        String name = tessera.name.white;

        if (isDefault) {
          prefix = '●'.brightGreen;
          name = tessera.name.bold.brightGreen;
        }

        String status = 'disabled'.brightRed;
        if (tessera.active) status = 'enabled'.brightGreen;

        final deps = tessera.dependencies.isNotEmpty && cli.flag('deps')
            ? ' [${tessera.dependencies.join(', ')}]'.dim
            : '';

        final blocks = ['  $prefix $name'.padRight(30), ' ($status)$deps'.dim];
        if (showPath != null) {
          if (showPath == 'rel') {
            blocks.add(' ${p.relative(tessera.path)} ');
          } else {
            blocks.add(' ${tessera.path}');
          }
        }

        print(blocks.join(''));
      }

      if (defaultModule != null) {
        print('');
        print('  ● = Default tessera'.dim.italic);
      }

      print('');
      print(
        'Found ${existing.length} tessera${existing.length != 1 ? 'e' : ''}'
            .dim,
      );
    } else {
      print('No tesserae discovered'.dim.italic);
      print('');
      print('Get started:'.bold.cyan);
      print('  mosaic add <name>'.cyan + ' - Create a new tessera'.dim);
    }
  }

  Future<void> status(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    if (!await ctx.env.isValid()) {
      print('✗ '.red + 'Not in a mosaic project'.dim);
      return;
    }
    final root = await ctx.env.root();

    final config = ctx.config;
    final tesserae = await ctx.tesserae();
    final currentProfile = config.get('profile');
    final profiles = config.get('profiles') as Map? ?? {};

    print('Project: '.dim + config.get('name').toString().cyan.bold);
    print('Root: '.dim + root.path.dim);
    print('Profile: '.dim + (currentProfile?.toString().green ?? 'none'.red));
    print(
      'Tesserae: '.dim +
          '${tesserae.length}'.cyan +
          ' (${tesserae.where((t) => t.active).length} active)'.dim,
    );
    print('Profiles: '.dim + '${profiles.length}'.cyan);
  }

  /// Validates the project and reports problems: missing config, dangling or
  /// circular dependencies, missing entry files, mis-configured gates, and
  /// invalid profiles. Exits non-zero when issues are found.
  Future<void> doctor(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final issues = <String>[];
    final warnings = <String>[];

    void ok(String msg) => print('  ✓ '.green + msg.dim);
    void fail(String msg) {
      issues.add(msg);
      print('  ✗ '.red + msg);
    }

    void warn(String msg) {
      warnings.add(msg);
      print('  ! '.yellow + msg);
    }

    print('');
    print('Running diagnostics...'.bold.cyan);
    print('');

    if (!await ctx.env.isValid()) {
      throw const CliException('Not inside a mosaic project');
    }
    await ctx.config.loadFromEnv();

    if (ctx.config.get('name') == null) {
      fail('mosaic.yaml is missing the "name" field');
    } else {
      ok('Project name present');
    }

    final defaultTessera = ctx.config.get('default');
    final tesserae = (await ctx.tesserae()).toList();
    final names = tesserae.map((t) => t.name).toSet();

    // Dependencies reference existing tesserae.
    for (final tessera in tesserae) {
      for (final dep in tessera.dependencies) {
        if (!names.contains(dep)) {
          fail('Tessera "${tessera.name}" depends on missing "$dep"');
        }
      }
      // Entry file exists.
      final entry =
          File(utils.join([tessera.path, 'lib', '${tessera.name}.dart']));
      if (!entry.existsSync()) {
        fail('Tessera "${tessera.name}" is missing lib/${tessera.name}.dart');
      }
      // A gate only makes sense for lazy tesserae.
      if (tessera.gate != null && !tessera.lazy) {
        warn('Tessera "${tessera.name}" sets a gate but is not lazy');
      }
    }
    if (tesserae.isNotEmpty) ok('${tesserae.length} tessera(e) discovered');

    // Cycle detection.
    try {
      Tessera.topologicalSort(tesserae);
      ok('No circular dependencies');
    } on CliException catch (e) {
      fail(e.message);
    }

    // Default tessera exists.
    if (defaultTessera != null && !names.contains(defaultTessera)) {
      fail('Default tessera "$defaultTessera" does not exist');
    }

    // Profiles parse and reference existing tesserae.
    final profiles = ctx.config.get('profiles') as Map? ?? {};
    for (final entry in profiles.entries) {
      try {
        final profile = Profile.parse(entry);
        for (final t in profile.tesserae) {
          if (!names.contains(t)) {
            fail('Profile "${profile.name}" references missing tessera "$t"');
          }
        }
      } on CliException catch (e) {
        fail('Profile "${entry.key}": ${e.message}');
      }
    }
    if (profiles.isNotEmpty) ok('${profiles.length} profile(s) valid');

    print('');
    if (issues.isEmpty) {
      print('✓ '.green + 'Everything looks healthy'.green +
          (warnings.isEmpty ? '' : ' (${warnings.length} warning(s))'.dim));
    } else {
      print('✗ '.red + '${issues.length} issue(s) found'.red);
      exit(1);
    }
  }
}
