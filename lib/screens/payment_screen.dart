import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Payment Method')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CardField(
              onCardChanged: (card) {
                // Optional: Handle card input changes if needed
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handlePayment,
              child: Text('Save Payment Method'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              // Optional: Add billing details if needed
              name: 'John Doe', // Example
              email: 'john@example.com', // Example
            ),
          ),
        ),
      );
      // Successfully created payment method, proceed to store it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment method created: ${paymentMethod.id}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
