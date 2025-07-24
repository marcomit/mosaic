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

import 'package:flutter/cupertino.dart';
import 'events.dart';
import 'injector.dart';

/// Type for the builder function type for extensions
typedef ModularExtensionBuilder = Widget Function(BuildContext);

/// Extensions class
class ModularExtension {
  /// The builder that create the [Widget]
  final ModularExtensionBuilder builder;

  /// It is used to sort based on the priority
  final int priority;

  /// Extensions can be categorized
  final String? category;

  ModularExtension(this.builder, {this.priority = 0, this.category});

  /// Static method used to sort extensions
  static int _compare(ModularExtension a, ModularExtension b) {
    return a.priority - b.priority;
  }
}

/// Stateful Modular extension should have the
abstract class ModularStatefulWidget extends StatefulWidget {
  /// Path is a list of string to permit having nested extensions.
  /// For now you should pass the parent path into the child.
  final List<String> path;
  const ModularStatefulWidget({super.key, required this.path});

  @override
  ModularState<ModularStatefulWidget> createState();
}

abstract class ModularState<T extends ModularStatefulWidget> extends State<T> {
  /// Identifier of the Modular view
  final String id;

  // Attribute to get the base topic
  List<String> get _baseTopic => [...widget.path, id];

  /// Get the string for listening events
  String _topic(String action) {
    return [..._baseTopic, action].join(Events.sep);
  }

  /// Constructor (only need to define a static string [id])
  ModularState(this.id);

  /// List of extensions
  final List<ModularExtension> extensions = [];

  /// Object that represent the EventListener.
  /// It should be initialized in the [initState]
  /// and removed in the [dispose]
  late UIInjectorListener _extensionListener;

  /// Function that will be executed when the listener receives an event
  void _extensionCallback(EventContext<ModularExtension> ctx) {
    if (ctx.data == null) return;

    extensions.add(ctx.data!);
    extensions.sort(ModularExtension._compare);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    _extensionListener = injector.on(_topic("*"), _extensionCallback);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    events.deafen(_extensionListener);
  }
}
