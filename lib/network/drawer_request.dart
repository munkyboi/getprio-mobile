import 'dart:async';

/// A timeout releases drawer navigation but does not pretend the request was
/// cancelled. Owners disable retry and reconcile the original late result.
Future<T> awaitDrawerRequest<T>(
  Future<T> request, {
  required void Function() onTimeout,
  required void Function(T) onLateSuccess,
  required void Function(Object) onLateFailure,
}) {
  var timedOut = false;
  unawaited(
    request.then<void>(
      (value) {
        if (timedOut) {
          try {
            onLateSuccess(value);
          } catch (error) {
            onLateFailure(error);
          }
        }
      },
      onError: (Object error, StackTrace _) {
        if (timedOut) onLateFailure(error);
      },
    ),
  );
  return request.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      timedOut = true;
      onTimeout();
      throw TimeoutException('Request still processing');
    },
  );
}
