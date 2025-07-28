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

import 'semaphore.dart';

/// Mutex is used to protect modification at the same time across multi threads
/// The api is very simple:
/// ```dart
/// final mutex = Mutex("my_shared_data");
/// String data = await mutex.get(); // This returns "my_shared_data"
/// mutex.set("my_new_value");
/// ```
/// If you want to use the value in a larger context you can do this instead
/// ```dart
/// final mutex = Mutex([1, 2, 3, 4, 5, 6]);
/// await mutex.use((v) {
///   // Manipulate your data here
/// });
/// ```
class Mutex<T> {
  /// The wrapped value
  /// It is private to prevent raw modification
  T _data;

  /// _s semaphore is used to lock the access to the data
  final Semaphore _s = Semaphore();

  Mutex(this._data);

  /// Method to set the new value
  Future<void> set(T value) async {
    await _s.lock();
    _data = value;
    _s.release();
  }

  /// Method to get the current value
  Future<T> get() async => await use((d) async => d);

  /// Method to handle data
  Future<V> use<V>(Future<V> Function(T) callback) async {
    try {
      await lock();
      final res = await callback(_data);
      return res;
    } finally {
      release();
    }
  }

  /// Lock the access to the data and returns it.
  /// Helpful method to give higher control to the semaphore
  Future<T> lock() async {
    await _s.lock();
    return _data;
  }

  /// Release the access to the data and returns it.
  /// Helpful method to give higher control to the semaphore
  void release() => _s.release();
}
