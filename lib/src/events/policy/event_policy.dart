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

import 'package:mosaic/src/events/events.dart';
import 'package:mosaic/src/events/policy/identity_provider.dart';
import 'package:mosaic/src/modules/modules.dart';

typedef EventViolationAction = void Function(EventViolationContext);

enum EventAccessLevel {
  internal(0),
  dependencies(1),
  graph(2),
  public(3);

  const EventAccessLevel(this.value);
  final int value;
}

enum EventPermission { emit, listen, retain, clearRetained, createChannels }

enum EventAction { emit, listen, retain, clearRetained, createChannels }

class EventViolationContext {
  EventViolationContext(this.sender, this.receiver);

  final Module sender;
  final Module receiver;
}

class EventAccessControl {
  EventAccessControl({
    this.emit = EventAccessLevel.public,
    this.receive = EventAccessLevel.public,
  });
  final EventAccessLevel emit;
  final EventAccessLevel receive;

  bool canEmit(EventIdentityRelationship relationship) {
    return relationship.value <= emit.value;
  }

  bool canReceive(EventIdentityRelationship relationship) {
    return relationship.value <= receive.value;
  }
}

class EventScope {
  EventScope({
    this.includes = const [],
    this.excludes = const [],
    this.overrides,
  });
  final List<String> includes;
  final List<String> excludes;

  final Map<String, EventPolicy>? overrides;
}

class EventPolicy {
  EventPolicy({
    required this.access,
    required this.permissions,
    required this.scope,
    required this.onViolation,
    this.reason,
  });

  factory EventPolicy.permissive() {
    return EventPolicy(
      access: EventAccessControl(),
      permissions: {},
      scope: EventScope(),
      onViolation: (_) {},
      reason: 'Permissive default policy',
    );
  }
  final EventAccessControl access;
  final Set<EventPermission> permissions;
  final EventScope scope;
  final EventViolationAction onViolation;
  final String? reason;

  void hasPermission(
    EventContext ctx,
    EventAction action,
    EventIdentityRelationship relationship,
  ) {}
}
