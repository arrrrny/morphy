import 'package:zikzak_morphy_annotation/zikzak_morphy_annotation.dart';

part 'customer.morphy.dart';
part 'customer.g.dart';

enum CustomerTier { bronze, silver, gold, platinum }

/// Generic preference system showcasing generic types
@Morphy(generateJson: true)
abstract class $Preference<T> {
  String get key;
  T get value;
  DateTime get updatedAt;
  String get category;

  factory $Preference.create(String key, T value, String category) {
    return Preference<T>._(
      key: key,
      value: value,
      updatedAt: DateTime.now(),
      category: category,
    );
  }
}

/// Customer with generic preferences
@Morphy(generateJson: true)
abstract class $Customer {
  String get id;
  String get email;
  String get firstName;
  String get lastName;
  CustomerTier get tier;
  $Preference<String> get language;
  $Preference<String> get currency;
  $Preference<bool> get marketingEmails;
  $Preference<bool> get smsNotifications;
  $Preference<List<String>> get favoriteCategories;
  $Preference<Map<String, int>> get notificationSettings;
  Map<String, $Address> get savedAddresses;
  List<String> get orderHistory;
  double get lifetimeValue;
  int get loyaltyPoints;
  DateTime get createdAt;
  DateTime get lastLoginAt;

  factory $Customer.create({
    required String email,
    required String firstName,
    required String lastName,
  }) {
    final now = DateTime.now();
    final customerId = 'CUST-${now.millisecondsSinceEpoch}';

    return Customer._(
      id: customerId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      tier: CustomerTier.bronze,
      language: Preference<String>.create('language', 'en', 'localization'),
      currency: Preference<String>.create('currency', 'USD', 'localization'),
      marketingEmails: Preference<bool>.create('marketing_emails', false, 'communication'),
      smsNotifications: Preference<bool>.create('sms_notifications', false, 'communication'),
      favoriteCategories: Preference<List<String>>.create('favorite_categories', [], 'personalization'),
      notificationSettings: Preference<Map<String, int>>.create(
        'notifications',
        {'order': 1, 'shipping': 1, 'marketing': 0, 'account': 1},
        'communication',
      ),
      savedAddresses: {},
      orderHistory: [],
      lifetimeValue: 0.0,
      loyaltyPoints: 0,
      createdAt: now,
      lastLoginAt: now,
    );
  }

  /// Import customer from legacy system
  factory $Customer.fromLegacy(Map<String, dynamic> data) {
    final now = DateTime.now();

    // Parse preferences from legacy format
    final prefs = data['preferences'] as Map<String, dynamic>? ?? {};

    return Customer._(
      id: 'CUST-${data['id']}',
      email: data['email'] as String,
      firstName: data['first_name'] as String,
      lastName: data['last_name'] as String,
      tier: CustomerTier.values.firstWhere(
        (t) => t.toString().split('.').last == data['tier'],
        orElse: () => CustomerTier.bronze,
      ),
      language: Preference<String>.create(
        'language',
        prefs['lang'] as String? ?? 'en',
        'localization',
      ),
      currency: Preference<String>.create(
        'currency',
        prefs['curr'] as String? ?? 'USD',
        'localization',
      ),
      marketingEmails: Preference<bool>.create(
        'marketing_emails',
        prefs['marketing'] as bool? ?? false,
        'communication',
      ),
      smsNotifications: Preference<bool>.create(
        'sms_notifications',
        prefs['sms'] as bool? ?? false,
        'communication',
      ),
      favoriteCategories: Preference<List<String>>.create(
        'favorite_categories',
        List<String>.from(prefs['favorites'] ?? []),
        'personalization',
      ),
      notificationSettings: Preference<Map<String, int>>.create(
        'notifications',
        Map<String, int>.from(prefs['notifications'] ?? {}),
        'communication',
      ),
      savedAddresses: {},
      orderHistory: List<String>.from(data['orders'] ?? []),
      lifetimeValue: (data['lifetime_value'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: data['points'] as int? ?? 0,
      createdAt: DateTime.parse(data['created_at'] as String),
      lastLoginAt: now,
    );
  }
}

@Morphy(generateJson: true)
abstract class $Address {
  String get name;
  String get street;
  String get street2;
  String get city;
  String get state;
  String get zipCode;
  String get country;
  String get phone;
  bool get isDefault;

  factory $Address.create({
    required String name,
    required String street,
    String street2 = '',
    required String city,
    required String state,
    required String zipCode,
    String country = 'US',
    required String phone,
    bool isDefault = false,
  }) {
    return Address._(
      name: name,
      street: street,
      street2: street2,
      city: city,
      state: state,
      zipCode: zipCode,
      country: country,
      phone: phone,
      isDefault: isDefault,
    );
  }
}

/// Generic shopping cart
@Morphy(generateJson: true)
abstract class $Cart<TItem> {
  String get customerId;
  List<TItem> get items;
  DateTime get createdAt;
  DateTime get updatedAt;
  String? get sessionId;

  factory $Cart.create(String customerId) {
    final now = DateTime.now();
    return Cart<TItem>._(
      customerId: customerId,
      items: [],
      createdAt: now,
      updatedAt: now,
      sessionId: null,
    );
  }
}

@Morphy(generateJson: true)
abstract class $CartItem {
  String get productId;
  String get productName;
  int get quantity;
  double get price;
  Map<String, String> get selectedOptions;

  factory $CartItem.create({
    required String productId,
    required String productName,
    required int quantity,
    required double price,
    Map<String, String> selectedOptions = const {},
  }) {
    return CartItem._(
      productId: productId,
      productName: productName,
      quantity: quantity,
      price: price,
      selectedOptions: selectedOptions,
    );
  }
}

// Extensions for customer operations
extension CustomerExtension on Customer {
  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Update preference with type safety
  Customer updatePreference<T>({
    Preference<String>? language,
    Preference<bool>? marketingEmails,
    Preference<List<String>>? favoriteCategories,
  }) {
    final patch = CustomerPatch.create()
      ..withLastLoginAt(DateTime.now());

    if (language != null) {
      patch.withLanguage(language);
    }
    if (marketingEmails != null) {
      patch.withMarketingEmails(marketingEmails);
    }
    if (favoriteCategories != null) {
      patch.withFavoriteCategories(favoriteCategories);
    }

    return patch.applyTo(this);
  }

  /// Add favorite category
  Customer addFavoriteCategory(String category) {
    final now = DateTime.now();
    final updatedCategories = [...favoriteCategories.value, category];

    return copyWithCustomerFn(
      favoriteCategories: () => Preference<List<String>>._(
        key: 'favorite_categories',
        value: updatedCategories,
        updatedAt: now,
        category: 'personalization',
      ),
      lastLoginAt: () => now,
    );
  }

  /// Update tier based on lifetime value
  Customer updateTier() {
    final newTier = lifetimeValue >= 5000
        ? CustomerTier.platinum
        : lifetimeValue >= 2000
            ? CustomerTier.gold
            : lifetimeValue >= 500
                ? CustomerTier.silver
                : CustomerTier.bronze;

    if (newTier == tier) return this;

    return copyWithCustomerFn(
      tier: () => newTier,
      lastLoginAt: () => DateTime.now(),
    );
  }

  /// Add loyalty points
  Customer addLoyaltyPoints(int points) {
    return copyWithCustomerFn(
      loyaltyPoints: () => loyaltyPoints + points,
      lastLoginAt: () => DateTime.now(),
    );
  }

  /// Add order to history
  Customer addOrder(String orderId, double orderTotal) {
    final now = DateTime.now();
    final newLifetimeValue = lifetimeValue + orderTotal;
    final pointsEarned = (orderTotal * 10).toInt(); // 10 points per dollar

    return copyWithCustomerFn(
      orderHistory: () => [...orderHistory, orderId],
      lifetimeValue: () => newLifetimeValue,
      loyaltyPoints: () => loyaltyPoints + pointsEarned,
      lastLoginAt: () => now,
    );
  }

  /// Save address
  Customer saveAddress(String key, Address address) {
    final newAddresses = {...savedAddresses, key: address};

    return copyWithCustomerFn(
      savedAddresses: () => newAddresses,
      lastLoginAt: () => DateTime.now(),
    );
  }

  /// Get tier benefits
  String get tierBenefits {
    switch (tier) {
      case CustomerTier.platinum:
        return 'Free shipping, 20% off, early access, dedicated support';
      case CustomerTier.gold:
        return 'Free shipping, 15% off, early access';
      case CustomerTier.silver:
        return 'Free shipping on orders > \$50, 10% off';
      case CustomerTier.bronze:
        return '5% off on first order';
    }
  }

  /// Calculate discount percentage
  double get tierDiscountPercent {
    switch (tier) {
      case CustomerTier.platinum:
        return 0.20;
      case CustomerTier.gold:
        return 0.15;
      case CustomerTier.silver:
        return 0.10;
      case CustomerTier.bronze:
        return 0.05;
    }
  }

  /// Check if notification type is enabled
  bool isNotificationEnabled(String type) {
    return (notificationSettings.value[type] ?? 0) > 0;
  }
}

extension CartExtension<T> on Cart<T> {
  /// Get total items
  int get totalItems => items.length;
}

extension CartItemCartExtension on Cart<CartItem> {
  /// Calculate total
  double get total {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  /// Add item to cart
  Cart<CartItem> addItem(CartItem item) {
    return copyWithCartFn(
      items: () => [...items, item],
      updatedAt: () => DateTime.now(),
    );
  }

  /// Remove item from cart
  Cart<CartItem> removeItem(int index) {
    final newItems = [...items];
    newItems.removeAt(index);

    return copyWithCartFn(
      items: () => newItems,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Update item quantity
  Cart<CartItem> updateQuantity(int index, int quantity) {
    final newItems = [...items];
    newItems[index] = newItems[index].copyWithCartItemFn(
      quantity: () => quantity,
    );

    return copyWithCartFn(
      items: () => newItems,
      updatedAt: () => DateTime.now(),
    );
  }
}
