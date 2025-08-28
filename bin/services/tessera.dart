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

  Future<void> depsRemove(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('tessera');
    final dependency = cli.positional('dependency');

    final tessera = await prepareDeps(cli);

    if (!tessera.dependencies.remove(dependency)) {
      throw CliException('Dependency $dependency not found in $name tessera');
    }

    await tessera.save(ctx);
  }

  Future<void> depsAdd(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final dependency = cli.positional('dependency')!;

    final tessera = await prepareDeps(cli);

    if (tessera.dependencies.contains(dependency)) {
      throw CliException('Dependency $dependency already exists');
    }
    tessera.dependencies.add(dependency);

    await tessera.save(ctx);
  }

  Future<Tessera> prepareDeps(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('tessera')!;
    final dependency = cli.positional('dependency')!;

    if (!await ctx.env.exists(name)) {
      throw CliException('$name does not exist in this mosaic');
    }

    if (!await ctx.env.exists(dependency)) {
      throw CliException(
        '$dependency is not a valid dependency because it does not exists',
      );
    }

    final tessera = await ctx.getTesseraFromName(name);
    if (tessera == null) {
      throw CliException('Tessera $name not found');
    }
    return tessera;
  }
}
