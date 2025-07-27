class AsyncState<T, V> {
  final Future<T> Function() builder;
  V Function()? _loading;
  V Function(Object?)? _error;
  V Function(T)? _success;

  AsyncState(this.builder);

  Future<T?> fetch() async {
    try {
      if (_loading != null) _loading!();
      final res = await builder();
      if (_success != null) _success!(res);
      return res;
    } catch (err) {
      if (_error != null) _error!(err);
    }
    return null;
  }

  AsyncState<T, V> loading(V Function() load) {
    _loading = load;
    return this;
  }

  AsyncState<T, V> success(V Function(T) completed) {
    _success = completed;
    return this;
  }

  AsyncState<T, V> error(V Function(Object?) err) {
    _error = err;
    return this;
  }
}

void pr() {
  AsyncState(() => Future.value(1))
      .loading(() => "loading...")
      .error((err) => "Errore")
      .success((d) => 'Data ricevuti');
}
