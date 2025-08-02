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
class MosaicException implements Exception {
  String get name => "MosaicException";
  final String message;
  final String? cause;
  final String? fix;

  const MosaicException(this.message, {this.cause, this.fix});

  Map<String, dynamic> _toJson() => {
    'message': message,
    if (cause != null) 'cause': cause,
    if (fix != null) 'fix': fix,
  };

  @override
  String toString() => "$name ${_toJson()}";
}

class RouterException extends MosaicException {
  @override
  String get name => "RouterException";

  RouterException(super.message, {super.cause, super.fix});
}

class SignalException extends MosaicException {
  @override
  String get name => "SignalException";

  SignalException(super.message, {super.cause, super.fix});
}

/// Exception thrown when module operations fail.
class ModuleException extends MosaicException {
  @override
  String get name => "ModuleException";

  final String? moduleName;

  ModuleException(super.message, {this.moduleName, super.cause, super.fix});

  @override
  String toString() => "$name ${moduleName ?? ""} ${_toJson()}";
}

class EventException extends MosaicException {
  @override
  String get name => "EventException";

  EventException(super.message, {super.fix, super.cause});
}

class DependencyException extends MosaicException {
  @override
  String get name => "DependencyException";

  DependencyException(super.message, {super.fix, super.cause});
}

class LoggerException extends MosaicException {
  @override
  String get name => "LoggerException";
  LoggerException(super.message, {super.fix, super.cause});
}

class ImcException extends MosaicException {
  ImcException(super.message, {super.fix, super.cause});

  @override
  String get name => "ImcException";
}
