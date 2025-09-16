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
import '../utils/utils.dart';

class ProfileService {
  Future<void> switchTo(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    final name = cli.positional('name');

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

  Future<void> run(ArgvResult cli) => _exec(cli, (p) => p.run);
  Future<void> build(ArgvResult cli) => _exec(cli, (p) => p.build);
  Future<void> exec(ArgvResult cli) async {
    return _exec(cli, (p) => p.commands[cli.positional('command')]);
  }

  Future<void> _exec(ArgvResult cli, String? Function(Profile) command) async {
    final ctx = cli.get<Context>();
    final profile = await validateProfile(cli);

    final cmd = command(profile);

    if (cmd == null) {
      throw CliException('Command not found in profile ${profile.name}.');
    }

    final main = await ctx.main();

    final args = utils.parseCommand(cmd);
    final code = await utils.cmd(args, path: main.path, out: true);

    if (code != 0) {
      throw const CliException('Something went wrong');
    }
  }

  Future<Profile> validateProfile(ArgvResult cli) async {
    final ctx = cli.get<Context>();

    String? profileName = cli.positional('profile');

    profileName ??= ctx.config.get('profile');

    if (profileName == null) throw const CliException('Invalid profile name');

    final profiles = ctx.config.get('profiles');
    if (profiles is! Map) {
      throw const CliException('Corruptect configuration file');
    }

    final profile = Profile.parse(MapEntry(profileName, profiles[profileName]));
    return profile;
  }

  String getProfileName(ArgvResult cli) {
    return cli.positional('profile') ??
        cli.get<Context>().config.get('profile')!;
  }

  Future<void> addTessera(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final profile = await validateProfile(cli);

    final tessera = cli.positional('tessera')!;

    final profiles = ctx.config.get('profiles');

    if (profile.tesserae.contains(tessera)) {
      throw CliException(
        'Tessera $tessera already present in ${profile.name} profile.',
      );
    }

    profile.tesserae.add(tessera);

    profiles[profile.name] = profile.encode();

    ctx.config.set('profiles', profiles);

    await ctx.config.save();
  }

  Future<void> removeTessera(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final profile = await validateProfile(cli);

    final tessera = cli.positional('tessera')!;

    if (!profile.tesserae.contains(tessera)) {
      throw CliException(
        'Tessera $tessera not found in ${profile.name} profile.',
      );
    }

    profile.tesserae.remove(tessera);

    if (tessera == profile.defaultTessera) {
      throw const CliException('The default tessera cannot be removed');
    }

    if (profile.tesserae.isEmpty) {
      throw const CliException(
        'The profile must contains at least one tessera',
      );
    }

    await ctx.saveProfile(profile);
  }

  Future<void> setDefault(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final profile = await validateProfile(cli);

    profile.defaultTessera = cli.positional('tessera')!;

    await ctx.saveProfile(profile);
  }

  Future<void> sync(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final tesserae = await ctx.tesserae();

    final profile = await validateProfile(cli);

    tesserae.removeWhere((t) => !profile.tesserae.contains(t.name));

    await ctx.writeInitializationFile(
      tesserae.toList(),
      profile.defaultTessera,
    );
  }
}
