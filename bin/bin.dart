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
import 'services/dependency_resolver.dart';
import 'services/profile.dart';
import 'config.dart';
import 'enviroment.dart';
import 'exception.dart';

extension on Argv {
  Argv get validateConfig {
    return on((cli) async {
      await cli.get<Context>().config.validateConfig();
    });
  }

  Argv get check => on((cli) async {
    await cli.get<Context>().checkEnvironment();
  });

  Argv get sync => use<ProfileService>((p) => p.sync);
  Argv get help {
    return flag('help', abbr: 'h').on((cli) {
      if (cli.commands.isEmpty) return;
      if (cli.commands.last != name) return;
      if (!cli.flag('help')) {
        print('Invalid command.');
        print('  -h or --help to see the usage!');
        return;
      }
      print(usage());
    });
  }
}

Argv setupContext(Argv app) {
  final config = Configuration();
  final env = Environment();
  final ctx = Context(config: config, env: env);
  final mosaic = MosaicService();
  final event = EventService();
  final tessera = TesseraService();
  final dependencyResolver = DependencyResolver();
  final profile = ProfileService();

  return app
      .set(ctx)
      .set(mosaic)
      .set(tessera)
      .set(event)
      .set(dependencyResolver)
      .set(profile);
}

ArgvCallback require(String name) {
  return (res) {
    if (res.positional(name) != null) return;
    throw CliException('Missing positional argument $name');
  };
}

void setupProjectCommands(Argv app) {
  app
    ..command(
      'init',
      description: 'Initialize a new mosaic project',
    ).positional('name').on(require('name')).use<MosaicService>((m) => m.create)
    ..command(
      'status',
      description: 'Show project status and current profile',
    ).check.use<MosaicService>((m) => m.status);
}

void setupTesseraCommands(Argv app) {
  final tessera = app.command('tessera', description: 'Manage tesserae');

  tessera.help
    ..command('add', description: 'Create a new tessera')
        .positional('name')
        .on(require('name'))
        .check
        .use<TesseraService>((t) => t.add)
    ..command('enable', description: 'Enable a tessera')
        .positional('name')
        .on(require('name'))
        .check
        .use<TesseraService>((t) => t.enable)
    ..command('disable', description: 'Disable a tessera')
        .positional('name')
        .on(require('name'))
        .check
        .use<TesseraService>((t) => t.disable)
    ..command('list', description: 'List all tesserae')
        .flag('deps', abbr: 'd', description: 'Show dependencies')
        .option(
          'path',
          abbr: 'p',
          defaultValue: 'abs',
          allowed: ['abs', 'rel'],
          description: 'Path display format',
        )
        .check
        .use<MosaicService>((m) => m.list);
}

void setupDependencyCommands(Argv app) {
  final deps = app
      .command('deps', description: 'Manage tessera dependencies')
      .help;

  final depsAdd = deps.command('add', description: 'Add dependency to tessera');

  final depsRemove = deps.command(
    'remove',
    description: 'Remove dependency from tessera',
  );

  Argv.group(
    [depsAdd, depsRemove],
    (cmd) => cmd
        .positional('tessera')
        .positional('dependency')
        .on(require('tessera'))
        .on(require('dependency'))
        .check,
  );

  depsAdd.use<TesseraService>((t) => t.depsAdd);
  depsRemove.use<TesseraService>((t) => t.depsRemove);
}

void setupProfileCommands(Argv app) {
  final profile = app.command('profile', description: 'Manage profiles');

  profile.help
    ..command(
      'list',
      description: 'List all profiles',
    ).check.validateConfig.use<ProfileService>((p) => p.list)
    ..command('switch', description: 'Switch to profile')
        .positional('name')
        .on(require('name'))
        .check
        .use<ProfileService>((p) => p.switchTo)
        .sync
    ..command(
      'show',
      description: 'Show profile details',
    ).positional('name').check.validateConfig.use<ProfileService>((p) => p.show)
    // ..command('delete', description: 'Delete profile')
    //     .positional('name')
    //     .on(require('name'))
    //     .check
    //     .use<ProfileService>((p) => p.delete)
    ..command('add', description: 'Add tessera to profile')
        .positional('tessera')
        .positional('profile')
        .on(require('tessera'))
        .check
        .validateConfig
        .use<ProfileService>((p) => p.addTessera)
        .sync
    ..command('remove', description: 'Remove tessera from profile')
        .positional('tessera')
        .positional('profile')
        .on(require('tessera'))
        .check
        .validateConfig
        .use<ProfileService>((p) => p.removeTessera)
        .sync
    ..command(
      'sync',
      description: 'Sync the tesserae from profile',
    ).positional('profile').check.validateConfig.sync
    ..command('set-default', description: 'Set default tessera for profile')
        .positional('tessera')
        .positional('profile')
        .on(require('tessera'))
        .check
        .validateConfig
        .use<ProfileService>((p) => p.setDefault)
        .sync;
}

void setupExecutionCommands(Argv app) {
  app
    ..command(
      'run',
      description: 'Run profile',
    ).positional('profile').check.use<ProfileService>((p) => p.run)
    ..command(
      'build',
      description: 'Build profile',
    ).positional('profile').check.use<ProfileService>((p) => p.build)
    ..command('exec', description: 'Execute profile command')
        .positional('command')
        .positional('profile')
        .on(require('command'))
        .check
        .use<ProfileService>((p) => p.exec)
    ..command(
      'sync',
      description: 'Sync profile and generate init files',
    ).positional('profile').check.use<MosaicService>((m) => m.sync);
}

void setupCodeGenerationCommands(Argv app) {
  final events = app.command('events', description: 'Event management');

  events
      .command('generate', description: 'Generate events from config')
      .check
      .use<EventService>((e) => e.generate);
}

Argv setupCli() {
  final app = setupContext(Argv('mosaic', 'Modular architecture'));

  setupProjectCommands(app);
  setupTesseraCommands(app);
  setupDependencyCommands(app);
  setupProfileCommands(app);
  setupExecutionCommands(app);
  setupCodeGenerationCommands(app);

  return app;
}

void main(List<String> args) async {
  final mosaic = setupCli();
  try {
    if (args.isEmpty) return print(mosaic.usage());
    await mosaic.run(args);
  } on ArgvException catch (e) {
    print(e);
    if (e.last != null) {
      print('');
      print(e.last!.usage());
    }
  } on CliException catch (e) {
    print(e);
  } catch (e) {
    print('Unknown error $e');
  }
}
