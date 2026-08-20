/// A catalog item from the shared vaxilifecorp backend.
///
/// This intentionally omits the deal/promo-tier pricing fields the live API
/// also returns (`withdeals`, `lowestprice`, tiered free-quantity discounts)
/// — that's a separate pricing-rules feature, not part of "add to cart".
/// Cart lines here always use the item's plain `itemprice`.
class Item {
  const Item({
    required this.id,
    required this.itemcode,
    required this.itemname,
    required this.itemdescription,
    required this.description,
    required this.itemimagepath,
    required this.itemprice,
    required this.category,
  });

  final int id;
  final String itemcode;
  final String itemname;
  final String itemdescription;
  final String description;
  final String itemimagepath;
  final double itemprice;
  final String category;

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as int? ?? 0,
      itemcode: json['itemcode']?.toString() ?? '',
      itemname: json['itemname']?.toString() ?? '',
      itemdescription: json['itemdescription']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      itemimagepath: json['itemimagepath']?.toString() ?? '',
      itemprice: (json['itemprice'] as num?)?.toDouble() ?? 0,
      category: json['category']?.toString() ?? '',
    );
  }
}
