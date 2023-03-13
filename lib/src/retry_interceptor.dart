import 'dart:ffi';

import 'package:dio/dio.dart';
// import 'package:logging/logging.dart';

import 'options.dart';

/// An interceptor that will try to send failed request again
class RetryInterceptor extends Interceptor {
  final Dio dio;

  final Function(ErrorResult err)? errorCallback;

  final RetryOptions options;

  RetryInterceptor(
      {required this.dio, RetryOptions? options, this.errorCallback})
      : options = options ?? const RetryOptions();

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    var extra = RetryOptions.fromExtra(err.requestOptions) ?? options;

//     var shouldRetry = extra.retries > 0 && await extra.retryEvaluator(err); (bugged, as per https://github.com/aloisdeniel/dio_retry/pull/5)
    var shouldRetry = extra.retries > 0 && await options.retryEvaluator(err);
    if (shouldRetry) {
      if (extra.retryInterval.inMilliseconds > 0) {
        await Future<void>.delayed(extra.retryInterval);
      }

      // Update options to decrease retry count before new try
      extra = extra.copyWith(retries: extra.retries - 1);
      err.requestOptions.extra = err.requestOptions.extra
        ..addAll(extra.toExtra());

      try {
        errorCallback!(ErrorResult(err.requestOptions.uri.toString(),
            err.message, extra.retries, err.error.toString()));

        // logger?.warning(
        //     "[${err.request.uri}] An error occured during request, trying a again (remaining tries: ${extra.retries}, error: ${err.error})");
        // We retry with the updated options
        final res = await dio.request<dynamic>(
          err.requestOptions.path,
          cancelToken: err.requestOptions.cancelToken,
          data: err.requestOptions.data,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
          onSendProgress: err.requestOptions.onSendProgress,
          queryParameters: err.requestOptions.queryParameters,
          options: Options(extra: err.requestOptions.extra),
        );
        handler.resolve(res);
      } catch (e) {
        handler.reject(err);
      }
    }

    super.onError(err, handler);
  }

//   @override
//   onError(DioError err) async {

//     return super.onError(err);
//   }
}

class ErrorResult {
  final String uri;
  final String response;
  final int retryCount;
  final String error;

  // final allowedRetries;

  ErrorResult(this.uri, this.response, this.retryCount, this.error);
}
