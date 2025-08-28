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
import '../utils/utils.dart';
import '../utils/gesso.dart';
import '../exception.dart';
import '../tessera.dart';

class TesseraService {
  Future<void> add(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final root = (await ctx.env.root())!;
    String? name = cli.positional('name');

    if (name == null) {
      throw const CliException('Missing tessera name');
    }

    name = await utils.ensureExistsParent(name);

    if (await ctx.env.exists(name)) {
      throw CliException('Tessera $name already exists');
    }

    print('Creating tessera '.dim + name.cyan.bold + '...'.dim);

    final tessera = Tessera(
      name,
      path: utils.join([root.path, name]),
      active: true,
    );

    final code = await tessera.create();

    if (code == 0) {
      print('✓ '.green + 'Tessera '.dim + name.cyan.bold + ' created'.green);
    } else {
      print('✗ '.red + 'Failed to create tessera '.dim + name.red);
      exit(1);
    }
  }

  Future<void> _toggleTessera(ArgvResult cli, bool enable) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('name');
    final action = enable ? 'enabled' : 'disabled';

    if (name == null) throw ArgvException('Missing tessera name');

    final tessera = await ctx.getTesseraFromName(name);
    if (tessera == null) {
      print('✗ '.red + 'Tessera '.dim + name.red + ' not found'.dim);
      print('Use '.dim + 'mosaic list'.cyan + ' to see available tesserae'.dim);
      return;
    }

    if (enable) {
      await tessera.enable(ctx);
    } else {
      await tessera.disable(ctx);
    }

    print('✓ '.green + 'Tessera '.dim + name.cyan + ' $action'.dim);
  }

  Future<void> enable(ArgvResult cli) => _toggleTessera(cli, true);
  Future<void> disable(ArgvResult cli) => _toggleTessera(cli, false);

  Future<void> depsAdd(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final tessera = await _prepareDeps(cli);
    final dependency = cli.positional('dependency')!;

    if (tessera.dependencies.contains(dependency)) {
      throw CliException('Dependency $dependency already exists');
    }

    tessera.dependencies.add(dependency);
    await tessera.save(ctx);

    print(
      '✓ '.green +
          'Added dependency '.dim +
          dependency.cyan +
          ' to '.dim +
          tessera.name.cyan,
    );
  }

  Future<void> depsRemove(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final tessera = await _prepareDeps(cli);
    final dependency = cli.positional('dependency')!;

    if (!tessera.dependencies.remove(dependency)) {
      throw CliException('Dependency $dependency not found');
    }

    await tessera.save(ctx);
    print(
      '✓ '.green +
          'Removed dependency '.dim +
          dependency.red +
          ' from '.dim +
          tessera.name.cyan,
    );
  }

  Future<Tessera> _prepareDeps(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('tessera')!;
    final dependency = cli.positional('dependency')!;

    if (!await ctx.env.exists(name)) {
      throw CliException('Tessera $name not found');
    }

    if (!await ctx.env.exists(dependency)) {
      throw CliException('Dependency $dependency does not exist');
    }

    final tessera = await ctx.getTesseraFromName(name);
    if (tessera == null) {
      throw CliException('Failed to load tessera $name');
    }

    return tessera;
  }
}
