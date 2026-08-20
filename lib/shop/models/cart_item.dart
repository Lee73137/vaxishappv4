import 'item.dart';

class CartItem {
  CartItem({
    required this.item,
    required this.quantity,
    this.freeQty = 0,
    double? unitPrice,
  }) : unitPrice = unitPrice ?? item.itemprice;

  final Item item;
  int quantity;
  int freeQty;

  /// The price actually charged per unit for this cart line — may differ
  /// from [Item.itemprice] (the plain catalog price) if a quantity-tier
  /// discount applied when this line was added.
  double unitPrice;

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap(String username) => {
    'username': username,
    'itemcode': item.itemcode,
    'itemname': item.itemname,
    'itemdescription': item.itemdescription,
    'description': item.description,
    'itemimagepath': item.itemimagepath,
    'itemprice': item.itemprice,
    'category': item.category,
    'quantity': quantity,
    'freeQty': freeQty,
    'unitPrice': unitPrice,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      item: Item(
        id: 0,
        itemcode: map['itemcode']?.toString() ?? '',
        itemname: map['itemname']?.toString() ?? '',
        itemdescription: map['itemdescription']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        itemimagepath: map['itemimagepath']?.toString() ?? '',
        itemprice: (map['itemprice'] as num?)?.toDouble() ?? 0,
        category: map['category']?.toString() ?? '',
      ),
      quantity: map['quantity'] as int? ?? 1,
      freeQty: map['freeQty'] as int? ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
    );
  }
}
