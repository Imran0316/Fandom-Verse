/// Emits [value] exactly once and then closes.
///
/// Unlike [Stream.value] (which is single-subscription and throws if it is
/// listened to twice), the returned stream can be listened to any number of
/// times — e.g. when a StreamBuilder unmounts and remounts while its parent
/// State keeps the stream instance cached.
Stream<T> onceStream<T>(T value) => Stream<T>.multi((controller) {
      controller.add(value);
      controller.close();
    });
