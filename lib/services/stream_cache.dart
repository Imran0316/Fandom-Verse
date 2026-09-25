import 'auth_service.dart';

/// Memoizes a service stream so StreamBuilders keep the same stream instance
/// across rebuilds (route pushes, keyboard changes, local setState) instead of
/// resubscribing to Firestore — and re-running loading states — on every tick.
///
/// A stream is only cached once Firebase is ready: while initialization is
/// still pending (or has failed) each call re-creates the service guard
/// stream, so a late [AuthService.firebaseReady] flip is still picked up by
/// the next rebuild — exactly like the previous create-streams-in-build
/// pattern, but without the churn once caching is active.
class StreamCache<T> {
  StreamCache(this.create);

  final Stream<T> Function() create;

  Stream<T>? _cached;

  Stream<T> call() {
    if (!AuthService.firebaseReady) return create();
    return _cached ??= create();
  }
}
