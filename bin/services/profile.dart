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

import 'package:argv/argv.dart';
import '../context.dart';
import '../exception.dart';
import '../utils/gesso.dart';
import '../models/profile.dart';

class ProfileService {
  Future<void> set(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    final name = cli.positional('name');

    final profiles = ctx.config.get('profiles');

    if (profiles is! Map) {
      throw const CliException('mosaic.yaml isn\'t a valid value');
    }

    if (!profiles.containsKey(name)) {
      throw CliException('$name is not a valid profile');
    }

    ctx.config.set('profile', name);

    await ctx.config.save();
  }

  Future<void> show(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final name = cli.positional('name')!;
    final profiles = ctx.config.get('profiles') as Map?;

    if (profiles == null || !profiles.containsKey(name)) {
      print('✗ '.red + 'Profile '.dim + name.red + ' not found'.dim);
      return;
    }

    final defaultProfile = ctx.config.get('default_profile');
    final profile = Profile.parse(MapEntry(name, profiles[name]));
    profile.show(defaultProfile == name);
  }

  Future<void> list(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final profiles = ctx.config.get('profiles');

    if (profiles is! Map || profiles.isEmpty) {
      print('No profiles found'.dim.italic);
      print('Create one with: '.dim + 'mosaic profile add <name>'.cyan);
      return;
    }

    final defaultProfile = ctx.config.get('profile');
    print('Available Profiles'.bold.cyan);
    print('');

    for (final entry in profiles.entries) {
      final profile = Profile.parse(entry);
      profile.show(defaultProfile == profile.name.toString());
    }

    if (defaultProfile != null) {
      print('  ● = Default profile'.dim.italic);
    }
  }

  Future<void> exec(ArgvResult cli) async {}
}
