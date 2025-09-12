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

import '../utils/gesso.dart';
import '../enviroment.dart';
import '../exception.dart';
import '../utils/utils.dart';
import '../context.dart';

class DependencyResolver {
  Future<void> tidy(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    final root = await ctx.env.root();
    final localPackages = await ctx.env.getAllPackages(root!.path);

    await ctx.env.walk((dir) async {
      if (!ctx.env.isValidPackage(path: dir.path)) return true;

      await _processPackage(cli, dir, localPackages);
      return false;
    });
  }

  Future<void> _processPackage(
    ArgvResult cli,
    Directory dir,
    Map<String, String> localPackages,
  ) async {
    final ctx = cli.get<Context>();

    final name = utils.last(dir.path);
    print(name.cyan.bold);

    try {
      final packages = await getLocalPackages(ctx, dir, localPackages);
      print(localPackages);

      if (packages.isEmpty) {
        print('└─ '.dim + '○'.brightBlack + ' No local dependencies'.dim);
        print('');
        return;
      }

      for (final entry in packages.entries) {
        print('├─ '.dim + entry.key + ' → '.dim + entry.value);
      }

      await generateOverridedPackages(cli, dir);
      print('└─ '.dim + '✓'.brightGreen + ' Generated overrides'.brightGreen);
    } catch (e) {
      print('└─ '.dim + '✗'.brightRed + ' Failed: '.red + e.toString().dim);
      // rethrow;
    }
    print('');
  }

  Future<Map<String, String>> getLocalPackages(
    Context ctx,
    Directory path,
    Map<String, String> localPackages,
  ) async {
    if (!ctx.env.isValidPackage(path: path.path)) return {};

    final res = <String, String>{};

    final pubspec = await ctx.config.read(
      utils.join([path.path, Environment.packageMark]),
    );

    if (!pubspec.containsKey('dependencies')) return res;

    final dependencies = pubspec['dependencies'] as Map<String, dynamic>;
    for (final MapEntry(:key) in dependencies.entries) {
      if (!localPackages.containsKey(key)) continue;
      res[key] = localPackages[key]!;
    }

    return res;
  }

  Future<void> generateOverridedPackages(ArgvResult cli, Directory path) async {
    final ctx = cli.get<Context>();
    final root = await ctx.env.root();

    if (root == null) return;

    final localPackages = await ctx.env.getAllPackages();
    final packages = await getLocalPackages(ctx, path, localPackages);

    final toOverride = <String, dynamic>{};

    for (final MapEntry(:key, :value) in packages.entries) {
      final source = utils.join([root.path, value]);
      final newPath = {'path': p.relative(source, from: path.path)};
      print('SRC: $source');
      print('OLD: ${path.path}');
      print('NEW: ${newPath['path']}');
      print('');
      toOverride[key] = newPath;
    }

    final file = await utils.ensureExists(
      utils.join([path.path, 'pubspec_overrides.yaml']),
    );

    await ctx.config.write(file.path, {'dependency_overrides': toOverride});

    final code = await utils.cmd(['flutter', 'pub', 'get'], path: path.path);
    if (code != 0) {
      throw CliException('Failed to get ${path.path}');
    }
  }
}
