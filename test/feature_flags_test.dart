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

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  group('FeatureFlags', () {
    late FeatureFlags flags;

    setUp(() => flags = FeatureFlags());

    test('returns the default value when no override exists', () {
      expect(flags.isEnabled('missing'), isFalse);
      expect(FeatureFlags(defaultValue: true).isEnabled('missing'), isTrue);
    });

    test('enable/disable/set update the override', () {
      flags.enable('a');
      expect(flags.isEnabled('a'), isTrue);

      flags.disable('a');
      expect(flags.isEnabled('a'), isFalse);

      flags.set('a', true);
      expect(flags.isEnabled('a'), isTrue);
    });

    test('remove restores the default value', () {
      flags.enable('a');
      flags.remove('a');
      expect(flags.isEnabled('a'), isFalse);
    });

    test('resolve consults resolvers when no override is set', () async {
      flags.addResolver((key) async => key == 'remote');
      expect(await flags.resolve('remote'), isTrue);
      expect(await flags.resolve('other'), isFalse);
    });

    test('local overrides take precedence over resolvers', () async {
      flags.addResolver((key) async => true);
      flags.disable('x');
      expect(await flags.resolve('x'), isFalse);
    });

    test('a resolver returning null is skipped', () async {
      flags.addResolver((key) async => null);
      flags.addResolver((key) async => true);
      expect(await flags.resolve('x'), isTrue);
    });

    test('a throwing resolver does not break resolution', () async {
      flags.addResolver((key) => throw StateError('boom'));
      flags.addResolver((key) async => true);
      expect(await flags.resolve('x'), isTrue);
    });

    test('gate builds a ModuleGate backed by the flag', () async {
      final ModuleGate gate = flags.gate('feature');
      expect(await gate(), isFalse);
      flags.enable('feature');
      expect(await gate(), isTrue);
    });
  });
}
