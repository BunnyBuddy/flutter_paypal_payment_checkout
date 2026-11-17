library flutter_paypal_checkout;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_paypal_payment/src/paypal_service.dart';

class PaypalCheckoutView extends StatefulWidget {
  final Function onSuccess, onCancel, onError;
  final String? note, clientId, secretKey;
  final String? returnUrl;
  final String? cancelUrl;

  final Widget? loadingIndicator;
  final List? transactions;
  final bool? sandboxMode;

  const PaypalCheckoutView({
    Key? key,
    required this.onSuccess,
    required this.onError,
    required this.onCancel,
    required this.transactions,
    required this.clientId,
    required this.secretKey,
    this.sandboxMode = false,
    this.note = '',
    this.returnUrl,
    this.cancelUrl,
    this.loadingIndicator,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PaypalCheckoutViewState();
  }
}

class PaypalCheckoutViewState extends State<PaypalCheckoutView> {
  String? checkoutUrl;
  String executeUrl = '';
  String accessToken = '';
  bool loading = true;
  bool pageloading = true;
  bool loadingError = false;
  late PaypalServices services;
  double progress = 0;
  late final String returnURL;
  late final String cancelURL;

  late InAppWebViewController webView;

  bool _handledCancel = false;
  bool _handledSuccess = false;
  bool _locked = false;

  void triggerCancel() {
    // Do NOT cancel if success already triggered
    if (_handledSuccess) return;
    if (_handledCancel) return;

    _handledCancel = true;

    widget.onCancel();

    Future.microtask(() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Map getOrderParams() {
    // We'll pass application_context via transactions[0]['appContext']
    // to keep compatibility with the earlier createPaypalPayment signature.
    // Build minimal payload: add appContext with shipping_preference + return/cancel
    final appContext = {
      'shipping_preference': 'SET_PROVIDED_ADDRESS',
      'return_url': returnURL,
      'cancel_url': cancelURL,
      'user_action': 'PAY_NOW' // or 'CONTINUE' - PAY_NOW shows Pay Now button
    };

    // clone transactions so we can inject appContext into first transaction map
    if (widget.transactions != null && widget.transactions is List && widget.transactions!.isNotEmpty) {
      final List tx = List.from(widget.transactions!);
      final first = Map<String, dynamic>.from(tx[0]);
      first['appContext'] = appContext;
      tx[0] = first;
      return {
        'transactions': tx, // but createPaypalPayment expects the list directly, so we'll return tx
      };
    } else {
      // Fallback empty transaction with appContext
      return {
        'transactions': [
          {
            'amount': {'total': '0.00', 'currency': 'USD'},
            'appContext': appContext
          }
        ]
      };
    }
  }

  @override
  void initState() {
    returnURL = widget.returnUrl!;
    cancelURL = widget.cancelUrl!;

    services = PaypalServices(
      sandboxMode: widget.sandboxMode!,
      clientId: widget.clientId!,
      secretKey: widget.secretKey!,
    );

    super.initState();
    Future.delayed(Duration.zero, () async {
      try {
        final tokenResult = await services.getAccessToken();
        if (tokenResult['error'] == false && tokenResult['token'] != null) {
          accessToken = tokenResult['token'];

          // Build transactions list with appContext injected
          final orderParamsWrapper = getOrderParams();
          final txList = orderParamsWrapper['transactions'];

          // create v2 order
          final createRes = await services.createPaypalPayment(txList, accessToken);

          if (createRes['approveUrl'] != null && createRes['orderId'] != null) {
            setState(() {
              checkoutUrl = createRes['approveUrl'];
              executeUrl = createRes['orderId']; // here executeUrl stores orderId (used on return)
            });
          } else {
            widget.onError(createRes);
          }
        } else {
          widget.onError(tokenResult);
        }
      } catch (e) {
        widget.onError(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checkoutUrl != null) {
      return PopScope(
        canPop: !_locked,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && !_handledSuccess) {
            if (_handledCancel) return;
            _handledCancel = true;
            widget.onCancel();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !_locked,
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text("Paypal"),
          ),
          body: Stack(
            children: <Widget>[
              InAppWebView(
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url;
                  if (url == null) return NavigationActionPolicy.ALLOW;

                  final urlStr = url.toString();

                  // PayPal returns token=ORDERID for v2
                  if (urlStr.contains(returnURL)) {
                    // extract token param (orderId)
                    final orderId = url.queryParameters['token'] ?? url.queryParameters['orderId'] ?? url.queryParameters['paymentId'];
                    if (orderId != null && orderId.isNotEmpty) {
                      // capture the order
                      final captureRes = await services.executePayment(orderId, accessToken);
                      if (captureRes['error'] == false) {
                        if (!_handledSuccess) {
                          _handledSuccess = true;
                          widget.onSuccess(captureRes);
                        }
                      } else {
                        widget.onError(captureRes);
                      }
                    } else {
                      widget.onError('No order token found in return URL.');
                    }

                    // close the webview route
                    Future.microtask(() {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    });
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Cancel URL handling
                  if (urlStr.contains(cancelURL)) {
                    triggerCancel();
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },

                /// BLOCK BACK AFTER PAY CLICK
                onLoadStop: (controller, url) {
                  if (url != null && url.toString().contains("useraction=commit")) {
                    // PayPal enters final "processing…" screen
                    _locked = true;
                    setState(() {});
                  }
                },
                initialUrlRequest: URLRequest(url: WebUri(checkoutUrl!)),
                onWebViewCreated: (InAppWebViewController controller) {
                  webView = controller;
                },
                onCloseWindow: (InAppWebViewController controller) {
                  triggerCancel();
                },
                onProgressChanged: (InAppWebViewController controller, int prog) {
                  setState(() {
                    progress = prog / 100;
                  });
                },
                onUpdateVisitedHistory: (controller, url, _) async {
                  if (url != null && url.toString().contains(returnURL)) {
                    final orderId = url.queryParameters['token'] ?? url.queryParameters['orderId'] ?? url.queryParameters['paymentId'];
                    if (orderId != null && orderId.isNotEmpty) {
                      final captureRes = await services.executePayment(orderId, accessToken);
                      if (captureRes['error'] == false) {
                        if (!_handledSuccess) {
                          _handledSuccess = true;
                          widget.onSuccess(captureRes);
                        }
                      } else {
                        widget.onError(captureRes);
                      }
                    } else {
                      widget.onError('No order token found in return URL.');
                    }
                    Future.microtask(() {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    });
                  }
                },
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  clearSessionCache: true,
                  clearCache: true,
                  cacheEnabled: false,
                ),
              ),
              if (progress < 1) SizedBox(height: 3, child: LinearProgressIndicator(value: progress))
            ],
          ),
        ),
      );
    } else {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && !_handledSuccess) {
            if (_handledCancel) return;
            _handledCancel = true;
            widget.onCancel();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text("Paypal Payment"),
          ),
          body: Center(child: widget.loadingIndicator ?? const CircularProgressIndicator()),
        ),
      );
    }
  }
}