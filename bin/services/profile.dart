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

  Future<void> list(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final profiles = ctx.config.get('profiles') as Map?;

    if (profiles == null || profiles.isEmpty) {
      print('No profiles found'.dim.italic);
      print('Create one with: '.dim + 'mosaic profile add <name>'.cyan);
      return;
    }

    final defaultProfile = ctx.config.get('profile');
    print('Available Profiles'.bold.cyan);
    print('');

    for (final entry in profiles.entries) {
      final profile = _validateProfile(entry);
      _showProfile(entry.key.toString(), profile, defaultProfile);
    }

    if (defaultProfile != null) {
      print('  ● = Default profile'.dim.italic);
    }
  }

  void _showProfile(String entryName, Map profile, String defaultProfile) {
    final isDefault = entryName == defaultProfile;

    String prefix = '○'.brightBlack;
    String name = entryName.white;

    if (isDefault) {
      prefix = '●'.brightGreen;
      name = entryName.bold.brightGreen;
    }

    final tesserae = profile['tesserae'] as List;
    final defaultTessera = profile['default'];
    final commands = profile['commands'] as Map?;

    print('  $prefix $name'.padRight(20) + '($defaultTessera)'.dim);
    print(
      '    ├─ ${tesserae.length} tesserae: '.dim +
          tesserae.take(3).join(', ').cyan +
          (tesserae.length > 3 ? '...' : ''),
    );

    if (commands?.isNotEmpty == true) {
      print(
        '    └─ ${commands!.length} commands: '.dim +
            commands.keys.take(2).join(', ').yellow +
            (commands.length > 2 ? '...' : ''),
      );
    }
    print('');
  }

  Map _validateProfile(MapEntry entry) {
    final MapEntry(:key, :value) = entry;

    if (value is! Map) {
      throw CliException('$key is not a valid profile');
    }

    if (!value.containsKey('default')) {
      throw CliException('Missing \'name\' field inside $key profile');
    }
    if (!value.containsKey('tesserae')) {
      throw CliException('Missing \'tesserae\' field inside $key profile');
    }

    if (value['default'] is! String) {
      throw CliException(
        'Profile: $key field \'name\' must be a string, found ${value['default']}',
      );
    }
    return value;
  }

  Future<Map<dynamic, dynamic>> _getProfile() async {}

  Future<void> exec(ArgvResult cli) async {}
}
