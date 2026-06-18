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

class _ScreenModule extends Module {
  _ScreenModule(String name) : super(name: name);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(name)));
}

void main() {
  group('MosaicRouterDelegate', () {
    tearDown(mosaic.reset);

    Future<void> pumpApp(WidgetTester tester) async {
      final home = _ScreenModule('home');
      final second = _ScreenModule('second');
      await mosaic.registry.register(home);
      await mosaic.registry.register(second);
      await mosaic.registry.initialize(home, [home, second]);

      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: MosaicRouterDelegate(),
          routeInformationParser: MosaicRouteInformationParser(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the default module', (tester) async {
      await pumpApp(tester);
      expect(find.text('home'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    });

    testWidgets('go() pushes a module page', (tester) async {
      await pumpApp(tester);
      await mosaic.router.go('second');
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('goBack() returns to the previous module', (tester) async {
      await pumpApp(tester);
      await mosaic.router.go('second');
      await tester.pumpAndSettle();
      mosaic.router.goBack();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    test('parser maps URLs to route state and back', () async {
      final parser = MosaicRouteInformationParser();
      final state = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/profile')),
      );
      expect(state.module, 'profile');

      final info = parser.restoreRouteInformation(
        const MosaicRouteState('profile'),
      );
      expect(info!.uri.path, '/profile');
    });
  });
}
