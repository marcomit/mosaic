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

import 'dart:async';

import 'package:argv/argv.dart';

import 'context.dart';
import 'mosaic.dart';
import 'config.dart';
import 'enviroment.dart';
import 'exception.dart';

Argv setupCli() {
  final mosaic = Mosaic();
  final config = Configuration();
  final env = Environment();

  ArgvCallback wrap(FutureOr<void> Function(Context) callback) {
    return (ArgvResult res) async {
      final ctx = Context(config: config, env: env, cli: res);
      return await callback(ctx);
    };
  }

  final app = Argv('mosaic', 'Modular architecture')
    ..command('run', description: 'Run the app')
    ..command(
      'walk',
      description: 'Execute the command in all tesserae',
    ).positional('command').on(wrap(mosaic.walk))
    ..command('status').on(wrap(mosaic.status))
    ..command(
      'list',
      description: 'Discover all tesserae in the project',
    ).positional('path').flag('path', abbr: 'p').on(wrap(mosaic.list))
    ..command(
      'create',
      description: 'Create a new mosaic project',
    ).positional('name').on(wrap(mosaic.create))
    ..command(
      'add',
      description: 'Add a tessera',
    ).positional('name').on(wrap(mosaic.add))
    ..command('delete', description: 'Delete a tessera')
        .positional('name')
        .flag('force', abbr: 'f', defaultTo: false)
        .on(wrap(mosaic.delete))
    ..command(
      'tidy',
      description: 'Add to the root project all existing tesserae',
    ).on(wrap(mosaic.tidy))
    ..command(
      'enable',
      description: 'Enable a tessera',
    ).positional('name').on(wrap(mosaic.enable))
    ..command(
      'disable',
      description: 'Disable a tessera',
    ).positional('name').on(wrap(mosaic.disable))
    ..command(
      'default',
      description: 'Set the default tessera',
    ).positional('name').on(wrap(mosaic.setDefault))
    ..command(
      'events',
      description: 'Build the events based on the configuration file',
    ).on(wrap(mosaic.events));
  return app;
}

void main(List<String> args) async {
  final mosaic = setupCli();

  try {
    if (args.isEmpty) return print(mosaic.usage());
    await mosaic.run(args);
  } on ArgvException catch (e) {
    print(e);
    print(mosaic.usage());
  } on CliException catch (e) {
    print(e);
  } catch (e, stack) {
    print('Unknown error $e');
    print(stack);
  }
}
