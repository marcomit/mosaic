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

/// Extension on [String] to provide convenient styling methods
///
/// This extension allows you to apply Gesso styling directly to strings
/// without creating a Gesso instance first.
///
/// Example:
/// ```dart
/// print('Error message'.red.bold);
/// print('Success!'.green.underline);
/// ```
extension GessoExtension on String {
  /// Wraps the string with ANSI escape codes
  ///
  /// [codes] - List of ANSI codes to apply
  /// Returns the styled string with proper reset sequence
  String wrap(List<int> codes) {
    if (codes.isEmpty) return this;
    final escape = codes.join(';');
    return "\x1B[${escape}m$this\x1B[0m";
  }

  /// Private helper method to apply a single style
  String _style(GessoStyle style) => wrap([style.value]);

  /// Private helper method to apply a foreground color
  String _foreground(GessoColor color, [bool bright = false]) {
    int code = color.value + 30;
    if (bright) code += 60;
    return wrap([code]);
  }

  /// Private helper method to apply a background color
  String _background(GessoColor color, [bool bright = false]) {
    int code = color.value + 40;
    if (bright) code += 60;
    return wrap([code]);
  }

  // Text styling methods

  /// Applies bold styling to the string
  String get bold => _style(GessoStyle.bold);

  /// Applies dim/faint styling to the string
  String get dim => _style(GessoStyle.dim);

  /// Applies italic styling to the string
  String get italic => _style(GessoStyle.italic);

  /// Applies underline styling to the string
  String get underline => _style(GessoStyle.underline);

  /// Applies slow blink styling to the string
  String get blink => _style(GessoStyle.blink);

  /// Applies rapid blink styling to the string
  String get blinkRapid => _style(GessoStyle.blinkRapid);

  /// Applies reversed (inverted) styling to the string
  String get reversed => _style(GessoStyle.reversed);

  /// Applies hidden/invisible styling to the string
  String get hidden => _style(GessoStyle.hidden);

  /// Applies strikethrough styling to the string
  String get strikethrough => _style(GessoStyle.strikethrough);

  // Standard foreground colors

  /// Applies black foreground color to the string
  String get black => _foreground(GessoColor.black);

  /// Applies red foreground color to the string
  String get red => _foreground(GessoColor.red);

  /// Applies green foreground color to the string
  String get green => _foreground(GessoColor.green);

  /// Applies yellow foreground color to the string
  String get yellow => _foreground(GessoColor.yellow);

  /// Applies blue foreground color to the string
  String get blue => _foreground(GessoColor.blue);

  /// Applies magenta foreground color to the string
  String get magenta => _foreground(GessoColor.magenta);

  /// Applies cyan foreground color to the string
  String get cyan => _foreground(GessoColor.cyan);

  /// Applies white foreground color to the string
  String get white => _foreground(GessoColor.white);

  // Bright foreground colors

  /// Applies bright black (gray) foreground color to the string
  String get brightBlack => _foreground(GessoColor.black, true);

  /// Applies bright red foreground color to the string
  String get brightRed => _foreground(GessoColor.red, true);

  /// Applies bright green foreground color to the string
  String get brightGreen => _foreground(GessoColor.green, true);

  /// Applies bright yellow foreground color to the string
  String get brightYellow => _foreground(GessoColor.yellow, true);

  /// Applies bright blue foreground color to the string
  String get brightBlue => _foreground(GessoColor.blue, true);

  /// Applies bright magenta foreground color to the string
  String get brightMagenta => _foreground(GessoColor.magenta, true);

  /// Applies bright cyan foreground color to the string
  String get brightCyan => _foreground(GessoColor.cyan, true);

  /// Applies bright white foreground color to the string
  String get brightWhite => _foreground(GessoColor.white, true);

  // Background color methods

  /// Applies black background color to the string
  String get onBlack => _background(GessoColor.black);

  /// Applies red background color to the string
  String get onRed => _background(GessoColor.red);

  /// Applies green background color to the string
  String get onGreen => _background(GessoColor.green);

  /// Applies yellow background color to the string
  String get onYellow => _background(GessoColor.yellow);

  /// Applies blue background color to the string
  String get onBlue => _background(GessoColor.blue);

  /// Applies magenta background color to the string
  String get onMagenta => _background(GessoColor.magenta);

  /// Applies cyan background color to the string
  String get onCyan => _background(GessoColor.cyan);

  /// Applies white background color to the string
  String get onWhite => _background(GessoColor.white);

  // Bright background color methods

  /// Applies bright black background color to the string
  String get onBrightBlack => _background(GessoColor.black, true);

  /// Applies bright red background color to the string
  String get onBrightRed => _background(GessoColor.red, true);

  /// Applies bright green background color to the string
  String get onBrightGreen => _background(GessoColor.green, true);

  /// Applies bright yellow background color to the string
  String get onBrightYellow => _background(GessoColor.yellow, true);

  /// Applies bright blue background color to the string
  String get onBrightBlue => _background(GessoColor.blue, true);

  /// Applies bright magenta background color to the string
  String get onBrightMagenta => _background(GessoColor.magenta, true);

  /// Applies bright cyan background color to the string
  String get onBrightCyan => _background(GessoColor.cyan, true);

  /// Applies bright white background color to the string
  String get onBrightWhite => _background(GessoColor.white, true);

  // Advanced styling methods

  /// Applies a specific foreground color to the string
  ///
  /// [color] - The foreground color to apply
  /// [bright] - Whether to use the bright variant (default: false)
  /// Returns the string with the specified foreground color
  String foreground(GessoColor color, [bool bright = false]) {
    return _foreground(color, bright);
  }

  /// Applies a specific background color to the string
  ///
  /// [color] - The background color to apply
  /// [bright] - Whether to use the bright variant (default: false)
  /// Returns the string with the specified background color
  String background(GessoColor color, [bool bright = false]) {
    return _background(color, bright);
  }

  /// Applies a specific style to the string
  ///
  /// [style] - The style to apply
  /// Returns the string with the specified style
  String style(GessoStyle style) {
    return _style(style);
  }

  /// Applies multiple ANSI codes to the string
  ///
  /// [codes] - List of ANSI codes to apply
  /// Returns the string with the specified codes applied
  String codes(List<int> codes) {
    return wrap(codes);
  }

  /// Applies a custom ANSI code to the string
  ///
  /// [code] - The ANSI code to apply (must be between 0 and 255)
  /// Returns the string with the specified code applied
  /// Throws [ArgumentError] if the code is outside the valid range
  String code(int code) {
    if (code < 0 || code > 255) {
      throw ArgumentError('ANSI code must be between 0 and 255, got: $code');
    }
    return wrap([code]);
  }

  /// Removes all ANSI escape sequences from the string
  ///
  /// This method strips all ANSI escape codes, returning plain text.
  /// Useful for measuring actual string length or saving to files.
  ///
  /// Returns the string with all ANSI escape sequences removed
  String get stripAnsi {
    // Regular expression to match ANSI escape sequences
    final ansiRegex = RegExp(r'\x1B\[[0-9;]*[mGKH]');
    return replaceAll(ansiRegex, '');
  }

  /// Gets the visible length of the string (excluding ANSI codes)
  ///
  /// This is useful for alignment and formatting when ANSI codes
  /// are present, as they don't contribute to the visible width.
  ///
  /// Returns the length of the string after removing ANSI codes
  int get visibleLength => stripAnsi.length;
}

/// Main class for creating styled terminal output.
///
/// Provides a chainable API for combining multiple styles and colors.
/// Each method returns a new [Gesso] instance, allowing for fluent composition.
///
/// Example:
/// ```dart
/// final g = Gesso();
/// print(g.red.bold.underline('Error: Critical failure!'));
/// ```
class Gesso {
  /// List of ANSI codes that define the current styling
  final List<int> _codes;

  /// Creates a new [Gesso] instance with no styling applied
  Gesso() : _codes = <int>[];

  /// Creates a new [Gesso] instance from an existing list of ANSI codes
  Gesso.from(List<int> codes) : _codes = List<int>.from(codes);

  /// Internal constructor for creating instances with specific codes
  Gesso._internal(this._codes);

  /// Generates the ANSI escape sequence for the current styles
  String get _escapeSequence => _codes.join(';');

  /// Adds a custom ANSI code to the current styling
  ///
  /// [code] - The ANSI code to add
  /// Returns a new [Gesso] instance with the added code
  Gesso and(int code) {
    if (code < 0 || code > 255) {
      throw ArgumentError('ANSI code must be between 0 and 255, got: $code');
    }
    return Gesso._internal([..._codes, code]);
  }

  /// Adds a [GessoStyle] to the current styling
  ///
  /// [style] - The style to add
  /// Returns a new [Gesso] instance with the added style
  Gesso add(GessoStyle style) => and(style.value);

  // Text styling methods

  /// Applies bold styling
  Gesso get bold => add(GessoStyle.bold);

  /// Applies dim/faint styling
  Gesso get dim => add(GessoStyle.dim);

  /// Applies italic styling
  Gesso get italic => add(GessoStyle.italic);

  /// Applies underline styling
  Gesso get underline => add(GessoStyle.underline);

  /// Applies slow blink styling
  Gesso get blink => add(GessoStyle.blink);

  /// Applies rapid blink styling
  Gesso get blinkRapid => add(GessoStyle.blinkRapid);

  /// Applies reversed (inverted) styling
  Gesso get reversed => add(GessoStyle.reversed);

  /// Applies hidden/invisible styling
  Gesso get hidden => add(GessoStyle.hidden);

  /// Applies strikethrough styling
  Gesso get strikethrough => add(GessoStyle.strikethrough);

  // Standard foreground colors

  /// Applies black foreground color
  Gesso get black => foreground(GessoColor.black);

  /// Applies red foreground color
  Gesso get red => foreground(GessoColor.red);

  /// Applies green foreground color
  Gesso get green => foreground(GessoColor.green);

  /// Applies yellow foreground color
  Gesso get yellow => foreground(GessoColor.yellow);

  /// Applies blue foreground color
  Gesso get blue => foreground(GessoColor.blue);

  /// Applies magenta foreground color
  Gesso get magenta => foreground(GessoColor.magenta);

  /// Applies cyan foreground color
  Gesso get cyan => foreground(GessoColor.cyan);

  /// Applies white foreground color
  Gesso get white => foreground(GessoColor.white);

  // Bright foreground colors

  /// Applies bright black (gray) foreground color
  Gesso get brightBlack => foreground(GessoColor.black, true);

  /// Applies bright red foreground color
  Gesso get brightRed => foreground(GessoColor.red, true);

  /// Applies bright green foreground color
  Gesso get brightGreen => foreground(GessoColor.green, true);

  /// Applies bright yellow foreground color
  Gesso get brightYellow => foreground(GessoColor.yellow, true);

  /// Applies bright blue foreground color
  Gesso get brightBlue => foreground(GessoColor.blue, true);

  /// Applies bright magenta foreground color
  Gesso get brightMagenta => foreground(GessoColor.magenta, true);

  /// Applies bright cyan foreground color
  Gesso get brightCyan => foreground(GessoColor.cyan, true);

  /// Applies bright white foreground color
  Gesso get brightWhite => foreground(GessoColor.white, true);

  /// Sets the background color
  ///
  /// [color] - The background color to apply
  /// [bright] - Whether to use the bright variant (default: false)
  /// Returns a new [Gesso] instance with the background color applied
  Gesso background(GessoColor color, [bool bright = false]) {
    int code = color.value + 40;
    if (bright) code += 60;
    return and(code);
  }

  /// Sets the foreground (text) color
  ///
  /// [color] - The foreground color to apply
  /// [bright] - Whether to use the bright variant (default: false)
  /// Returns a new [Gesso] instance with the foreground color applied
  Gesso foreground(GessoColor color, [bool bright = false]) {
    int code = color.value + 30;
    if (bright) code += 60;
    return and(code);
  }

  /// Applies all accumulated styles to the given text
  ///
  /// [text] - The text to style
  /// Returns the styled text with ANSI escape sequences
  ///
  /// Example:
  /// ```dart
  /// final styled = Gesso().red.bold('Error message');
  /// print(styled); // Prints red, bold text
  /// ```
  String call(String text) {
    if (_codes.isEmpty) return text;
    return '\x1B[${_escapeSequence}m$text\x1B[0m';
  }

  /// Returns a string representation of the current styling codes
  @override
  String toString() => 'Gesso(codes: $_codes)';

  /// Checks equality based on the styling codes
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Gesso) return false;
    return _codes.length == other._codes.length &&
        _codes.every((code) => other._codes.contains(code));
  }

  /// Hash code based on the styling codes
  @override
  int get hashCode => Object.hashAll(_codes);
}

/// Enumeration of available text styling options
///
/// Each style corresponds to a specific ANSI escape code for terminal formatting.
enum GessoStyle {
  /// Bold or increased intensity text
  bold(1),

  /// Dim or faint text
  dim(2),

  /// Italic text (not widely supported)
  italic(3),

  /// Underlined text
  underline(4),

  /// Slowly blinking text (less than 150 blinks per minute)
  blink(5),

  /// Rapidly blinking text (150+ blinks per minute)
  blinkRapid(6),

  /// Reversed colors (foreground and background swapped)
  reversed(7),

  /// Hidden or invisible text
  hidden(8),

  /// Text with strikethrough/crossed-out effect
  strikethrough(9);

  /// Creates a [GessoStyle] with the specified ANSI code value
  const GessoStyle(this.value);

  /// The ANSI escape code value for this style
  final int value;
}

/// Enumeration of available colors for foreground and background styling
///
/// These correspond to the standard 8-color palette supported by most terminals.
/// Each color can also be used in a "bright" variant by adding 60 to the base code.
enum GessoColor {
  /// Black color (ANSI code 0)
  black(0),

  /// Red color (ANSI code 1)
  red(1),

  /// Green color (ANSI code 2)
  green(2),

  /// Yellow color (ANSI code 3)
  yellow(3),

  /// Blue color (ANSI code 4)
  blue(4),

  /// Magenta color (ANSI code 5)
  magenta(5),

  /// Cyan color (ANSI code 6)
  cyan(6),

  /// White color (ANSI code 7)
  white(7);

  /// Creates a [GessoColor] with the specified ANSI code value
  const GessoColor(this.value);

  /// The ANSI escape code value for this color
  final int value;
}
