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
    await lock();
    final res = await callback(_data);
    release();
    return res;
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
