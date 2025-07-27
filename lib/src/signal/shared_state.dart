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
import 'signal.dart';

class CounterSignal extends Signal<int> {
  CounterSignal(super._state);

  void increment() => state++;
  void decrement() => state--;
  void reset() => state = 0;
}

final counter = CounterSignal(10);

class Prova extends StatefulWidget {
  const Prova({super.key});

  @override
  State<Prova> createState() => _ProvaState();
}

mixin SharedState<T extends StatefulWidget> on State<T> {
  List<Signal> signals = [];

  @override
  void initState() {
    super.initState();
    for (final state in signals) {
      state.watch(_refresh);
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final state in signals) {
      state.unwatch();
    }
  }

  void _refresh<R>(R param) {
    if (mounted) setState(() {});
  }

  void watch<R>(Signal<R> provider) => provider.watch(_refresh);
  void unwatch<R>(Signal<R> provider) => provider.unwatch();
}

final fetched = AsyncSignal(() {
  return Future.value(10);
});

class _ProvaState extends State<Prova> with SharedState {
  @override
  List<Signal> get signals => [fetched, counter];

  @override
  Widget build(BuildContext context) {
    return fetched.when((status) {
      fetched.fetch();
      if (status.loading) return Text("Loading...");
      if (status.isError) return Text("An error occured");
      return Text(status.data.toString());
    });
  }
}
