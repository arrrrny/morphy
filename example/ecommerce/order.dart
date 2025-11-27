import 'package:zikzak_morphy_annotation/zikzak_morphy_annotation.dart';

part 'order.morphy.dart';
part 'order.g.dart';

enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded
}

enum PaymentStatus { pending, authorized, captured, failed, refunded }

/// Order with complex nested structures demonstrating deep patches
@Morphy(generateJson: true)
abstract class $Order {
  String get id;
  String get customerId;
  List<$OrderItem> get items;
  $ShippingAddress get shippingAddress;
  $BillingAddress get billingAddress;
  Map<String, $PaymentMethod> get paymentMethods;
  double get subtotal;
  double get taxAmount;
  double get shippingCost;
  double get discount;
  double get totalAmount;
  OrderStatus get status;
  DateTime get createdAt;
  DateTime get updatedAt;
  String? get trackingNumber;
  Map<String, String> get metadata;

  /// Create order with calculated totals
  factory $Order.create({
    required String customerId,
    required List<OrderItem> items,
    required ShippingAddress shippingAddress,
    required BillingAddress billingAddress,
    String? promoCode,
  }) {
    final now = DateTime.now();
    final orderId = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

    // Calculate subtotal
    final subtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    // Calculate tax (8%)
    final taxAmount = subtotal * 0.08;

    // Calculate shipping based on total weight/volume
    final totalWeight = items.fold<double>(
      0.0,
      (sum, item) => sum + (item.weight * item.quantity),
    );
    final shippingCost = _calculateShippingCost(totalWeight);

    // Apply discount if promo code provided
    final discount = _calculateDiscount(subtotal, promoCode);

    // Calculate total
    final totalAmount = subtotal + taxAmount + shippingCost - discount;

    return Order._(
      id: orderId,
      customerId: customerId,
      items: items,
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      paymentMethods: {},
      subtotal: subtotal,
      taxAmount: taxAmount,
      shippingCost: shippingCost,
      discount: discount,
      totalAmount: totalAmount,
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
      trackingNumber: null,
      metadata: promoCode != null ? {'promo_code': promoCode} : {},
    );
  }

  static double _calculateShippingCost(double weight) {
    if (weight < 1) return 5.99;
    if (weight < 5) return 9.99;
    if (weight < 10) return 14.99;
    return 19.99 + (weight - 10) * 2.0;
  }

  static double _calculateDiscount(double subtotal, String? promoCode) {
    if (promoCode == null) return 0.0;

    switch (promoCode.toUpperCase()) {
      case 'SAVE10':
        return subtotal * 0.10;
      case 'SAVE20':
        return subtotal * 0.20;
      case 'FREESHIP':
        return 0.0; // Handled separately
      default:
        return 0.0;
    }
  }
}

@Morphy(generateJson: true)
abstract class $OrderItem {
  String get productId;
  String get productName;
  String get sku;
  int get quantity;
  double get unitPrice;
  double get totalPrice;
  double get weight;
  Map<String, String> get attributes;

  factory $OrderItem.create({
    required String productId,
    required String productName,
    required String sku,
    required int quantity,
    required double unitPrice,
    required double weight,
    Map<String, String> attributes = const {},
  }) {
    final totalPrice = unitPrice * quantity;

    return OrderItem._(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      weight: weight,
      attributes: attributes,
    );
  }
}

@Morphy(generateJson: true)
abstract class $ShippingAddress {
  String get recipientName;
  String get street;
  String get street2;
  String get city;
  String get state;
  String get zipCode;
  String get country;
  String get phone;

  factory $ShippingAddress.create({
    required String recipientName,
    required String street,
    String street2 = '',
    required String city,
    required String state,
    required String zipCode,
    String country = 'US',
    required String phone,
  }) {
    return ShippingAddress._(
      recipientName: recipientName,
      street: street,
      street2: street2,
      city: city,
      state: state,
      zipCode: zipCode,
      country: country,
      phone: phone,
    );
  }
}

@Morphy(generateJson: true)
abstract class $BillingAddress {
  String get name;
  String get street;
  String get street2;
  String get city;
  String get state;
  String get zipCode;
  String get country;

  factory $BillingAddress.create({
    required String name,
    required String street,
    String street2 = '',
    required String city,
    required String state,
    required String zipCode,
    String country = 'US',
  }) {
    return BillingAddress._(
      name: name,
      street: street,
      street2: street2,
      city: city,
      state: state,
      zipCode: zipCode,
      country: country,
    );
  }
}

@Morphy(generateJson: true)
abstract class $PaymentMethod {
  String get type; // 'card', 'paypal', 'bank_transfer'
  String get last4;
  String get brand;
  double get amount;
  PaymentStatus get status;
  DateTime get authorizedAt;
  DateTime? get capturedAt;

  factory $PaymentMethod.card({
    required String last4,
    required String brand,
    required double amount,
  }) {
    final now = DateTime.now();

    return PaymentMethod._(
      type: 'card',
      last4: last4,
      brand: brand,
      amount: amount,
      status: PaymentStatus.pending,
      authorizedAt: now,
      capturedAt: null,
    );
  }

  factory $PaymentMethod.paypal({
    required String email,
    required double amount,
  }) {
    final now = DateTime.now();
    final emailParts = email.split('@');
    final last4 = emailParts[0].length > 4
        ? emailParts[0].substring(emailParts[0].length - 4)
        : emailParts[0];

    return PaymentMethod._(
      type: 'paypal',
      last4: last4,
      brand: 'PayPal',
      amount: amount,
      status: PaymentStatus.pending,
      authorizedAt: now,
      capturedAt: null,
    );
  }
}

// Extension demonstrating complex order operations
extension OrderExtension on Order {
  /// Process payment and update order
  Order processPayment(String paymentId, PaymentMethod method) {
    // Use deep patch to update nested payment methods
    final orderPatch = OrderPatch.create()
      ..withStatus(OrderStatus.processing)
      ..withUpdatedAt(DateTime.now())
      ..updatePaymentMethodsValue(paymentId, (paymentPatch) {
        return paymentPatch
          ..withStatus(PaymentStatus.authorized)
          ..withCapturedAt(DateTime.now());
      });

    return orderPatch.applyTo(this);
  }

  /// Update shipping address
  Order updateShippingAddress({
    String? street,
    String? city,
    String? state,
    String? zipCode,
  }) {
    final patch = OrderPatch.create()
      ..withUpdatedAt(DateTime.now())
      ..withShippingAddressPatchFunc((addressPatch) {
        if (street != null) addressPatch.withStreet(street);
        if (city != null) addressPatch.withCity(city);
        if (state != null) addressPatch.withState(state);
        if (zipCode != null) addressPatch.withZipCode(zipCode);
        return addressPatch;
      });

    return patch.applyTo(this);
  }

  /// Update item quantity
  Order updateItemQuantity(int itemIndex, int newQuantity) {
    final item = items[itemIndex];
    final newTotalPrice = item.unitPrice * newQuantity;

    final patch = OrderPatch.create()
      ..withUpdatedAt(DateTime.now())
      ..updateItemsAt(itemIndex, (itemPatch) {
        return itemPatch
          ..withQuantity(newQuantity)
          ..withTotalPrice(newTotalPrice);
      });

    // Recalculate totals
    var updatedOrder = patch.applyTo(this);
    return updatedOrder._recalculateTotals();
  }

  /// Ship order with tracking
  Order ship(String trackingNumber) {
    final patch = OrderPatch.create()
      ..withStatus(OrderStatus.shipped)
      ..withTrackingNumber(trackingNumber)
      ..withUpdatedAt(DateTime.now());

    return patch.applyTo(this);
  }

  /// Cancel order
  Order cancel() {
    final patch = OrderPatch.create()
      ..withStatus(OrderStatus.cancelled)
      ..withUpdatedAt(DateTime.now());

    return patch.applyTo(this);
  }

  /// Private method to recalculate totals
  Order _recalculateTotals() {
    final newSubtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final newTaxAmount = newSubtotal * 0.08;
    final newTotalAmount = newSubtotal + newTaxAmount + shippingCost - discount;

    return copyWithOrderFn(
      subtotal: () => newSubtotal,
      taxAmount: () => newTaxAmount,
      totalAmount: () => newTotalAmount,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Get order summary
  String get summary {
    final itemCount = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return 'Order $id: $itemCount items, \$${totalAmount.toStringAsFixed(2)} - $status';
  }

  /// Check if order can be cancelled
  bool get canBeCancelled {
    return status == OrderStatus.pending || status == OrderStatus.processing;
  }

  /// Check if order can be modified
  bool get canBeModified {
    return status == OrderStatus.pending;
  }
}
