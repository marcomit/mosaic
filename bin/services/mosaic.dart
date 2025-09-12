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
import '../utils/gesso.dart';
import '../utils/utils.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class MosaicService {
  Future<void> tidy(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    await ctx.env.walkCmd(['flutter', 'pub', 'get']);

    print('✓ All tesserae organized successfully'.green);
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
      utils.join([root!.path, name]),
    ]);
  }

  Future<void> sync(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final content = await ctx.getInitializationFile();

    final name = ctx.config.get('name');
    final root = await ctx.env.root();

    final path = utils.join([root!.path, name, 'lib', 'init.dart']);

    final file = await utils.ensureExists(path);

    await file.writeAsString(content);
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
    print('  mosaic add <tessera-name>'.cyan);
  }

  Future<void> walk(ArgvResult cli) async {
    final env = cli.get<Context>().env;

    final command = cli.positional('command');
    if (command == null) throw ArgvException('Missing command to execute');

    print('');

    env.walkCmd(command.split(' '));
    print('✓ Command executed across tesserae'.green);
  }

  Future<void> list(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final root = cli.positional('path');
    final showPath = cli.option('path');

    print('');

    final existing = await ctx.tesserae(root);
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
    final root = await ctx.env.root();

    if (root == null) {
      print('✗ '.red + 'Not in a mosaic project'.dim);
      return;
    }

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
}
