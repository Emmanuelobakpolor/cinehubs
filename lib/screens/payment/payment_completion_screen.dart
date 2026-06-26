import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../app_colors.dart';
import '../../services/payment_service.dart';
import '../main/main_screen.dart';

class PaymentCompletionScreen extends StatefulWidget {
  final String paymentLink;
  final String txRef;
  /// Human-readable plan label shown in the success dialog (e.g. 'PREMIUM', 'Basic Movie').
  final String planName;
  /// When provided, called with the verified txRef instead of navigating to MainScreen.
  /// Use this when launching from a context that needs to handle post-payment logic itself.
  final Future<void> Function(String txRef)? onPaymentSuccess;

  const PaymentCompletionScreen({
    super.key,
    required this.paymentLink,
    required this.txRef,
    this.planName = 'PREMIUM',
    this.onPaymentSuccess,
  });

  @override
  State<PaymentCompletionScreen> createState() => _PaymentCompletionScreenState();
}

class _PaymentCompletionScreenState extends State<PaymentCompletionScreen> {
  bool _isProcessing = false;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _processPayment({String? transactionId}) async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _isProcessing = true;
      _error = null;
    });

    try {
      await PaymentService.verifyPayment(widget.txRef, transactionId: transactionId);
      await PaymentService.clearPendingTxRef();

      if (!mounted) return;

      if (widget.onPaymentSuccess != null) {
        await widget.onPaymentSuccess!(widget.txRef);
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSuccessAndNavigate();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isVerifying = false;
        _error = e.toString();
      });
      _showFailureAndNavigate();
    }
  }

  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${widget.planName} access is now active.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Start Watching',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailureAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Your payment could not be completed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Go Home',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns true only when Flutterwave explicitly signals a successful payment.
  /// Checks the `status` query parameter first (Flutterwave sends 'successful',
  /// 'success', or 'completed' depending on payment type and region).
  /// Falls back to URL path patterns for the test-mode mock endpoint.
  bool _isSuccessUrl(Uri uri) {
    final statusParam = uri.queryParameters['status']?.toLowerCase();
    if (statusParam != null) {
      return statusParam == 'successful' ||
          statusParam == 'success' ||
          statusParam == 'completed';
    }
    // Test-mode mock endpoint: /api/payments/mock-pay/?tx_ref=...
    final path = uri.path.toLowerCase();
    return path.contains('mock-pay') || path.contains('payment-complete') || path.contains('payment-success');
  }

  /// Returns true when Flutterwave signals a failed or cancelled payment.
  bool _isFailureUrl(Uri uri) {
    final statusParam = uri.queryParameters['status']?.toLowerCase();
    if (statusParam != null) {
      return statusParam == 'failed' || statusParam == 'cancelled' || statusParam == 'error';
    }
    final path = uri.path.toLowerCase();
    return path.contains('payment-failed') || path.contains('payment-failure');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text(
                    _isProcessing
                        ? 'Verifying payment...'
                        : _error ?? 'Something went wrong',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri.uri(Uri.parse(widget.paymentLink)),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      transparentBackground: true,
                      verticalScrollBarEnabled: false,
                    ),
                    onLoadStop: (controller, url) async {
                      if (url == null || _isVerifying) return;

                      final uri = Uri.parse(url.toString());

                      if (_isFailureUrl(uri)) {
                        setState(() {
                          _error = 'Payment was cancelled or failed.';
                          _isProcessing = false;
                        });
                        _showFailureAndNavigate();
                        return;
                      }

                      // Flutterwave appends tx_ref to the redirect URL on all outcomes.
                      // Only proceed when the status is explicitly successful.
                      final txRef = uri.queryParameters['tx_ref'];
                      final transactionId = uri.queryParameters['transaction_id'];

                      if (txRef != null && _isSuccessUrl(uri)) {
                        if (txRef == widget.txRef) {
                          await _processPayment(transactionId: transactionId);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
