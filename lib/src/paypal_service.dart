// import 'dart:convert';
//
// import 'package:dio/dio.dart';
//
// import 'dart:async';
// import 'dart:convert' as convert;
//
// class PaypalServices {
//   final String clientId, secretKey;
//   final bool sandboxMode;
//   PaypalServices({
//     required this.clientId,
//     required this.secretKey,
//     required this.sandboxMode,
//   });
//
//   getAccessToken() async {
//     String baseUrl = sandboxMode
//         ? "https://api-m.sandbox.paypal.com"
//         : "https://api.paypal.com";
//
//     try {
//       var authToken = base64.encode(
//         utf8.encode("$clientId:$secretKey"),
//       );
//       final response = await Dio()
//           .post('$baseUrl/v1/oauth2/token?grant_type=client_credentials',
//               options: Options(
//                 headers: {
//                   'Authorization': 'Basic $authToken',
//                   'Content-Type': 'application/x-www-form-urlencoded'
//                 },
//               ));
//       final body = response.data;
//       return {
//         'error': false,
//         'message': "Success",
//         'token': body["access_token"]
//       };
//     } on DioException {
//       return {
//         'error': true,
//         'message': "Your PayPal credentials seems incorrect"
//       };
//     } catch (e) {
//       return {
//         'error': true,
//         'message': "Unable to proceed, check your internet connection."
//       };
//     }
//   }
//
//   Future<Map> createPaypalPayment(
//     transactions,
//     accessToken,
//   ) async {
//     String domain = sandboxMode
//         ? "https://api.sandbox.paypal.com"
//         : "https://api.paypal.com";
//
//     try {
//       final response = await Dio().post('$domain/v1/payments/payment',
//           data: jsonEncode(transactions),
//           options: Options(
//             headers: {
//               'Authorization': 'Bearer $accessToken',
//               'Content-Type': 'application/json'
//             },
//           ));
//
//       final body = response.data;
//       if (body["links"] != null && body["links"].length > 0) {
//         List links = body["links"];
//
//         String executeUrl = "";
//         String approvalUrl = "";
//         final item = links.firstWhere((o) => o["rel"] == "approval_url",
//             orElse: () => null);
//         if (item != null) {
//           approvalUrl = item["href"];
//         }
//         final item1 =
//             links.firstWhere((o) => o["rel"] == "execute", orElse: () => null);
//         if (item1 != null) {
//           executeUrl = item1["href"];
//         }
//         return {"executeUrl": executeUrl, "approvalUrl": approvalUrl};
//       }
//       return {};
//     } on DioException catch (e) {
//       return {
//         'error': true,
//         'message': "Payment Failed.",
//         'data': e.response?.data,
//       };
//     } catch (e) {
//       rethrow;
//     }
//   }
//
//   Future<Map> executePayment(
//     url,
//     payerId,
//     accessToken,
//   ) async {
//     try {
//       final response = await Dio().post(url,
//           data: convert.jsonEncode({"payer_id": payerId}),
//           options: Options(
//             headers: {
//               'Authorization': 'Bearer $accessToken',
//               'Content-Type': 'application/json'
//             },
//           ));
//
//       final body = response.data;
//       return {'error': false, 'message': "Success", 'data': body};
//     } on DioException catch (e) {
//       return {
//         'error': true,
//         'message': "Payment Failed.",
//         'data': e.response?.data,
//       };
//     } catch (e) {
//       return {'error': true, 'message': e, 'exception': true, 'data': null};
//     }
//   }
// }

// paypal_service.dart  (v2)
import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:async';

class PaypalServices {
  final String clientId, secretKey;
  final bool sandboxMode;
  PaypalServices({
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
  });

  Future<Map> getAccessToken() async {
    String baseUrl = sandboxMode
        ? "https://api-m.sandbox.paypal.com"
        : "https://api.paypal.com";

    try {
      var authToken = base64.encode(
        utf8.encode("$clientId:$secretKey"),
      );
      final response = await Dio().post(
        '$baseUrl/v1/oauth2/token',
        data: 'grant_type=client_credentials',
        options: Options(
          headers: {
            'Authorization': 'Basic $authToken',
            'Content-Type': 'application/x-www-form-urlencoded'
          },
        ),
      );

      final body = response.data;
      return {
        'error': false,
        'message': "Success",
        'token': body["access_token"]
      };
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Your PayPal credentials seem incorrect",
        'data': e.response?.data
      };
    } catch (e) {
      return {
        'error': true,
        'message': "Unable to proceed, check your internet connection.",
        'data': e.toString()
      };
    }
  }

  /// Creates an order (v2) and returns { "approveUrl": "...", "orderId": "..." }
  Future<Map> createPaypalPayment(dynamic transactionsPayload, String accessToken) async {
    // transactionsPayload is the same widget.transactions you pass in.
    // We'll convert it into v2 purchase_units below.
    String domain = sandboxMode
        ? "https://api-m.sandbox.paypal.com"
        : "https://api-m.paypal.com";

    try {
      // Build purchase_units from the incoming transactions (best-effort mapping).
      // Expect transactionsPayload to be a List with one entry containing amount.total and details.
      List purchaseUnits = [];
      if (transactionsPayload is List && transactionsPayload.isNotEmpty) {
        final t = transactionsPayload[0];
        final amount = t['amount'] ?? {};
        final total = amount['total']?.toString() ?? amount.toString();
        final currency = amount['currency'] ?? 'USD';

        Map breakdown = {};
        if (amount['details'] != null) {
          final d = amount['details'];
          breakdown = {
            'item_total': {'currency_code': currency, 'value': (d['subtotal'] ?? total).toString()},
            'shipping': {'currency_code': currency, 'value': (d['shipping'] ?? '0').toString()},
            'shipping_discount': {'currency_code': currency, 'value': (d['shipping_discount'] ?? '0').toString()},
          };
        }

        Map shipping = {};
        if (t['shipping_address'] != null) {
          final s = t['shipping_address'];
          shipping = {
            'name': {
              'full_name': s['recipient_name'] ?? ''
            },
            'address': {
              'address_line_1': s['line1'] ?? '',
              'address_line_2': s['line2'] ?? '',
              'admin_area_2': s['city'] ?? '',
              'admin_area_1': s['state'] ?? '',
              'postal_code': s['postal_code'] ?? '',
              'country_code': s['country_code'] ?? ''
            }
          };
        }

        purchaseUnits.add({
          'amount': {
            'currency_code': currency,
            'value': total.toString(),
            if (breakdown.isNotEmpty) 'breakdown': breakdown,
          },
          if (shipping.isNotEmpty) 'shipping': shipping,
          'description': t['description'] ?? ''
        });
      } else {
        // Fallback: empty single purchase unit
        purchaseUnits.add({
          'amount': {'currency_code': 'USD', 'value': '0.00'}
        });
      }

      // The caller must supply return_url and cancel_url inside transactionsPayload?
      // We'll expect they are provided as widget.returnUrl / cancelUrl at view layer; we'll pass them via transactionsPayload wrapper.
      // However to keep method signature unchanged, the create call in view will set application_context via a wrapper "appContext" on transactionsPayload or we add placeholders - view passes return/cancel via PaypalCheckoutView's returnURL/cancelURL variables.

      // If caller passed a "appContext" map inside transactionsPayload[0], use it.
      Map? appContext;
      try {
        // transactionsPayload may include an appContext property in first element
        if (transactionsPayload is List && transactionsPayload.isNotEmpty && transactionsPayload[0] is Map && transactionsPayload[0]['appContext'] != null) {
          appContext = Map<String, dynamic>.from(transactionsPayload[0]['appContext']);
        }
      } catch (_) {}

      final body = {
        'intent': 'CAPTURE',
        'purchase_units': purchaseUnits,
        // application_context must include return/cancel and shipping_preference
        'application_context': appContext ??
            {
              'shipping_preference': 'SET_PROVIDED_ADDRESS',
              // return/cancel will be set by the caller: we prefer the view to inject correct URLs via appContext
            }
      };

      final response = await Dio().post('$domain/v2/checkout/orders',
          data: jsonEncode(body),
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json'
            },
          ));

      final resBody = response.data;

      // pick the approve link
      String approveUrl = '';
      if (resBody['links'] != null && resBody['links'] is List) {
        final links = List.from(resBody['links']);
        final item = links.firstWhere((l) => l['rel'] == 'approve', orElse: () => null);
        if (item != null) approveUrl = item['href'];
      }

      return {'orderId': resBody['id'], 'approveUrl': approveUrl};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Order creation failed.",
        'data': e.response?.data,
      };
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }

  /// Capture an order by orderId (v2)
  Future<Map> executePayment(String orderId, String accessToken) async {
    String domain = sandboxMode
        ? "https://api-m.sandbox.paypal.com"
        : "https://api-m.paypal.com";

    try {
      final response = await Dio().post('$domain/v2/checkout/orders/$orderId/capture',
          options: Options(headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          }));

      final body = response.data;
      return {'error': false, 'message': 'Success', 'data': body};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Capture failed.",
        'data': e.response?.data,
      };
    } catch (e) {
      return {'error': true, 'message': e.toString()};
    }
  }
}