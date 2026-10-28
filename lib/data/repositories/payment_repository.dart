import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TestOrder {
  final String orderId;
  final String clientSecret;
  final int amountMinor;
  final String currency;
  const TestOrder(this.orderId, this.clientSecret, this.amountMinor, this.currency);
}

/// Stripe TEST mode only. The app sends ONLY the book id; the server decides the price.
class PaymentRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  PaymentRepository(this._functions, this._db);

  Future<TestOrder> createOrder(String bookId) async {
    final res = await _functions.httpsCallable('createOrder').call<Map<String, dynamic>>({'bookId': bookId});
    final d = res.data;
    if (d['testMode'] != true) {
      throw Exception('Server did not confirm test mode. Payment cancelled.');
    }
    return TestOrder(
      d['orderId'].toString(),
      d['clientSecret'].toString(),
      (d['amountMinor'] as num).toInt(),
      d['currency'].toString(),
    );
  }

  /// The ONLY source of truth for "paid": the order document written by the webhook.
  Stream<String> watchOrderStatus(String orderId) {
    return _db.doc('orders/$orderId').snapshots().map((s) => (s.data()?['status'] ?? 'pending').toString());
  }
}
