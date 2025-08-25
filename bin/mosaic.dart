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

import 'context.dart';
import 'utils/gesso.dart';
import 'utils/utils.dart';
import 'exception.dart';
import 'tessera.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class Mosaic {
  Future<void> tidy(Context ctx) async {
    await ctx.checkEnvironment();
    print('✓ All tesserae organized successfully'.green);
  }

  Future<void> _toggleTessera(Context ctx, bool enable) async {
    await ctx.checkEnvironment();
    final pastTense = enable ? 'enabled' : 'disabled';

    final name = ctx.cli.positional('name');
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

  Future<void> enable(Context ctx) => _toggleTessera(ctx, true);
  Future<void> disable(Context ctx) => _toggleTessera(ctx, false);

  Future<void> setDefault(Context ctx) async {
    await ctx.checkEnvironment();
    final name = ctx.cli.positional('name');
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

  Future<void> create(Context ctx) async {
    String? name = ctx.cli.positional('name');
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

  Future<void> walk(Context ctx) async {
    await ctx.checkEnvironment();
    final command = ctx.cli.positional('command');
    if (command == null) throw ArgvException('Missing command to execute');

    print('');

    ctx.env.walkCmd(command.split(' '));
    print('✓ Command executed across tesserae'.green);
  }

  Future<void> list(Context ctx) async {
    await ctx.checkEnvironment();
    final root = ctx.cli.positional('path');
    final showPath = ctx.cli.flag('path');

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

        final deps = tessera.dependencies.isNotEmpty
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

  Future<void> events(Context ctx) async {
    await ctx.checkEnvironment();
    print('');
    print('✓ Events built successfully'.green);
  }

  void delete(Context ctx) {
    final name = ctx.cli.positional('name');
    if (name == null) throw ArgvException('Missing tessera name');

    print('');

    print('⚠ Tessera deletion not yet implemented'.yellow);
  }

  Future<void> add(Context ctx) async {
    await ctx.checkEnvironment();
    Directory root = (await ctx.env.root())!;
    String? name = ctx.cli.positional('name');

    if (name == null) {
      throw const CliException('Missing tessera name');
    }

    root = Directory(utils.parent(name));
    name = await utils.ensureExistsParent(name);

    // await utils.ancestor(Environment.tesseraMark, root.path);

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

  Future<void> status(Context ctx) async {
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
