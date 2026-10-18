import "dart:async";

/// One live upstream subscription shared by every listener, with the latest
/// value replayed to anyone who starts listening.
///
/// Why this exists: a `StreamBuilder` resubscribes whenever it is given a
/// different Stream object. Calling `dataService.something()` inside `build()`
/// used to create a brand-new stream on every rebuild, so each rebuild threw
/// away the current data and the widget went back to "waiting / no data" for a
/// moment. With a periodic rebuild (a new reading every few seconds) that showed
/// up as items that appear, vanish and reappear in a loop.
///
/// [stream] always returns the SAME Stream instance, and a new listener is handed
/// the last known value immediately, so a rebuild or a screen change never blanks
/// the UI.
class SharedStream<T> {
  SharedStream(this._create, {this.grace = const Duration(seconds: 30)});

  final Stream<T> Function() _create;

  /// How long the upstream subscription (and the cached last value) is kept after
  /// the last listener leaves, so switching tabs and coming back is instant.
  final Duration grace;

  final List<MultiStreamController<T>> _listeners = [];
  StreamSubscription<T>? _sub;
  Timer? _graceTimer;
  T? _last;
  bool _hasLast = false;
  bool _disposed = false;

  /// True while the upstream subscription is open (for tests).
  bool get isConnected => _sub != null;

  late final Stream<T> stream = Stream<T>.multi((controller) {
    if (_disposed) {
      controller.close();
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = null;
    if (_hasLast) controller.add(_last as T);
    _listeners.add(controller);
    _connect();
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty) _scheduleDisconnect();
    };
  });

  void _connect() {
    if (_sub != null) return;
    _sub = _create().listen(
      (value) {
        _last = value;
        _hasLast = true;
        for (final l in List.of(_listeners)) {
          l.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in List.of(_listeners)) {
          l.addError(error, stack);
        }
      },
    );
  }

  void _scheduleDisconnect() {
    _graceTimer?.cancel();
    _graceTimer = Timer(grace, () {
      if (_listeners.isEmpty) _disconnect();
    });
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _hasLast = false;
    _last = null;
  }

  /// Closes everything (used on sign-out so one user's data is never replayed
  /// to the next).
  void dispose() {
    _disposed = true;
    _graceTimer?.cancel();
    _disconnect();
    for (final l in List.of(_listeners)) {
      l.close();
    }
    _listeners.clear();
  }
}
