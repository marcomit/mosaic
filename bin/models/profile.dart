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
  });

  final String name;
  String defaultTessera;
  final List<String> tesserae;
  final Map<String, List<String>> commands;

  static Profile parse(MapEntry entry) {
    final MapEntry(:key, :value) = entry;

    if (value is! Map) {
      throw CliException('$key is not a valid profile');
    }

    final requiredFields = {
      'default': String,
      'tesserae': List<String>,
      'commands': Map<String, String>,
    };

    for (final field in requiredFields.entries) {
      if (!value.containsKey(field.key)) {
        throw CliException(
          'Missing \'${field.key}\' field inside $key profile',
        );
      }
      if (value[field.key].runtimeType != field.value) {
        throw CliException(
          'Profile: $key field \'name\' must be a string, found ${value['default']}',
        );
      }
    }

    return Profile(
      name: entry.key.toString(),
      defaultTessera: value['default'],
      tesserae: value['tesserae'],
      commands: value['commands'],
    );
  }

  String buffer(bool isDefault) {
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
    buf.writeln();

    return buf.toString();
  }
}
