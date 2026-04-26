import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/services.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../data/payment_models.dart';
import '../../data/payment_repository.dart';
import '../../data/payment_service.dart';

class PaymentPage extends StatefulWidget {
  final int idIncidente;
  final AuthState authState;

  const PaymentPage({
    super.key,
    required this.idIncidente,
    required this.authState,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _repository = PaymentRepository();

  PaymentDetailModel? _detail;
  PaymentReceiptModel? _receipt;
  bool _isLoading = true;
  bool _isPaying = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  bool get _useSimulatedPayment => true;

  Future<void> _loadDetail() async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final detail = await _repository.fetchPaymentDetail(
        idIncidente: widget.idIncidente,
        accessToken: token,
      );
      setState(() => _detail = detail);
    } on PaymentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'No fue posible cargar el detalle del cobro');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pay() async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    if (_useSimulatedPayment) {
      await _runSimulatedPayment();
      return;
    }

    setState(() {
      _isPaying = true;
      _errorMessage = null;
      _statusMessage = 'Generando pago seguro...';
    });

    try {
      debugPrint('CU10 creando intencion para incidente=${widget.idIncidente}');
      final intent = await _repository.createPaymentIntent(
        idIncidente: widget.idIncidente,
        accessToken: token,
      );
      final rawKey = intent.publishableKey;
      final normalizedKey = rawKey.trim().replaceAll('"', '');

      debugPrint('CU10 intent publishableKey=[$rawKey]');
      debugPrint('CU10 normalized publishableKey=[$normalizedKey]');
      debugPrint('CU10 clientSecret=[${intent.clientSecret}]');

      if (normalizedKey.isEmpty || intent.clientSecret.isEmpty) {
        throw const PaymentException('El backend no devolvió credenciales de Stripe');
      }

      if (!_looksLikeStripePublishableKey(normalizedKey)) {
        throw const PaymentException(
          'La clave pública de Stripe enviada por backend no es válida.',
        );
      }

      Stripe.publishableKey = normalizedKey;
      await Stripe.instance.applySettings();

      setState(() => _statusMessage = 'Abriendo pasarela de pago...');

      debugPrint('CU10 initPaymentSheet start');
      try {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: intent.clientSecret,
            merchantDisplayName: 'AutoAssist AI',
            style: ThemeMode.system,
          ),
        );
        debugPrint('CU10 initPaymentSheet ok');
      } catch (error, stackTrace) {
        debugPrint('CU10 initPaymentSheet error=$error');
        debugPrint('CU10 initPaymentSheet stack=$stackTrace');
        rethrow;
      }

      debugPrint('CU10 presentPaymentSheet start');
      try {
        await Stripe.instance.presentPaymentSheet();
        debugPrint('CU10 presentPaymentSheet ok');
      } catch (error, stackTrace) {
        debugPrint('CU10 presentPaymentSheet error=$error');
        debugPrint('CU10 presentPaymentSheet stack=$stackTrace');
        rethrow;
      }

      setState(() => _statusMessage = 'Procesando confirmación del pago...');

      debugPrint(
        'CU10 consultando comprobante idPagoServicio=${intent.idPagoServicio}',
      );
      final receipt = await _fetchPaidReceiptWithRetries(
        idPagoServicio: intent.idPagoServicio,
        accessToken: token,
      );

      if (!mounted) return;

      if (!_isPaid(receipt)) {
        setState(() {
          _errorMessage =
              'Tu pago se está procesando. Revisa nuevamente en unos segundos.';
          _statusMessage = null;
        });
        return;
      }

      setState(() {
        _receipt = receipt;
        _statusMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago realizado correctamente')),
      );
    } on StripeException catch (error) {
      final code = error.error.code.toString().toLowerCase();
      final message = error.error.localizedMessage ?? error.error.message ?? '';
      debugPrint('CU10 StripeException code=$code message=$message');
      final normalizedMessage = message.toLowerCase();
      setState(() {
        _errorMessage = code.contains('cancel')
            ? 'El pago fue cancelado'
            : normalizedMessage.contains('invalid api key')
                ? 'La clave pública de Stripe enviada por backend no es válida.'
                : message.isEmpty
                ? 'No fue posible completar el pago'
                : 'No fue posible completar el pago: $message';
      });
    } on PaymentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (error) {
      debugPrint('CU10 error inesperado: $error');
      setState(() => _errorMessage = 'No fue posible completar el pago: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _runSimulatedPayment() async {
    final detail = _detail;
    if (detail == null) return;

    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isPaying = true;
      _errorMessage = null;
      _statusMessage = 'Preparando pago seguro...';
    });

    await Future<void>.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isPaying = false;
      _statusMessage = null;
    });

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _StripeLikePaymentSheet(detail: detail),
    );

    if (!mounted || approved != true) return;

    setState(() {
      _isPaying = true;
      _errorMessage = null;
      _statusMessage = 'Procesando pago demo...';
    });

    try {
      final confirmation = await _repository.confirmDemoPayment(
        idIncidente: widget.idIncidente,
        accessToken: token,
      );

      setState(() => _statusMessage = 'Generando comprobante...');

      final receipt = await _repository.fetchReceipt(
        idPagoServicio: confirmation.idPagoServicio,
        accessToken: token,
      );

      if (!mounted) return;

      if (!_isPaid(receipt)) {
        setState(() {
          _errorMessage = 'No fue posible registrar el pago';
          _statusMessage = null;
        });
        return;
      }

      setState(() {
        _receipt = receipt;
        _errorMessage = null;
        _statusMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado correctamente')),
      );
    } on PaymentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (error) {
      debugPrint('CU10 demo error inesperado: $error');
      setState(() => _errorMessage = 'No fue posible registrar el pago');
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<PaymentReceiptModel> _fetchPaidReceiptWithRetries({
    required int idPagoServicio,
    required String accessToken,
  }) async {
    PaymentReceiptModel? latestReceipt;

    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        setState(() {
          _statusMessage =
              'Procesando confirmación del pago... intento ${attempt + 1}';
        });
      }

      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 1000 : 1500),
      );

      final receipt = await _repository.fetchReceipt(
        idPagoServicio: idPagoServicio,
        accessToken: accessToken,
      );

      latestReceipt = receipt;
      debugPrint(
        'CU10 comprobante intento ${attempt + 1}: estado=${receipt.estadoPago}',
      );

      if (_isPaid(receipt)) return receipt;
    }

    if (latestReceipt == null) {
      throw const PaymentException('No fue posible obtener el comprobante');
    }

    return latestReceipt;
  }

  bool _isPaid(PaymentReceiptModel receipt) {
    return receipt.estadoPago.trim().toUpperCase() == 'PAGADO';
  }

  bool _looksLikeStripePublishableKey(String key) {
    final trimmedKey = key.trim();
    return (trimmedKey.startsWith('pk_test_') ||
            trimmedKey.startsWith('pk_live_')) &&
        !trimmedKey.contains('*') &&
        trimmedKey.length > 20;
  }

  Future<void> _expireSession() async {
    await widget.authState.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar auxilio')),
      body: Stack(
        children: [
          const _PaymentBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: Text('Cargando detalle del cobro...'))
                : _errorMessage != null && _detail == null
                    ? _PaymentError(message: _errorMessage!, onRetry: _loadDetail)
                    : _receipt != null
                        ? _ReceiptView(receipt: _receipt!)
                        : _PaymentDetailView(
                            detail: _detail!,
                            isPaying: _isPaying,
                            statusMessage: _statusMessage,
                            errorMessage: _errorMessage,
                            onPay: _pay,
                            onRefresh: _loadDetail,
                          ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailView extends StatelessWidget {
  final PaymentDetailModel detail;
  final bool isPaying;
  final String? statusMessage;
  final String? errorMessage;
  final VoidCallback onPay;
  final VoidCallback onRefresh;

  const _PaymentDetailView({
    required this.detail,
    required this.isPaying,
    required this.statusMessage,
    required this.errorMessage,
    required this.onPay,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _PaymentHeader(subtitle: 'Pago del servicio'),
          const SizedBox(height: 30),
          Text(
            'Pagar auxilio',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF132033),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            detail.mensaje.isEmpty
                ? 'Revisa el servicio y confirma el monto a pagar.'
                : detail.mensaje,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6E7F96),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 22),
          _SummaryCard(detail: detail),
          const SizedBox(height: 16),
          _ChargeCard(detail: detail),
          const SizedBox(height: 16),
          _PaymentMethodCard(),
          if (statusMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              statusMessage!,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed:
                isPaying || !detail.habilitadoParaPago ? null : onPay,
            child: isPaying
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text('Pagar ahora ${_money(detail.montoTotal, detail.moneda)}'),
          ),
          if (!detail.habilitadoParaPago) ...[
            const SizedBox(height: 10),
            const Text(
              'Este auxilio todavía no está habilitado para pago.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _StripeLikePaymentSheet extends StatefulWidget {
  final PaymentDetailModel detail;

  const _StripeLikePaymentSheet({required this.detail});

  @override
  State<_StripeLikePaymentSheet> createState() => _StripeLikePaymentSheetState();
}

class _StripeLikePaymentSheetState extends State<_StripeLikePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _zipController = TextEditingController();
  final _expiryFocusNode = FocusNode();
  final _cvcFocusNode = FocusNode();
  final _zipFocusNode = FocusNode();
  bool _showCardForm = false;
  bool _saveInfo = true;
  bool _isProcessing = false;

  static const _stripeBlue = Color(0xFF007AFF);
  static const _lineColor = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _zipController.dispose();
    _expiryFocusNode.dispose();
    _cvcFocusNode.dispose();
    _zipFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_showCardForm) {
      setState(() => _showCardForm = true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showCardForm
                    ? _buildCardForm(context)
                    : _buildPaymentMethods(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(BuildContext context) {
    return Column(
      key: const ValueKey('stripe-methods'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AutoAssist AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _textDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _payButton(
          background: Colors.black,
          foreground: Colors.white,
          label: 'Apple Pay',
          icon: Icons.apple,
          onPressed: _isProcessing ? null : () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 10),
        _payButton(
          background: const Color(0xFF00D66F),
          foreground: const Color(0xFF052E16),
          label: 'Pay with Link',
          icon: Icons.link,
          onPressed: _isProcessing ? null : () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider(color: _lineColor)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or pay using',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: _lineColor)),
          ],
        ),
        const SizedBox(height: 14),
        _StripeMethodRow(
          icon: Icons.credit_card,
          title: 'Card',
          selected: true,
          onTap: () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 8),
        _StripeMethodRow(
          badgeText: 'K',
          badgeColor: Color(0xFFFFB3D9),
          title: 'Klarna',
          subtitle: 'Buy now or pay later with Klarna',
          onTap: () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 8),
        _StripeMethodRow(
          badgeText: r'$',
          badgeColor: Color(0xFF00D66F),
          title: 'Cash App Pay',
          onTap: () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 8),
        _StripeMethodRow(
          icon: Icons.account_balance,
          title: 'US bank account',
          onTap: () => setState(() => _showCardForm = true),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _stripeBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _submit,
            icon: const Icon(Icons.lock, size: 16),
            label: Text('Pay ${_money(widget.detail.montoTotal, widget.detail.moneda)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildCardForm(BuildContext context) {
    return Column(
      key: const ValueKey('stripe-card-form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _isProcessing
                  ? null
                  : () => setState(() => _showCardForm = false),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              tooltip: 'Volver',
            ),
            Expanded(
              child: Text(
                'Add card',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _textDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: _isProcessing ? null : () {},
              icon: const Icon(Icons.camera_alt_outlined, size: 15),
              label: const Text('Scan card'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Card information',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: _fieldGroupDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardController,
                      enabled: !_isProcessing,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [_CardNumberInputFormatter()],
                      decoration: InputDecoration(
                        hintText: '4242 4242 4242 4242',
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.fromLTRB(14, 12, 10, 10),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              _CardBrandChip(label: 'VISA'),
                              SizedBox(width: 4),
                              _CardBrandChip(label: 'MC'),
                            ],
                          ),
                        ),
                      ),
                      validator: _validateCard,
                      onChanged: (value) {
                        if (_digitsOnly(value).length == 16) {
                          _expiryFocusNode.requestFocus();
                        }
                      },
                    ),
                    const Divider(height: 1, color: _lineColor),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            focusNode: _expiryFocusNode,
                            enabled: !_isProcessing,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [_ExpiryDateInputFormatter()],
                            decoration: const InputDecoration(
                              hintText: 'MM / YY',
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.fromLTRB(14, 12, 10, 10),
                            ),
                            validator: _validateExpiry,
                            onChanged: (value) {
                              if (value.length == 5) {
                                _cvcFocusNode.requestFocus();
                              }
                            },
                          ),
                        ),
                        Container(width: 1, height: 48, color: _lineColor),
                        Expanded(
                          child: TextFormField(
                            controller: _cvcController,
                            focusNode: _cvcFocusNode,
                            enabled: !_isProcessing,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'CVC',
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.fromLTRB(14, 12, 10, 10),
                              suffixIcon: Icon(Icons.credit_score, size: 18),
                            ),
                            validator: _validateCvc,
                            onChanged: (value) {
                              if (value.length == 3) {
                                _zipFocusNode.requestFocus();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Billing address',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: _fieldGroupDecoration(),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: const Text(
                        'Country or region',
                        style: TextStyle(fontSize: 12, color: _textMuted),
                      ),
                      subtitle: const Text('United States'),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Divider(height: 1, color: _lineColor),
                    TextFormField(
                      controller: _zipController,
                      focusNode: _zipFocusNode,
                      enabled: !_isProcessing,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'ZIP',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.fromLTRB(14, 12, 10, 10),
                      ),
                      validator: _validateZip,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _saveInfo,
                onChanged: _isProcessing
                    ? null
                    : (value) => setState(() => _saveInfo = value ?? true),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Save my info for faster checkout with Link',
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _stripeBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _isProcessing ? null : _submit,
            child: _isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...'),
                    ],
                  )
                : Text('Pay ${_money(widget.detail.montoTotal, widget.detail.moneda)}'),
          ),
        ),
      ],
    );
  }

  Widget _payButton({
    required Color background,
    required Color foreground,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  BoxDecoration _fieldGroupDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(7),
    );
  }

  String? _validateCard(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length != 16) return 'Enter 16 digits';
    return null;
  }

  String? _validateExpiry(String? value) {
    final text = value ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(text)) return 'Use MM/YY';
    final month = int.tryParse(text.substring(0, 2)) ?? 0;
    if (month < 1 || month > 12) return 'Invalid month';
    return null;
  }

  String? _validateCvc(String? value) {
    if (_digitsOnly(value ?? '').length != 3) return 'Enter 3 digits';
    return null;
  }

  String? _validateZip(String? value) {
    if (_digitsOnly(value ?? '').length < 5) return 'Enter ZIP';
    return null;
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}

class _StripeMethodRow extends StatelessWidget {
  final IconData? icon;
  final String? badgeText;
  final Color badgeColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _StripeMethodRow({
    this.icon,
    this.badgeText,
    this.badgeColor = const Color(0xFFE5E7EB),
    required this.title,
    this.subtitle,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            if (badgeText != null)
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              )
            else
              Icon(icon ?? Icons.payment, size: 22, color: const Color(0xFF111827)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFFE5E7EB),
                ),
                color: selected ? const Color(0xFFF9FAFB) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBrandChip extends StatelessWidget {
  final String label;

  const _CardBrandChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SimulatedCardPaymentSheet extends StatefulWidget {
  final PaymentDetailModel detail;

  const _SimulatedCardPaymentSheet({required this.detail});

  @override
  State<_SimulatedCardPaymentSheet> createState() =>
      _SimulatedCardPaymentSheetState();
}

class _SimulatedCardPaymentSheetState
    extends State<_SimulatedCardPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _holderController = TextEditingController();
  final _expiryFocusNode = FocusNode();
  final _cvcFocusNode = FocusNode();
  final _holderFocusNode = FocusNode();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _holderController.dispose();
    _expiryFocusNode.dispose();
    _cvcFocusNode.dispose();
    _holderFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Color(0xFF12305A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pago seguro',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'AutoAssist AI',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(widget.detail.montoTotal, widget.detail.moneda),
                      style: const TextStyle(
                        color: Color(0xFF0EA5E9),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardController,
                        enabled: !_isProcessing,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [_CardNumberInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Número de tarjeta',
                          hintText: '4242 4242 4242 4242',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        validator: _validateCard,
                        onChanged: (value) {
                          if (_digitsOnly(value).length == 16) {
                            _expiryFocusNode.requestFocus();
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              focusNode: _expiryFocusNode,
                              enabled: !_isProcessing,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [_ExpiryDateInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Vencimiento',
                                hintText: '06/28',
                              ),
                              validator: _validateExpiry,
                              onChanged: (value) {
                                if (value.length == 5) {
                                  _cvcFocusNode.requestFocus();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvcController,
                              focusNode: _cvcFocusNode,
                              enabled: !_isProcessing,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'CVC',
                                hintText: '123',
                              ),
                              validator: _validateCvc,
                              onChanged: (value) {
                                if (value.length == 3) {
                                  _holderFocusNode.requestFocus();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _holderController,
                        focusNode: _holderFocusNode,
                        enabled: !_isProcessing,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Nombre del titular',
                          hintText: 'Pedro Alaca',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _required,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF12305A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La información se procesa de forma segura para confirmar el pago.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF52657E),
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _isProcessing ? null : _submit,
                  child: _isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Procesando pago...'),
                          ],
                        )
                      : Text(
                          'Confirmar pago ${_money(widget.detail.montoTotal, widget.detail.moneda)}',
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Completa este campo';
    }
    return null;
  }

  String? _validateCard(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length != 16) return 'Ingresa 16 dígitos';
    return null;
  }

  String? _validateExpiry(String? value) {
    final text = value ?? '';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(text)) return 'Usa MM/AA';
    final month = int.tryParse(text.substring(0, 2)) ?? 0;
    if (month < 1 || month > 12) return 'Mes inválido';
    return null;
  }

  String? _validateCvc(String? value) {
    if (!RegExp(r'^\d{3}$').hasMatch(value ?? '')) return '3 dígitos';
    return null;
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = limited.length <= 2
        ? limited
        : '${limited.substring(0, 2)}/${limited.substring(2)}';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _SimulatedCardPaymentPage extends StatefulWidget {
  final PaymentDetailModel detail;

  const _SimulatedCardPaymentPage({required this.detail});

  @override
  State<_SimulatedCardPaymentPage> createState() =>
      _SimulatedCardPaymentPageState();
}

class _SimulatedCardPaymentPageState extends State<_SimulatedCardPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _holderController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de tarjeta')),
      body: Stack(
        children: [
          const _PaymentBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _PaymentHeader(subtitle: 'Transacción segura'),
                const SizedBox(height: 30),
                Text(
                  'Datos de pago',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF132033),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa una tarjeta para completar el pago del servicio.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E7F96),
                      ),
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardController,
                        enabled: !_isProcessing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tarjeta',
                          hintText: '4242 4242 4242 4242',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              enabled: !_isProcessing,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Vencimiento',
                                hintText: '12 / 34',
                              ),
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvcController,
                              enabled: !_isProcessing,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'CVC',
                                hintText: '123',
                              ),
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _holderController,
                        enabled: !_isProcessing,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del titular',
                          hintText: 'Pedro Alaca',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _required,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _WhitePanel(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFF12305A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pago demo. El backend registrará el pago y generará el comprobante.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF52657E),
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isProcessing ? null : _submit,
                  child: _isProcessing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Pagar ${_money(widget.detail.montoTotal, widget.detail.moneda)}',
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Completa este campo';
    }
    return null;
  }
}

class _SummaryCard extends StatelessWidget {
  final PaymentDetailModel detail;

  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Servicio de auxilio',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _PaymentBadge(detail.estadoServicioActual),
            ],
          ),
          const SizedBox(height: 16),
          _PaymentRow(label: 'Incidente', value: 'INC-${detail.idIncidente}'),
          _PaymentRow(label: 'Título', value: detail.titulo),
          _PaymentRow(label: 'Taller', value: detail.nombreTaller),
          if (detail.tipoIncidente.isNotEmpty)
            _PaymentRow(label: 'Tipo', value: detail.tipoIncidente),
        ],
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  final PaymentDetailModel detail;

  const _ChargeCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalle del cobro',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (detail.detallesCobro.isEmpty)
            const Text('El backend no devolvió conceptos de cobro.'),
          ...detail.detallesCobro.map(
            (item) => _PaymentRow(
              label: item.concepto,
              value: _money(
                item.monto,
                item.moneda.isEmpty ? detail.moneda : item.moneda,
              ),
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total a pagar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                _money(detail.montoTotal, detail.moneda),
                style: const TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Row(
        children: [
          const Icon(Icons.credit_card, color: Color(0xFF12305A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tarjeta bancaria',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            'Stripe seguro',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF0EA5E9),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  final PaymentReceiptModel receipt;

  const _ReceiptView({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PaymentHeader(subtitle: 'Comprobante'),
        const SizedBox(height: 42),
        const CircleAvatar(
          radius: 58,
          backgroundColor: Color(0xFFD6F8E1),
          child: Text(
            'OK',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Pago realizado correctamente',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'El backend emitió el comprobante final del servicio.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6E7F96),
              ),
        ),
        const SizedBox(height: 26),
        _WhitePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comprobante', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _PaymentRow(label: 'Incidente', value: 'INC-${receipt.idIncidente}'),
              _PaymentRow(label: 'Taller', value: receipt.nombreTaller),
              _PaymentRow(label: 'Estado', value: receipt.estadoPago),
              _PaymentRow(
                label: 'Monto',
                value: _money(receipt.montoTotal, receipt.moneda),
              ),
              _PaymentRow(label: 'Referencia', value: receipt.referenciaTransaccion),
              _PaymentRow(label: 'Fecha', value: _date(receipt.fechaPago)),
              if (receipt.comisionPlataforma > 0)
                _PaymentRow(
                  label: 'Comisión plataforma',
                  value: _money(receipt.comisionPlataforma, receipt.moneda),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (receipt.detalles.isNotEmpty)
          _WhitePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalle', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...receipt.detalles.map(
                  (item) => _PaymentRow(
                    label: item.concepto,
                    value: _money(
                      item.monto,
                      item.moneda.isEmpty ? receipt.moneda : item.moneda,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        if (receipt.receiptUrl.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Recibo: ${receipt.receiptUrl}')),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ver recibo'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}

class _PaymentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PaymentError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar nuevamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  final String subtitle;

  const _PaymentHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF12305A),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AutoAssist AI',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF132033),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6E7F96),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WhitePanel extends StatelessWidget {
  final Widget child;

  const _WhitePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7F3)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color.fromRGBO(15, 23, 42, 0.05),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String label;

  const _PaymentBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD6F8E1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label.isEmpty ? 'Servicio' : label,
          style: const TextStyle(
            color: Color(0xFF16A34A),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PaymentBackground extends StatelessWidget {
  const _PaymentBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PaymentBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PaymentBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEAF8FF);
    canvas.drawRect(Offset.zero & size, paint);

    paint.color = const Color(0xFFD6F0FB).withValues(alpha: 0.9);
    canvas.drawCircle(Offset(size.width * 0.88, 34), 88, paint);
    canvas.drawCircle(Offset(-14, size.height * 0.36), 104, paint);
    canvas.drawCircle(Offset(size.width + 16, size.height * 0.86), 112, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _money(double amount, String currency) {
  return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
}

String _date(DateTime? date) {
  if (date == null) return '-';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
