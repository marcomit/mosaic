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
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'build.dart';
import 'events.dart';
import 'init.dart';
import 'gesso.dart';

class ArgNode {
  final String val;
  final String description;
  final List<ArgNode> children;
  final Future<void> Function(ArgResults?)? callback;

  ArgNode(
    this.val, {
    this.description = "",
    this.children = const [],
    this.callback,
  });

  ArgParser addCommand(ArgParser parser) {
    final added = parser.addCommand(val);
    for (final child in children) {
      child.addCommand(added);
    }
    return added;
  }

  void parse(ArgResults res) {
    if (res.command?.name != val) return;

    if (callback != null) callback!(res);

    for (final child in children) {
      child.parse(res.command!);
    }
  }
}

final cmds = ArgNode(
  "",
  children: [
    ArgNode(
      'create',
      callback: create,
      description: "Create a new mosaic project",
    ),
    ArgNode('init', callback: init, description: "Initialize a mosaic project"),
    ArgNode('add', callback: addModule, description: "Add a module"),
    ArgNode('enable', callback: enable, description: "Enable a module"),
    ArgNode('disable', callback: disable, description: "Disable a module"),
    ArgNode('default', callback: setDefault, description: "Set default module"),
    ArgNode('list', callback: listModules, description: "List modules"),
    ArgNode('remove', callback: removeModule, description: "Remove a module"),
    ArgNode(
      'build',
      callback: (_) async => await build(),
      description: "Build all modules",
    ),
    ArgNode(
      'events',
      callback: (_) async => await events(),
      description: "Generate event tree",
    ),
  ],
);

void main(List<String> args) {
  final parser = ArgParser();

  for (final child in cmds.children) {
    child.addCommand(parser);
  }

  final res = parser.parse(args);

  if (res.command == null) {
    print("No command provided. Usage: module <command>\n");
    print("COMMANDS");
    for (final cmd in cmds.children) {
      print("${cmd.val.padRight(10)}: ${cmd.description}");
    }
    exit(1);
  }

  for (final child in cmds.children) {
    child.parse(res);
  }
}
