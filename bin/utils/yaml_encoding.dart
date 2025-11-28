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

class YamlEncoding {
  static const _spacesPerNestingLevel = 2;
  String serialize(dynamic json) => _condense(
    _formatObject(value: json, context: const _Context(nesting: 0)),
  );

  Map<String, dynamic> deserialize(String yaml) {
    // final lines = yaml.split('\n');
    final res = <String, dynamic>{};

    return res;
  }

  String _formatObject({required dynamic value, required _Context context}) {
    if (value is Map) {
      return _formatStructure(
        structure: value as Map<String, dynamic>,
        context: context,
      );
    } else if (value is Iterable) {
      return _formatCollection(collection: value, context: context);
    } else if (value is String) {
      return _isMultilineString(value)
          ? _formatMultilineString(value, context)
          : _formatSingleLineString(value);
    } else if (value == null) {
      return '';
    } else {
      return '$value';
    }
  }

  String _formatStructure({
    required Map<String, dynamic> structure,
    required _Context context,
  }) {
    String separator(MapEntry<String, dynamic> e) =>
        e.value is Map ? '\n${_indentation(context.nest())}' : ' ';

    if (structure.isEmpty) {
      return '';
    }
    final entries = structure.entries;
    final firstElement = entries.first;
    final first =
        '${_formatSingleLineString(firstElement.key)}:${separator(firstElement)}${_formatObject(value: firstElement.value, context: context.nest())}\n';
    final rest = entries
        .skip(1)
        .map(
          (e) =>
              '${_indentation(context)}${e.key}:${separator(e)}'
              '${_formatObject(value: e.value, context: context.nest())}',
        )
        .join('\n');
    return '$first$rest';
  }

  String _formatCollection({
    required Iterable<dynamic> collection,
    required _Context context,
  }) {
    if (collection.isEmpty) {
      return '';
    }
    return '\n${collection.map((dynamic e) => '${_indentation(context)}- '
        '${_formatObject(value: e, context: context.nest())}').join('\n')}\n';
  }

  String _condense(String yaml) => _endWithEol(
    yaml
        .split('\n')
        .map((s) => s.trimRight())
        .where((s) => s.isNotEmpty)
        .join('\n'),
  );

  String _endWithEol(String s) => '$s\n';

  String _indentation(_Context ctx) =>
      ''.padLeft(ctx.nesting * _spacesPerNestingLevel);

  bool _isMultilineString(String value) => value.trim().contains('\n');

  String _formatMultilineString(String value, _Context ctx) =>
      '|${_chompModifier(value)}\n'
      '${_indentMultilineString(value, _indentation(ctx))}';

  String _chompModifier(String value) => value.endsWith('\n') ? '' : '-';

  String _indentMultilineString(String value, String indentation) =>
      value.split('\n').map((s) => '$indentation$s').join('\n');

  String _formatSingleLineString(String value) =>
      _requiresQuotes(value) ? '\'$value\'' : value;

  bool _requiresQuotes(String s) =>
      _isNumeric(s) || _isBoolean(s) || _containsSpecialCharacters(s);

  bool _isNumeric(String s) => s.isNotEmpty && num.tryParse(s) != null;

  bool _isBoolean(String s) => _booleanValues.contains(s);

  bool _containsSpecialCharacters(String s) =>
      _specialCharacters.any((c) => s.contains(c));

  static const _specialCharacters = {
    ': ',
    '[',
    ']',
    '{',
    '}',
    '>',
    '!',
    '*',
    '&',
    '|',
    '%',
    ' #',
    '`',
    '@',
    ',',
    '?',
  };

  static const _booleanValues = {'${true}', '${false}'};
}

class _Context {
  const _Context({required this.nesting});

  final int nesting;

  _Context nest() => _Context(nesting: nesting + 1);
}
