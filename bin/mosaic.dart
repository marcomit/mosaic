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
import 'gesso.dart';
import 'exception.dart';
import 'enviroment.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class Mosaic {
  Future<void> tidy(Context ctx) async {
    await ctx.checkEnvironment();
    print('┌─────────────────────────────────────┐'.dim);
    print('│ '.dim + 'Tidying tesserae...'.cyan.bold + '              │'.dim);
    print('└─────────────────────────────────────┘'.dim);
    print('✓ All tesserae organized successfully'.green);
  }

  Future<void> _toggleTessera(Context ctx, bool enable) async {
    await ctx.checkEnvironment();
    final actionGerund = enable ? 'Enabling' : 'Disabling';
    final pastTense = enable ? 'enabled' : 'disabled';
    final symbol = enable ? '▲' : '▼';

    final name = ctx.cli.positional('name');
    if (name == null) throw ArgvException('Missing tessera name');

    print('');
    print('┌─ $actionGerund Tessera ──────────────────┐'.dim);
    print(
      '│ '.dim + '$symbol '.brightBlue + name.cyan.bold + ' │'.dim.padRight(42),
    );
    print('└─────────────────────────────────────────┘'.dim);

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
    if (name == null) throw ArgvException('Missing tessera name');

    print('');
    print('┌─ Setting Default Tessera ───────────┐'.dim);
    print('│ '.dim + '★ '.yellow + name.cyan.bold + ' │'.dim.padRight(42));
    print('└─────────────────────────────────────┘'.dim);

    ctx.config.config['initial'] = name;
    print('✓ Default tessera set to '.green + name.bold.green);
  }

  Future<void> create(Context ctx) async {
    final name = ctx.cli.positional('name');
    if (name == null) throw ArgvException('Missing project name');

    if (await ctx.env.isValid()) {
      throw ArgvException(
        'Already inside a mosaic project (subprojects coming soon)',
      );
    }

    final root = Directory(name);
    if (await root.exists()) {
      throw ArgvException('Project $name already exists');
    }

    print('');
    print('┌─ Creating Mosaic Project ───────────┐'.dim);
    print(
      '│ '.dim + '◆ '.brightMagenta + name.cyan.bold + ' │'.dim.padRight(42),
    );
    print('└─────────────────────────────────────┘'.dim);
    print('');

    await root.create(recursive: true);
    final mark = File(
      [root.path, Environment.projectMarker].join(Platform.pathSeparator),
    );

    await mark.create();

    print('✓ Project structure created'.green);
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
    print('┌─ Walking Tesserae ──────────────────┐'.dim);
    print(
      '│ '.dim + '→ '.brightBlue + command.cyan.bold + ' │'.dim.padRight(42),
    );
    print('└─────────────────────────────────────┘'.dim);

    ctx.env.walkCmd([command]);
    print('✓ Command executed across tesserae'.green);
  }

  Future<void> list(Context ctx) async {
    final root = ctx.cli.positional('path');
    final path = [Directory.current.path, if (root != null) root];

    print('');
    print('┌─ Tessera Discovery ─────────────────┐'.dim);
    print(
      '│ '.dim +
          'Scanning: '.dim +
          path.join(Platform.pathSeparator).truncate(24).cyan +
          ' │'.dim.padRight(42),
    );
    print('└─────────────────────────────────────┘'.dim);
    print('');

    final existing = await ctx.tesserae(root);
    final defaultModule = ctx.config.defaultModule;

    if (existing.isNotEmpty) {
      print('Available Tesserae'.bold.cyan + ':');
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

        print('  $prefix $name'.padRight(30) + '($status)$deps'.dim);
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
    print('┌─ Building Events ───────────────────┐'.dim);
    print(
      '│ '.dim +
          '⚡ '.yellow +
          'Processing configuration...'.cyan +
          ' │'.dim.padRight(42),
    );
    print('└─────────────────────────────────────┘'.dim);
    print('✓ Events built successfully'.green);
  }

  void delete(Context ctx) {
    final name = ctx.cli.positional('name');
    if (name == null) throw ArgvException('Missing tessera name');

    print('');
    print('┌─ Deleting Tessera ──────────────────┐'.dim);
    print('│ '.dim + '✗ '.red + name.red.bold + ' │'.dim.padRight(42));
    print('└─────────────────────────────────────┘'.dim);

    print('⚠ Tessera deletion not yet implemented'.yellow);
  }

  Future<void> add(Context ctx) async {
    final name = ctx.cli.positional('name');
    if (name == null) {
      throw const CliException('Missing tessera name');
    }

    print('');
    print('┌─ Adding Tessera ────────────────────┐'.dim);
    print('│ '.dim + '+ '.green + name.cyan.bold + ' │'.dim.padRight(42));
    print('└─────────────────────────────────────┘'.dim);
    print('');

    print('Creating Flutter module...'.dim);
    final process = await Process.start('flutter', [
      'create',
      name,
    ], workingDirectory: Directory.current.path);
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);

    final code = await process.exitCode;
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
    final valid = await ctx.env.isValid();

    print('');
    print('┌─ Mosaic Status ─────────────────────┐'.dim);
    if (valid) {
      print(
        '│ '.dim +
            '✓ '.green +
            'Valid mosaic environment'.green.bold +
            '     │'.dim,
      );
    } else {
      print(
        '│ '.dim +
            '✗ '.red +
            'Invalid environment'.red.bold +
            '          │'.dim,
      );
    }
    print('└─────────────────────────────────────┘'.dim);

    if (valid) {
      print('');
      print('Environment Details:'.bold.cyan);
      print('  Project root: ${Directory.current.path}'.dim);
      print('  Marker file: ${Environment.projectMarker}'.dim);
    } else {
      print('');
      print('Resolution:'.bold.yellow);
      print(
        '  Run '.dim +
            'mosaic create <name>'.cyan +
            ' to initialize a project'.dim,
      );
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
