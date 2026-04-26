import 'payment_models.dart';
import 'payment_service.dart';

class PaymentRepository {
  final PaymentService _service;

  PaymentRepository({PaymentService? service})
      : _service = service ?? PaymentService();

  Future<PaymentDetailModel> fetchPaymentDetail({
    required int idIncidente,
    required String accessToken,
  }) {
    return _service.fetchPaymentDetail(
      idIncidente: idIncidente,
      accessToken: accessToken,
    );
  }

  Future<PaymentIntentModel> createPaymentIntent({
    required int idIncidente,
    required String accessToken,
  }) {
    return _service.createPaymentIntent(
      idIncidente: idIncidente,
      accessToken: accessToken,
    );
  }

  Future<DemoPaymentConfirmationModel> confirmDemoPayment({
    required int idIncidente,
    required String accessToken,
    String? referenciaDemo,
  }) {
    return _service.confirmDemoPayment(
      idIncidente: idIncidente,
      accessToken: accessToken,
      referenciaDemo: referenciaDemo,
    );
  }

  Future<PaymentReceiptModel> fetchReceipt({
    required int idPagoServicio,
    required String accessToken,
  }) {
    return _service.fetchReceipt(
      idPagoServicio: idPagoServicio,
      accessToken: accessToken,
    );
  }
}
