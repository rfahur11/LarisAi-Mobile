import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  int get subtotal => product.price * quantity;

  Map<String, dynamic> toCheckoutJson() {
    return {
      'product_id': product.id,
      'quantity': quantity,
    };
  }
}
