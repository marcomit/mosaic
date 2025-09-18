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
import '../utils/gesso.dart';
import '../context.dart';
import '../utils/utils.dart';

extension on String {
  String capitalize() {
    return this[0].toUpperCase() + substring(1);
  }
}

class _Layer {
  _Layer(this.val, this.children);

  String val;
  List<_Layer> children;

  bool get isLeaf {
    if (children.isEmpty) return true;
    for (final child in children) {
      if (!child.isWildCard) return false;
    }
    return true;
  }

  bool get isWildCard => {'*', '#'}.contains(val);

  bool get containsOnlyLeaf {
    for (final child in children) {
      if (!child.isLeaf) return false;
    }
    return true;
  }

  String get className => '${val.capitalize()}Node';

  void extend(Map<String, dynamic> json, [int depth = 0]) {
    for (final key in json.keys) {
      final layer = _Layer(key, []);
      children.add(layer);
      layer.extend(json[key], depth + 1);
    }
  }

  String? prop([_Layer? parent]) {
    if (isWildCard) return null;
    String param = 'super.topic';
    if (!isLeaf) param = '\'$val\'';
    return '$className get $val => $className($param);';
  }

  @override
  String toString([_Layer? parent]) {
    final props = [];

    final Set<String> mixins = {};

    for (final child in children) {
      final property = child.prop(parent);

      if (property != null) props.add(property);
      if (child.val == '*') {
        mixins.add('Id');
      } else if (child.val == '#') {
        mixins.add('Param');
      }
    }

    String nodeMixin = '';

    if (mixins.isNotEmpty) {
      nodeMixin = ' with ${mixins.join(', ')}';
    }

    final String superParam =
        '''(super.topic) {
    \$('$val');
  }''';

    final classes = [
      '''
class $className extends Segment$nodeMixin {
  ${props.join('\n  ')}
  $className$superParam
}
      ''',
    ];

    for (final child in children) {
      if (child.isWildCard) continue;
      classes.add(child.toString(this));
    }
    return classes.reversed.join('\n\n');
  }
}

class EventService {
  Future<void> generate(ArgvResult cli) async {
    final ctx = cli.get<Context>();
    final root = await ctx.env.root();
    final events = ctx.config.get('events') ?? <String, dynamic>{};
    final name = ctx.config.get('name');
    final path = utils.join([root.path, name, 'lib', 'events.dart']);

    print('Generating event tree...'.dim);
    await _saveFile(path, events);
    print('✓ '.green + 'Events generated at '.dim + 'lib/events.dart'.cyan);
  }

  Future<String> _generate(Map<String, dynamic> json) async {
    final layer = _Layer('', []);
    layer.extend(json);

    final content = layer.children.map((c) => c.toString()).join('\n\n');
    final headProps = layer.children.map((child) {
      return '${child.className} get ${child.val} => ${child.className}();';
    });

    return '''
import 'package:mosaic/mosaic.dart';

${Context.banner}

$content

mixin HeadNode {
 ${headProps.join('\n  ')}
}
''';
  }

  Future<void> _saveFile(String path, Map<String, dynamic> json) async {
    final file = await utils.ensureExists(path);
    final content = await _generate(json);
    await file.writeAsString(content);
  }
}
