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

import '../context.dart';
import '../utils/gesso.dart';
import '../utils/utils.dart';
import '../exception.dart';
import '../tessera.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class MosaicService {
  Future<void> tidy(ArgvResult cli) async {
    print('✓ All tesserae organized successfully'.green);
  }

  Future<void> _toggleTessera(ArgvResult cli, bool enable) async {
    final ctx = cli.get<Context>();
    final pastTense = enable ? 'enabled' : 'disabled';

    final name = cli.positional('name');
    if (name == null) throw ArgvException('Missing tessera name');

    print('');

    final tessera = await ctx.getTesseraFromName(name);
    if (tessera == null) {
      print('');
      print('✗ Tessera '.red.bold + name.bold + ' not found'.red.bold);
      print(
        '  Use '.dim + 'mosaic list'.cyan + ' to see available tesserae'.dim,
      );
      exit(1);
    }

    if (enable) {
      await tessera.enable(ctx);
    } else {
      await tessera.disable(ctx);
    }

    print('');
    print(
      '✓ Tessera '.green.bold +
          name.bold.green +
          ' $pastTense successfully'.green.bold,
    );
  }

  Future<void> enable(ArgvResult cli) => _toggleTessera(cli, true);
  Future<void> disable(ArgvResult cli) => _toggleTessera(cli, false);

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
    print('prprprprp');
    final ctx = cli.get<Context>();
    String? name = cli.positional('name');
    if (name == null) throw ArgvException('Missing project name');

    if (await ctx.env.isValid()) {
      throw ArgvException(
        'Already inside a mosaic project (subprojects coming soon)',
      );
    }

    name = await utils.ensureExistsParent(name);

    final root = Directory(name);
    if (await root.exists()) {
      throw ArgvException('Project $name already exists');
    }

    print('');

    print('✓ Project structure created'.green);

    await ctx.config.createDefaultConfigFile(name, root.path);

    await utils.cmd(['flutter', 'create', name], path: root.path);

    await utils.install(path: root.path);

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
    final showPath = cli.flag('path');

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

        final blocks = [
          '  $prefix $name'.padRight(30),
          ' ($status)$deps'.dim,
          if (showPath) ' ${tessera.path} ',
        ];
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

  Future<void> events(ArgvResult cli) async {
    print('');
    print('✓ Events built successfully'.green);
  }

  void delete(ArgvResult cli) {
    final name = cli.positional('name');
    if (name == null) throw ArgvException('Missing tessera name');

    print('');

    print('⚠ Tessera deletion not yet implemented'.yellow);
  }

  Future<void> add(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    Directory root = (await ctx.env.root())!;
    String? name = cli.positional('name');

    if (name == null) {
      throw const CliException('Missing tessera name');
    }

    root = Directory(utils.parent(name));
    name = await utils.ensureExistsParent(name);

    if (await ctx.env.exists(name)) {
      throw CliException('Tessera $name already exists');
    }
    print('');

    print('Creating Flutter module...'.dim);
    final tessera = Tessera(
      name,
      path: utils.join([root.path, name]),
      active: true,
    );
    final code = await tessera.create();
    if (code == 0) {
      print('');
      print(
        '✓ Tessera '.green + name.bold.green + ' created successfully'.green,
      );
    } else {
      print('');
      print('✗ Failed to create tessera '.red + name.bold);
    }
  }

  Future<void> status(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final root = await ctx.env.root();
    if (root == null) {
      print('You\'re not in a valid project');
    } else {
      print('Project root: ${root.path}');
    }
  }
}

// Extension to truncate strings for display
extension StringTruncate on String {
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 3)}...';
  }
}
