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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

class _M extends Module {
  _M(String name) : super(name: name);
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('MosaicInspector', () {
    tearDown(() async {
      await mosaic.registry.disposeAll();
      mosaic.reset();
    });

    testWidgets('lists registered modules and their states', (tester) async {
      final module = _M('alpha');
      await mosaic.registry.register(module);
      await module.initialize();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MosaicInspector())),
      );
      await tester.pump();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
    });

    testWidgets('overlay toggles the panel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MosaicInspectorOverlay(
            enabled: true,
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(MosaicInspector), findsNothing);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(MosaicInspector), findsOneWidget);
    });
  });
}
