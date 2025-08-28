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

import 'package:argv/argv.dart';

import 'context.dart';
import 'services/mosaic.dart';
import 'services/tessera.dart';
import 'services/events.dart';
import 'config.dart';
import 'enviroment.dart';
import 'exception.dart';

Argv setupContext(Argv app) {
  final config = Configuration();
  final env = Environment();
  final ctx = Context(config: config, env: env);
  final mosaic = MosaicService();
  final event = EventService();
  final tessera = TesseraService();

  return app.set(ctx).set(mosaic).set(tessera).set(event);
}

void check(ArgvResult cli) => cli.get<Context>().checkEnvironment();

ArgvCallback require(String name) {
  return (res) {
    if (res.positional(name) != null) return;
    throw CliException('Missing positional argument $name');
  };
}

Argv setupCli() {
  final app = setupContext(Argv('mosaic', 'Modular architecture'))
    ..command('run', description: 'Run the app')
    ..command(
      'walk',
      description: 'Execute the command in all tesserae',
    ).positional('command').on(check).use<MosaicService>((m) => m.walk)
    ..command('status').on(check).use<MosaicService>((m) => m.status)
    ..command('list', description: 'Discover all tesserae in the project')
        .positional('path')
        .flag('path', abbr: 'p')
        .flag('deps', abbr: 'd')
        .on(check)
        .use<MosaicService>((MosaicService m) => m.list)
    ..command(
      'create',
      description: 'Create a new mosaic project',
    ).positional('name').use<MosaicService>((m) => m.create)
    ..command(
      'add',
      description: 'Add a tessera',
    ).positional('name').on(check).use<TesseraService>((t) => t.add)
    ..command('delete', description: 'Delete a tessera')
        .positional('name')
        .flag('force', abbr: 'f', defaultTo: false)
        .on(check)
        .use<MosaicService>((m) => m.delete)
    ..command(
      'tidy',
      description: 'Add to the root project all existing tesserae',
    ).on(check).use<MosaicService>((m) => m.tidy)
    ..command(
      'sync',
      description: 'Sync all tesserae and generate the initialization file',
    ).on(check).use<MosaicService>((m) => m.sync)
    ..command(
      'enable',
      description: 'Enable a tessera',
    ).positional('name').on(check).use<TesseraService>((t) => t.enable)
    ..command(
      'disable',
      description: 'Disable a tessera',
    ).positional('name').on(check).use<TesseraService>((t) => t.disable)
    ..command(
      'default',
      description: 'Set the default tessera',
    ).positional('name').on(check).use<MosaicService>((m) => m.setDefault)
    ..command(
      'events',
      description: 'Build the events based on the configuration file',
    ).on(check).use<EventService>((e) => e.generate);

  final deps = app.command('deps');
  final depsadd = deps.command(
    'add',
    description: 'Adds a dependency to a tessera',
  );
  final depsrem = deps.command(
    'remove',
    description: 'Removes a dependency from a tessera',
  );

  Argv.group(
    [depsadd, depsrem],
    (c) => c
        .positional('tessera')
        .positional('dependency')
        .on(require('tessera'))
        .on(require('dependency')),
  );

  depsadd.use<TesseraService>((t) => t.depsAdd);
  depsrem.use<TesseraService>((t) => t.depsRemove);

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
