import 'package:dio/dio.dart';
import 'storage_service.dart';

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
}

class PaymentService {
  // Update this to your production URL
  static const String _base = 'https://web-production-3fa8c.up.railway.app/api/payments';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<Options> _authOptions() async {
    final token = await StorageService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Initiates payment for [planId].
  /// Returns the payment link to open in webview.
  static Future<String> initiatePayment(int planId) async {
    final opts = await _authOptions();
    try {
      final res = await _dio.post(
        '$_base/initiate/',
        data: {'plan_id': planId},
        options: opts,
      );

      final paymentLink = res.data['payment_link'] as String;
      final txRef = res.data['tx_ref'] as String;

      // Store tx_ref for verification after redirect
      await StorageService.setString('pending_tx_ref', txRef);

      return paymentLink;
    } on DioException catch (e) {
      throw PaymentException(_extractError(e.response?.data));
    }
  }

  /// Gets the pending tx_ref from storage
  static Future<String?> getPendingTxRef() async {
    return StorageService.getString('pending_tx_ref');
  }

  /// Clears the pending tx_ref
  static Future<void> clearPendingTxRef() async {
    await StorageService.remove('pending_tx_ref');
  }

  /// Verifies payment by [txRef].
  /// [transactionId] is the Flutterwave transaction ID from the redirect URL
  /// query parameter `transaction_id`. Required in live mode; may be omitted
  /// in test mode where the backend activates the subscription by tx_ref alone.
  static Future<void> verifyPayment(String txRef, {String? transactionId}) async {
    final opts = await _authOptions();
    try {
      final body = <String, dynamic>{'tx_ref': txRef};
      if (transactionId != null && transactionId.isNotEmpty) {
        body['transaction_id'] = transactionId;
      }
      await _dio.post('$_base/verify/', data: body, options: opts);
    } on DioException catch (e) {
      throw PaymentException(_extractError(e.response?.data));
    }
  }

  /// Gets the payment redirect URL base
  static String get paymentRedirectBase => 'cinehubs://payment-complete';

  static String _extractError(dynamic data) {
    if (data == null) return 'Something went wrong';
    if (data is Map) {
      final detail = data['detail'] ?? data['error'];
      if (detail != null) return detail.toString();
    }
    return 'Something went wrong';
  }
}