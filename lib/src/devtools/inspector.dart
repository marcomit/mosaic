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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';

/// A live, in-app inspector panel for a Mosaic application.
///
/// Surfaces module lifecycle states, the contract registry, feature-flag
/// overrides, and a rolling log of framework events — the things that are
/// hardest to reason about in a modular app. It reads the running [mosaic]
/// container directly and refreshes as lifecycle/contract/feature events fire.
///
/// Drop it anywhere in a [MaterialApp], or use [MosaicInspectorOverlay] to get a
/// toggleable debug button automatically.
class MosaicInspector extends StatefulWidget {
  const MosaicInspector({super.key});

  @override
  State<MosaicInspector> createState() => _MosaicInspectorState();
}

class _MosaicInspectorState extends State<MosaicInspector> with Admissible {
  static const _maxLog = 50;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    on<String>('module_manager/module_activated', (c) => _add('activated ${c.data}'));
    on<ModuleLifecycleState>(
        'module/*/state_changed', (c) => _add('${c.params.first} → ${c.data.name}'));
    on<String>('contracts/provided/*', (c) => _add('contract ${c.params.first} ⊕ ${c.data}'));
    on<String>('contracts/revoked/*', (c) => _add('contract ${c.params.first} ⊖ ${c.data}'));
    on<bool>('features/*', (c) => _add('flag ${c.params.first} = ${c.data}'));
  }

  void _add(String entry) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, entry);
      if (_log.length > _maxLog) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final health = mosaic.registry.getHealthStatus();
    final contracts = mosaic.contracts.providers;
    final flags = mosaic.features.overrides;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _header('Modules (${health.length})'),
            for (final entry in health.entries)
              _row(entry.key, '${entry.value['state']}'
                  '${entry.value['hasError'] == true ? ' ⚠' : ''}'),
            _header('Contracts (${contracts.length})'),
            if (contracts.isEmpty) _muted('none'),
            for (final entry in contracts.entries)
              _row('${entry.key}', entry.value),
            _header('Feature flags (${flags.length})'),
            if (flags.isEmpty) _muted('none'),
            for (final entry in flags.entries)
              _row(entry.key, entry.value ? 'on' : 'off'),
            _header('Events (latest ${_log.length})'),
            if (_log.isEmpty) _muted('no events yet'),
            for (final entry in _log)
              Text(entry, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _row(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(key, overflow: TextOverflow.ellipsis)),
            Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _muted(String text) =>
      Text(text, style: TextStyle(color: Theme.of(context).disabledColor));
}

/// Wraps [child] and adds a floating button (debug builds only by default) that
/// toggles the [MosaicInspector] panel.
///
/// ```dart
/// runApp(MaterialApp(home: MosaicInspectorOverlay(child: MosaicScope())));
/// ```
class MosaicInspectorOverlay extends StatefulWidget {
  const MosaicInspectorOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
  });

  final Widget child;

  /// Whether the toggle button is shown. Defaults to [kDebugMode].
  final bool enabled;

  @override
  State<MosaicInspectorOverlay> createState() => _MosaicInspectorOverlayState();
}

class _MosaicInspectorOverlayState extends State<MosaicInspectorOverlay> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_open)
          const Positioned(
            right: 8,
            bottom: 72,
            top: 80,
            width: 320,
            child: Card(
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              child: MosaicInspector(),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton.small(
            heroTag: 'mosaic_inspector',
            onPressed: () => setState(() => _open = !_open),
            child: Icon(_open ? Icons.close : Icons.bug_report),
          ),
        ),
      ],
    );
  }
}
