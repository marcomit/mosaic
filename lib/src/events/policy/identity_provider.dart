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

import 'dart:collection';
import 'package:mosaic/mosaic.dart';

enum EventIdentityRelationship {
  self(0),
  dependencies(1),
  graph(2),
  unrelated(3);

  const EventIdentityRelationship(this.value);
  final int value;
}

abstract class EventIdentityProvider {
  String getCurrentIdentity();

  EventIdentityRelationship getRelationship(String from, String to);
}

class AnonymousIdentityProvider implements EventIdentityProvider {
  @override
  String getCurrentIdentity() => 'anonymous';

  @override
  EventIdentityRelationship getRelationship(String from, String to) {
    return EventIdentityRelationship.unrelated;
  }
}

class MosaicIdentityProvider implements EventIdentityProvider {
  final Map<(String, String), EventIdentityRelationship> _cached = {};

  @override
  String getCurrentIdentity() {
    return mosaic.registry.current.name;
  }

  EventIdentityRelationship _getRelationship(Module from, Module to) {
    if (from.name == to.name) return EventIdentityRelationship.self;
    if (from.dependencies.contains(to)) {
      return EventIdentityRelationship.dependencies;
    }

    final queue = Queue<Module>();
    final seen = <Module>{};
    queue.add(from);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (seen.contains(node)) {
        return EventIdentityRelationship.unrelated;
      }
      seen.add(node);
      if (node.name == to.name) {
        return EventIdentityRelationship.graph;
      }

      for (final dependency in node.dependencies) {
        queue.add(dependency);
      }
    }
    return EventIdentityRelationship.unrelated;
  }

  @override
  EventIdentityRelationship getRelationship(String from, String to) {
    final cached = _cached[(from, to)];
    if (cached != null) return cached;

    final source = mosaic.registry.modules[from];
    final target = mosaic.registry.modules[to];

    if (source == null || target == null) {
      return EventIdentityRelationship.unrelated;
    }

    final relationship = _getRelationship(source, target);
    _cached[(from, to)] = relationship;
    return relationship;
  }
}
