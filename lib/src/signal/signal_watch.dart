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
import 'package:mosaic/mosaic.dart';

/// Watches a [Signal] and rebuilds when its value changes.
///
/// This widget automatically subscribes to signal changes and rebuilds
/// the UI when the signal's state is updated.
///
/// *Example:*
/// ```dart
/// Watch<int>(
///   signal: counter,
///   builder: (context, value) => Text('Count: $value'),
/// )
/// ```
///
/// *Note:* Use this widget to rebuild only the necessary widgets,
/// avoiding update expensive widgets.
class Watch<T> extends StatelessWidget {
  const Watch({super.key, required this.signal, required this.child});
  final Signal<T> signal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultipleWatch(signals: [signal], builder: (ctx) => child);
  }
}

class MultipleWatch extends StatefulWidget {
  const MultipleWatch({
    super.key,
    required this.signals,
    required this.builder,
  });
  final List<Signal> signals;
  final Function(BuildContext) builder;

  @override
  State<MultipleWatch> createState() => _MultipleWatchState();
}

class _MultipleWatchState extends State<MultipleWatch> with StatefulSignal {
  @override
  void initState() {
    super.initState();
    widget.signals.forEach(watch);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
