
# Flutter PayPal Payment Package

The **Flutter PayPal Payment Package** provides an easy-to-integrate solution for enabling PayPal payments in your Flutter mobile application. This package allows for a seamless checkout experience with both sandbox and production environments.

## Features

- **Seamless PayPal Integration**: Easily integrate PayPal payments into your Flutter app.
- **Sandbox Mode Support**: Test payments in a safe sandbox environment before going live.
- **Customizable Transactions**: Define custom transaction details for each payment.
- **Payment Outcome Callbacks**: Handle success, error, and cancellation events for payments.

## Installation

To install the Flutter PayPal Payment Checkout Package, follow these steps

1. Add the package to your project's dependencies in the `pubspec.yaml` file:
   ```yaml
   dependencies:
      flutter_paypal_payment:
         git:
            url: https://github.com/BunnyBuddy/flutter_paypal_payment_checkout
            ref: main
    ``` 
2. Run the following command to fetch the package:

    ``` 
    flutter pub get
    ``` 

## Usage
1. Import the package:

    ``` 
    import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
    ```
2. Navigate to the PayPal checkout screen:
```dart

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaypalCheckoutView(
      sandboxMode: true, // set false for production
      clientId: "YOUR_PAYPAL_CLIENT_ID",
      secretKey: "YOUR_PAYPAL_SECRET_KEY",

      returnUrl: "https://example.com/paypal/return",
      cancelUrl: "https://example.com/paypal/cancel",

      note: "Order payment",

      transactions: [
        {
          "amount": {
            "total": "50.00",
            "currency": "USD",
            "details": {
              "subtotal": "50.00",
              "shipping": "0",
              "shipping_discount": 0
            }
          },
          "description": "Example order payment",

          // Optional: provide shipping address
          "shipping_address": {
            "recipient_name": "John Doe",
            "line1": "123 Main Street",
            "line2": "Apt 4B",
            "city": "New York",
            "state": "NY",
            "postal_code": "10001",
            "country_code": "US",
            "phone": "+11234567890"
          },

          "shipping_preference": "SET_PROVIDED_ADDRESS"
        }
      ],

      onSuccess: (Map params) async {
        print("Payment success: $params");
      },

      onError: (error) {
        print("Payment error: $error");
      },

      onCancel: () {
        print("Payment cancelled");
      },
    ),
  ),
);
``` 
