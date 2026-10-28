import 'package:flutter_test/flutter_test.dart';
import 'package:bookswaphub/data/models/book.dart';

void main() {
  test('Book.fromMap applies safe defaults for missing fields', () {
    final b = Book.fromMap('b1', {'title': 'Clean Code', 'ownerId': 'u1'});
    expect(b.id, 'b1');
    expect(b.author, '');
    expect(b.status, 'available');
    expect(b.listingType, 'swap');
    expect(b.price, isNull);
    expect(b.canSwap, isTrue);
    expect(b.canBuy, isFalse);
    expect(b.isAvailable, isTrue);
  });

  test('sale listings can be bought, reserved books are not available', () {
    final b = Book.fromMap('b2', {
      'title': 'X',
      'ownerId': 'u1',
      'listingType': 'both',
      'price': 250,
      'status': 'reserved',
    });
    expect(b.canBuy, isTrue);
    expect(b.canSwap, isTrue);
    expect(b.price, 250.0);
    expect(b.isAvailable, isFalse);
  });
}
