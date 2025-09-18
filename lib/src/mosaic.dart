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

import 'package:mosaic/mosaic.dart';
import 'package:mosaic/src/dependency_injection/dependency_container.dart';

class MosaicContainer with Injectable {
  MosaicContainer._internal() {
    put(Events());
    put(InternalRouter());
    put(Logger());
    put(Imc());
    put(ModuleManager());
  }

  Events get events => get<Events>();
  InternalRouter get router => get<InternalRouter>();
  Imc get imc => get<Imc>();
  ModuleManager get registry => get<ModuleManager>();

  /// Global logger instance for application-wide logging.
  ///
  /// This singleton provides a convenient way to access logging functionality
  /// from anywhere in your application without dependency injection.
  ///
  /// **Example:**
  /// ```dart
  /// logger.info('Application started');
  /// logger.error('Failed to connect to database');
  /// ```
  Logger get logger => get<Logger>();
}

mixin MosaicServices {
  Events get events => mosaic.events;
  InternalRouter get router => mosaic.router;
  Imc get imc => mosaic.imc;
  ModuleManager get registry => mosaic.registry;
  Logger get logger => mosaic.logger;
}

final mosaic = MosaicContainer._internal();
