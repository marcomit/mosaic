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
import 'gesso.dart';

/// Mosaic in this case refers like the orchestrator of the tesserae
class Mosaic {
  Future<void> tidy(Context ctx) async {
    ctx.validateNoRestArgs();
  }

  Future<void> _toggleTessera(Context ctx, bool enable) async {
    final action = enable ? 'enable' : 'disable';
    final actionGerund = enable ? 'Enabling' : 'Disabling';
    final pastTense = enable ? 'enabled' : 'disabled';

    try {
      ctx.validateRestArgsLength(1);
      final name = ctx.restArgs[0];

      print('$actionGerund tessera '.dim + name.cyan.bold + '...'.dim);

      final tessera = await ctx.getTesseraFromName(name);
      if (tessera == null) {
        print('Error: Tessera '.red + name.bold + ' not found'.red);
        print(
          'Use '.dim + 'mosaic list'.cyan + ' to see available tesserae'.dim,
        );
        exit(1);
      }

      if (enable) {
        await tessera.enable(ctx);
      } else {
        await tessera.disable(ctx);
      }

      print('Success: Tessera '.green + name.bold.green + ' $pastTense'.green);
    } catch (e) {
      print('Error: Failed to $action tessera - '.red + e.toString().red);
      exit(1);
    }
  }

  Future<void> enable(Context ctx) => _toggleTessera(ctx, true);
  Future<void> disable(Context ctx) => _toggleTessera(ctx, false);
  Future<void> setDefault(Context ctx) async {
    ctx.config.config['initial'] = '';
  }

  Future<void> create(Context ctx) async {}

  Future<void> walk(Context ctx) async {}

  Future<void> list(Context ctx) async {
    ctx.validateNoRestArgs();

    final existing = await ctx.tesserae(ctx.config.moduleDir);
    final defaultModule = ctx.config.defaultModule;

    if (existing.isNotEmpty) {
      print('Available Tesserae:'.bold.cyan);
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

        print('  $prefix $name ($status)$deps');
      }

      if (defaultModule != null) {
        print('');
        print('  ● Default module'.dim.italic);
      }
    } else {
      print('No tesserae found.'.dim.italic);
      print(
        'Use '.dim + 'mosaic add <name>'.cyan + ' to create a new tessera.'.dim,
      );
    }
  }

  Future<void> events(Context ctx) async {}
}
