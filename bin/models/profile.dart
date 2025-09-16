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

import '../utils/gesso.dart';
import '../exception.dart';

class Profile {
  Profile({
    required this.name,
    required this.defaultTessera,
    this.tesserae = const [],
    this.commands = const {},
    this.run,
    this.build,
  });

  final String name;
  String defaultTessera;
  final List<String> tesserae;
  final Map<String, String> commands;
  final String? run;
  final String? build;
  static Profile parse(MapEntry entry) {
    final MapEntry(:key, :value) = entry;
    if (value is! Map) {
      throw CliException('$key is not a valid profile');
    }

    final requiredFields = {
      'default': (dynamic v) => v is String,
      'tesserae': (dynamic v) => v is List,
      'commands': (dynamic v) => v == null || v is Map,
      'run': (dynamic v) => v == null || v is String,
      'build': (dynamic v) => v == null || v is String,
    };

    for (final requiredEntry in requiredFields.entries) {
      // if (!value.containsKey(requiredEntry.key)) {
      //   throw CliException(
      //     'Profile $key: missing field \'${requiredEntry.key}\'',
      //   );
      // }
      if (!requiredEntry.value(value[requiredEntry.key])) {
        throw CliException(
          'Profile $key: invalid type for field \'${requiredEntry.key}\'',
        );
      }
    }

    final commands = <String, String>{};

    if (value['commands'] != null) {
      for (final MapEntry(:key, :value) in (value['commands'] as Map).entries) {
        if (value is! String) {
          throw CliException('Profile $key: command \'$key\' must be a string');
        }
        commands[key.toString()] = value;
      }
    }

    return Profile(
      name: key.toString(),
      defaultTessera: value['default'],
      tesserae: (value['tesserae'] as List).cast<String>(),
      commands: commands,
      run: value['run'],
      build: value['build'],
    );
  }

  void show(bool isDefault) {
    final buf = StringBuffer();
    String prefix = '○'.brightBlack;
    String name = this.name.white;

    if (isDefault) {
      prefix = '●'.brightGreen;
      name = this.name.bold.brightGreen;
    }

    buf.writeln('  $prefix $name'.padRight(20) + '($defaultTessera)'.dim);
    buf.writeln(
      '    ├─ ${tesserae.length} tesserae: '.dim +
          tesserae.take(3).join(', ').cyan +
          (tesserae.length > 3 ? '...' : ''),
    );

    if (commands.isNotEmpty) {
      buf.writeln(
        '    └─ ${commands.length} commands: '.dim +
            commands.keys.take(2).join(', ').yellow +
            (commands.length > 2 ? '...' : ''),
      );
    }

    print(buf.toString());
  }

  Map<String, dynamic> encode() {
    return {
      'default': defaultTessera,
      'tesserae': tesserae,
      'commands': commands,
    };
  }
}
