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
import 'gesso.dart';

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
// import 'package:interact/interact.dart';

Future<void> init(ArgResults? arg) async {}
Future<void> create(ArgResults? arg) async {
  if (arg == null) {
    print("Invalid argument".red);
    exit(1);
  }
  final projectName = arg.arguments.last;
  await downloadGitRepository('marcomit', 'mosaic_starter', projectName);
  print("Template downloaded".green);
}

Future<void> downloadGitRepository(
  String username,
  String repository,
  String output, [
  String branch = 'main',
]) async {
  final tempDir = Directory.systemTemp.createTempSync();
  final zipUrl =
      'https://github.com/$username/$repository/archive/refs/heads/$branch.zip';

  print('Downloading template...'.blink);
  final response = await http.get(Uri.parse(zipUrl));
  final archive = ZipDecoder().decodeBytes(response.bodyBytes);

  print('Extracting...'.blink.yellow);
  for (final file in archive) {
    final filename = file.name.replaceFirst('stdlib-$branch/', '');
    if (filename.isEmpty) continue;
    final outputPath = p.join(tempDir.path, filename);
    if (file.isFile) {
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(outputPath).createSync(recursive: true);
    }
  }

  final destination = Directory(output);
  if (destination.existsSync()) {
    print('Error: Folder "$output" already exists.');
    exit(1);
  }
  tempDir.renameSync(output);

  print('Project "$output" created!');
}
