import 'package:dio/dio.dart';
import 'api_errors.dart';
import 'auth_repository.dart';
import 'token_store.dart';

Dio buildApiClient(TokenStore store, AuthRepository auth) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example-campus-api.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final access = await store.readAccess();
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
      handler.next(options);
    },
    onError: (e, handler) async {
      if (e.response?.statusCode == 401) {
        final refresh = await store.readRefresh();
        if (refresh == null) {
          // Tidak ada refresh token → lempar AppError agar UI bisa redirect login.
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              // Sertakan AppError di message agar interceptor atas bisa tangkap.
              message: toAppError(e).message,
              type: e.type,
              response: e.response,
            ),
          );
        }
        try {
          final renewed = await auth.refresh(refresh);
          await store.save(access: renewed, refresh: refresh);
          final retry = await dio.fetch(
            e.requestOptions..headers['Authorization'] = 'Bearer $renewed',
          );
          return handler.resolve(retry);
        } on DioException catch (retryErr) {
          // Refresh ikut mati → bersihkan sesi, paksa login ulang.
          await store.clear();
          return handler.reject(
            DioException(
              requestOptions: retryErr.requestOptions,
              message: toAppError(retryErr).message,
              type: retryErr.type,
              response: retryErr.response,
            ),
          );
        }
      }

      // Untuk error lain: convert ke AppError dan teruskan.
      // Caller cukup catch DioException dan panggil friendlyMessage(e)
      // atau toAppError(e) untuk mendapat pesan UI.
      handler.next(e);
    },
  ));
  return dio;
}