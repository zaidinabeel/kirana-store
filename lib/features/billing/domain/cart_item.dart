import 'package:decimal/decimal.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money_utils.dart';

class CartItem {
  final String id;
  final String? productId;
  final String nameSnapshotEn;
  final String? nameSnapshotHi;
  final String? hsnSnapshot;
  final String unit;
  final Decimal rate;
  final Decimal qty;
  final Decimal gstRate;
  final Decimal discount;
  final bool isLoose;

  CartItem({
    required this.id,
    this.productId,
    required this.nameSnapshotEn,
    this.nameSnapshotHi,
    this.hsnSnapshot,
    required this.unit,
    required this.rate,
    required this.qty,
    required this.gstRate,
    Decimal? discount,
    this.isLoose = false,
  }) : discount = discount ?? Decimal.zero;

  Decimal get lineTotal => MoneyUtils.computeLineTotal(
        rate: rate,
        qty: qty,
        discount: discount,
      );

  String displayName(bool isHindi) {
    if (isHindi && nameSnapshotHi != null && nameSnapshotHi!.isNotEmpty) {
      return nameSnapshotHi!;
    }
    return nameSnapshotEn;
  }

  CartItem copyWith({
    String? id,
    String? productId,
    String? nameSnapshotEn,
    String? nameSnapshotHi,
    String? hsnSnapshot,
    String? unit,
    Decimal? rate,
    Decimal? qty,
    Decimal? gstRate,
    Decimal? discount,
    bool? isLoose,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      nameSnapshotEn: nameSnapshotEn ?? this.nameSnapshotEn,
      nameSnapshotHi: nameSnapshotHi ?? this.nameSnapshotHi,
      hsnSnapshot: hsnSnapshot ?? this.hsnSnapshot,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      qty: qty ?? this.qty,
      gstRate: gstRate ?? this.gstRate,
      discount: discount ?? this.discount,
      isLoose: isLoose ?? this.isLoose,
    );
  }

  factory CartItem.fromProduct(Product product, {Decimal? initialQty}) {
    return CartItem(
      id: product.id,
      productId: product.id,
      nameSnapshotEn: product.nameEn,
      nameSnapshotHi: product.nameHi,
      hsnSnapshot: product.hsnCode,
      unit: product.unit,
      rate: MoneyUtils.parse(product.price),
      qty: initialQty ?? (product.itemType == 'loose' ? Decimal.one : Decimal.one),
      gstRate: MoneyUtils.parse(product.gstRate),
      isLoose: product.itemType == 'loose',
    );
  }
}
