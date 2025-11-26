// library flutter_paypal_checkout;
//
// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter_paypal_payment/src/paypal_service.dart';
//
// class PaypalCheckoutView extends StatefulWidget {
//   final Function onSuccess, onCancel, onError;
//   final String? note, clientId, secretKey;
//   final String? returnUrl;
//   final String? cancelUrl;
//
//   final Widget? loadingIndicator;
//   final List? transactions;
//   final bool? sandboxMode;
//
//   const PaypalCheckoutView({
//     Key? key,
//     required this.onSuccess,
//     required this.onError,
//     required this.onCancel,
//     required this.transactions,
//     required this.clientId,
//     required this.secretKey,
//     this.sandboxMode = false,
//     this.note = '',
//     this.returnUrl,
//     this.cancelUrl,
//     this.loadingIndicator,
//   }) : super(key: key);
//
//   @override
//   State<StatefulWidget> createState() {
//     return PaypalCheckoutViewState();
//   }
// }
//
// class PaypalCheckoutViewState extends State<PaypalCheckoutView> {
//   String? checkoutUrl;
//   String navUrl = '';
//   String executeUrl = '';
//   String accessToken = '';
//   bool loading = true;
//   bool pageloading = true;
//   bool loadingError = false;
//   late PaypalServices services;
//   int pressed = 0;
//   double progress = 0;
//   late final String returnURL;
//   late final String cancelURL;
//
//   late InAppWebViewController webView;
//
//   bool _handledCancel = false;
//
//   void triggerCancel() {
//     if (_handledCancel) return;
//     _handledCancel = true;
//
//     widget.onCancel();
//
//     Future.microtask(() {
//       if (Navigator.of(context).canPop()) {
//         Navigator.of(context).pop();
//       }
//     });
//   }
//
//
//   Map getOrderParams() {
//     Map<String, dynamic> temp = {
//       "intent": "sale",
//       "payer": {"payment_method": "paypal"},
//       "transactions": widget.transactions,
//       "note_to_payer": widget.note,
//       "redirect_urls": {
//         "return_url": returnURL,
//         "cancel_url": cancelURL,
//       }
//     };
//     return temp;
//   }
//
//   @override
//   void initState() {
//     returnURL = widget.returnUrl!;
//     cancelURL = widget.cancelUrl!;
//
//     services = PaypalServices(
//       sandboxMode: widget.sandboxMode!,
//       clientId: widget.clientId!,
//       secretKey: widget.secretKey!,
//     );
//
//     super.initState();
//     Future.delayed(Duration.zero, () async {
//       try {
//         Map getToken = await services.getAccessToken();
//
//         if (getToken['token'] != null) {
//           accessToken = getToken['token'];
//           final body = getOrderParams();
//           final res = await services.createPaypalPayment(body, accessToken);
//
//           if (res["approvalUrl"] != null) {
//             setState(() {
//               checkoutUrl = res["approvalUrl"];
//               executeUrl = res["executeUrl"];
//             });
//           } else {
//             widget.onError(res);
//           }
//         } else {
//           widget.onError("${getToken['message']}");
//         }
//       } catch (e) {
//         widget.onError(e);
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (checkoutUrl != null) {
//       return PopScope(
//         canPop: true,
//         onPopInvokedWithResult: (didPop, result) {
//           if (didPop) {
//             // widget.onCancel();
//             triggerCancel();
//           }
//         },
//         child: Scaffold(
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             centerTitle: true,
//             title: const Text(
//               "Paypal",
//             ),
//           ),
//           body: Stack(
//             children: <Widget>[
//               InAppWebView(
//                 shouldOverrideUrlLoading: (controller, navigationAction) async {
//                   final url = navigationAction.request.url;
//
//                   if (url != null && url.host.contains("inspireuplift.com") && url.path.contains("/mobile/paypal/return")) {
//                     exceutePayment(url, context);
//                     return NavigationActionPolicy.CANCEL;
//                   }
//                   if (url.toString().contains(cancelURL)) {
//                     // widget.onCancel();
//                     triggerCancel();
//                     return NavigationActionPolicy.CANCEL;
//                   } else {
//                     return NavigationActionPolicy.ALLOW;
//                   }
//                 },
//                 initialUrlRequest: URLRequest(url: WebUri(checkoutUrl!)),
//                 onWebViewCreated: (InAppWebViewController controller) {
//                   webView = controller;
//                 },
//                 onCloseWindow: (InAppWebViewController controller) {
//                   // widget.onCancel();
//                   triggerCancel();
//                   Navigator.of(context).pop();
//                 },
//                 onProgressChanged: (InAppWebViewController controller, int progress) {
//                   setState(() {
//                     this.progress = progress / 100;
//                   });
//                 },
//                 onUpdateVisitedHistory: (controller, url, _) {
//                   if (url != null && url.toString().contains(returnURL)) {
//                     exceutePayment(url, context);
//                     Navigator.pop(context);
//                   }
//                 },
//                 initialSettings: InAppWebViewSettings(
//                   useShouldOverrideUrlLoading: true,
//                 ),
//               ),
//               progress < 1
//                   ? SizedBox(
//                       height: 3,
//                       child: LinearProgressIndicator(
//                         value: progress,
//                       ),
//                     )
//                   : const SizedBox(),
//             ],
//           ),
//         ),
//       );
//     } else {
//       return PopScope(
//         canPop: true,
//         onPopInvokedWithResult: (didPop, result) {
//           if (didPop) {
//             // widget.onCancel();
//             triggerCancel();
//           }
//         },
//         child: Scaffold(
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             centerTitle: true,
//             title: const Text(
//               "Paypal",
//             ),
//           ),
//           body: Center(child: widget.loadingIndicator ?? const CircularProgressIndicator()),
//         ),
//       );
//     }
//   }
//
//   void exceutePayment(Uri? url, BuildContext context) {
//     final payerID = url!.queryParameters['PayerID'];
//     if (payerID != null) {
//       services.executePayment(executeUrl, payerID, accessToken).then(
//         (id) {
//           if (id['error'] == false) {
//             widget.onSuccess(id); // send data to your Dart code
//             // Navigator.of(context).pop(); // CLOSE the PayPal WebView
//           } else {
//             widget.onError(id);
//             // Navigator.of(context).pop();
//           }
//         },
//       );
//     } else {
//       widget.onError('Something went wront PayerID == null');
//     }
//   }
// }

// paypal_checkout_view.dart (v2)
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

  void triggerCancel() {
    if (_handledCancel) return;
    _handledCancel = true;

    // cleanup callback (does NOT pop)
    widget.onCancel();

    // close route, but after current event loop to avoid debugLocked
    Future.microtask(() {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
      return {'transactions': [ {'amount': {'total': '0.00', 'currency': 'USD'}, 'appContext': appContext } ]};
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
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            triggerCancel();
          }
        },
        child: Scaffold(
          appBar: AppBar(
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
                        widget.onSuccess(captureRes);
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
                        widget.onSuccess(captureRes);
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
                ),
              ),
              if (progress < 1)
                SizedBox(height: 3, child: LinearProgressIndicator(value: progress))
            ],
          ),
        ),
      );
    } else {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            triggerCancel();
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