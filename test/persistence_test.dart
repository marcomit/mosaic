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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

class _CounterModule extends Module with Persistable {
  _CounterModule() : super(name: 'counter');

  final count = Signal<int>(0);

  @override
  Future<void> onInit() async {
    await persistJson<int>(count, key: 'count',
        debounce: const Duration(milliseconds: 10));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('Persistable', () {
    late InMemoryStorage storage;

    setUp(() {
      storage = InMemoryStorage();
      mosaic.override<MosaicStorage>(storage);
    });

    tearDown(() async {
      await mosaic.registry.disposeAll();
      mosaic.reset();
    });

    test('writes signal changes to storage (debounced)', () async {
      final module = _CounterModule();
      await mosaic.registry.register(module);
      await module.initialize();

      module.count.state = 42;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(storage.entries['mosaic/counter/count'], '42');
    });

    test('rehydrates the signal from storage on init', () async {
      await storage.write('mosaic/counter/count', '7');

      final module = _CounterModule();
      await mosaic.registry.register(module);
      await module.initialize();

      expect(module.count.state, 7);
    });

    test('stops writing after dispose', () async {
      final module = _CounterModule();
      await mosaic.registry.register(module);
      await module.initialize();
      await module.dispose();

      module.count.state = 99;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(storage.entries.containsKey('mosaic/counter/count'), isFalse);
    });
  });
}
