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

class _Service {
  _Service(this.id);
  final int id;
}

void main() {
  group('DependencyInjector', () {
    late DependencyInjector di;
    setUp(() => di = DependencyInjector());

    test('put registers a shared singleton', () {
      di.put<_Service>(_Service(1));
      expect(identical(di.get<_Service>(), di.get<_Service>()), isTrue);
    });

    test('factory returns a new instance every time', () {
      var counter = 0;
      di.factory<_Service>(() => _Service(counter++));
      final a = di.get<_Service>();
      final b = di.get<_Service>();
      expect(identical(a, b), isFalse);
      expect(a.id, 0);
      expect(b.id, 1);
    });

    test('lazy builds once on first access then caches', () {
      var built = 0;
      di.lazy<_Service>(() {
        built++;
        return _Service(99);
      });

      expect(built, 0); // not built until accessed
      final first = di.get<_Service>();
      final second = di.get<_Service>();

      expect(built, 1); // built exactly once
      expect(identical(first, second), isTrue);
    });

    test('call operator is equivalent to get', () {
      di.put<_Service>(_Service(7));
      expect(di<_Service>().id, 7);
    });

    test('duplicate registration throws', () {
      di.put<_Service>(_Service(1));
      expect(() => di.put<_Service>(_Service(2)),
          throwsA(isA<DependencyException>()));
      expect(() => di.factory<_Service>(() => _Service(2)),
          throwsA(isA<DependencyException>()));
      expect(() => di.lazy<_Service>(() => _Service(2)),
          throwsA(isA<DependencyException>()));
    });

    test('override replaces an existing registration', () {
      di.put<_Service>(_Service(1));
      di.override<_Service>(_Service(2));
      expect(di.get<_Service>().id, 2);
    });

    test('override clears a prior lazy registration', () {
      var built = 0;
      di.lazy<_Service>(() {
        built++;
        return _Service(1);
      });
      di.override<_Service>(_Service(2));
      expect(di.get<_Service>().id, 2);
      expect(built, 0); // lazy builder must not run after being overridden
    });

    test('get throws when the dependency is missing', () {
      expect(() => di.get<_Service>(), throwsA(isA<DependencyException>()));
    });

    test('contains reflects every registration kind without building', () {
      expect(di.contains<_Service>(), isFalse);
      di.lazy<_Service>(() => _Service(1));
      expect(di.contains<_Service>(), isTrue);
    });

    test('remove unregisters the dependency', () {
      di.put<_Service>(_Service(1));
      di.remove<_Service>();
      expect(di.contains<_Service>(), isFalse);
      expect(() => di.get<_Service>(), throwsA(isA<DependencyException>()));
    });

    test('instances exposes resolved singletons only', () {
      di.put<_Service>(_Service(1));
      di.factory<String>(() => 'x'); // transient: not instantiated
      di.lazy<int>(() => 5); // lazy: not yet resolved

      expect(di.instances.length, 1);
      di.get<int>(); // resolve the lazy singleton
      expect(di.instances.length, 2);
    });

    test('clear removes everything', () {
      di.put<_Service>(_Service(1));
      di.clear();
      expect(di.contains<_Service>(), isFalse);
    });

    group('named bindings', () {
      test('same type can be registered under different names', () {
        di.put<_Service>(_Service(1), name: 'a');
        di.put<_Service>(_Service(2), name: 'b');
        expect(di.get<_Service>(name: 'a').id, 1);
        expect(di.get<_Service>(name: 'b').id, 2);
      });

      test('named and unnamed registrations are independent', () {
        di.put<_Service>(_Service(0));
        di.put<_Service>(_Service(1), name: 'admin');
        expect(di.get<_Service>().id, 0);
        expect(di.get<_Service>(name: 'admin').id, 1);
      });

      test('duplicate name throws', () {
        di.put<_Service>(_Service(1), name: 'a');
        expect(() => di.put<_Service>(_Service(2), name: 'a'),
            throwsA(isA<DependencyException>()));
      });

      test('remove targets the named binding only', () {
        di.put<_Service>(_Service(0));
        di.put<_Service>(_Service(1), name: 'a');
        di.remove<_Service>(name: 'a');
        expect(di.contains<_Service>(name: 'a'), isFalse);
        expect(di.contains<_Service>(), isTrue);
      });
    });

    group('async providers', () {
      test('putAsync resolves once then caches', () async {
        var built = 0;
        di.putAsync<_Service>(() async {
          built++;
          return _Service(5);
        });

        final a = await di.getAsync<_Service>();
        final b = await di.getAsync<_Service>();
        expect(built, 1);
        expect(identical(a, b), isTrue);
      });

      test('resolved async dependency is reachable via sync get', () async {
        di.putAsync<_Service>(() async => _Service(9));
        await di.getAsync<_Service>();
        expect(di.get<_Service>().id, 9);
      });

      test('getAsync throws when unregistered', () {
        expect(di.getAsync<_Service>(), throwsA(isA<DependencyException>()));
      });
    });
  });
}
