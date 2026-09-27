import 'dart:async';

import 'auth_service.dart';

/// Memoizes a service stream so StreamBuilders keep the same stream instance
/// across rebuilds (route pushes, keyboard changes, local setState) instead of
/// resubscribing to Firestore — and re-running loading states — on every tick.
///
/// The cached view supports any number of concurrent listeners: the Home tab
/// shares one cache across several sections (Discovery, Trending, News and
/// LatestDiscoveries all listen to `_published`), and a raw single-subscription
/// stream would throw `Bad state: Stream has already been listened to` on the
/// second subscriber. The cache therefore owns exactly one subscription to the
/// service stream, fans every event out to all listeners, and replays the
/// latest event to late joiners so they show data instead of an endless
/// skeleton.
///
/// Ownership mirrors StreamBuilder's own lifecycle: when the last listener
/// cancels, the service subscription is cancelled; the next listener calls
/// [create] again for a fresh source (all `watch*()` services are per-call
/// factories, so re-listening is safe).
///
/// A stream is only cached once Firebase is ready: while initialization is
/// still pending (or has failed) each call re-creates the service guard
/// stream, so a late [AuthService.firebaseReady] flip is still picked up by
/// the next rebuild — exactly like the previous create-streams-in-build
/// pattern, but without the churn once caching is active.
class StreamCache<T> {
  StreamCache(this.create);

  final Stream<T> Function() create;

  Stream<T>? _view;
  StreamSubscription<T>? _source;
  final Set<MultiStreamController<T>> _listeners = <MultiStreamController<T>>{};
  bool _hasLatest = false;
  T? _latest;
  bool _sourceDone = false;

  Stream<T> call() {
    if (!AuthService.firebaseReady) return create();
    return _view ??= Stream<T>.multi(_attach);
  }

  void _attach(MultiStreamController<T> controller) {
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty) {
        _source?.cancel();
        _source = null;
      }
    };
    _listeners.add(controller);
    if (_hasLatest) controller.add(_latest as T);
    if (_sourceDone) {
      controller.close();
      return;
    }
    _source ??= create().listen(
      _fanOut,
      onError: _fanOutError,
      onDone: _fanOutDone,
      cancelOnError: false,
    );
  }

  void _fanOut(T event) {
    _latest = event;
    _hasLatest = true;
    for (final listener in List<MultiStreamController<T>>.of(_listeners)) {
      listener.add(event);
    }
  }

  void _fanOutError(Object error, StackTrace stackTrace) {
    for (final listener in List<MultiStreamController<T>>.of(_listeners)) {
      listener.addError(error, stackTrace);
    }
  }

  void _fanOutDone() {
    _source = null;
    _sourceDone = true;
    for (final listener in List<MultiStreamController<T>>.of(_listeners)) {
      listener.close();
    }
  }
}
