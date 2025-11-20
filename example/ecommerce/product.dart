import 'package:zikzak_morphy_annotation/zikzak_morphy_annotation.dart';

part 'product.morphy.dart';
part 'product.g.dart';

enum ProductStatus { draft, active, archived, outOfStock }

/// Base sealed product class demonstrating polymorphism
@Morphy(generateJson: true, explicitSubTypes: [
  $PhysicalProduct,
  $DigitalProduct,
  $SubscriptionProduct,
])
abstract class $$Product {
  String get id;
  String get name;
  String get description;
  double get basePrice;
  ProductStatus get status;
  List<String> get tags;
  DateTime get createdAt;
  DateTime get updatedAt;
}

/// Physical product with shipping properties
@Morphy(generateJson: true)
abstract class $PhysicalProduct implements $$Product {
  double get weight; // in kg
  $Dimensions get dimensions;
  String get sku;
  int get stockQuantity;
  String get warehouse;

  /// Create a physical product with curly brace factory
  factory $PhysicalProduct.create({
    required String name,
    required String description,
    required double price,
    required double weight,
    required Dimensions dimensions,
    String? sku,
  }) {
    final now = DateTime.now();
    final generatedSku = sku ?? 'PHYS-${now.millisecondsSinceEpoch}';
    final productId = 'PROD-${now.millisecondsSinceEpoch}';

    return PhysicalProduct._(
      id: productId,
      name: name,
      description: description,
      basePrice: price,
      status: ProductStatus.draft,
      tags: ['physical'],
      createdAt: now,
      updatedAt: now,
      weight: weight,
      dimensions: dimensions,
      sku: generatedSku,
      stockQuantity: 0,
      warehouse: 'default',
    );
  }

  /// Import from external system
  factory $PhysicalProduct.fromWarehouse({
    required Map<String, dynamic> warehouseData,
  }) {
    final now = DateTime.now();
    final price = (warehouseData['price_cents'] as int) / 100.0;
    final weight = (warehouseData['weight_grams'] as int) / 1000.0;

    return PhysicalProduct._(
      id: 'PROD-${warehouseData['id']}',
      name: warehouseData['name'] as String,
      description: warehouseData['description'] as String? ?? '',
      basePrice: price,
      status: ProductStatus.active,
      tags: List<String>.from(warehouseData['tags'] ?? []),
      createdAt: DateTime.parse(warehouseData['created_at']),
      updatedAt: now,
      weight: weight,
      dimensions: Dimensions._(
        length: (warehouseData['length_cm'] as num).toDouble(),
        width: (warehouseData['width_cm'] as num).toDouble(),
        height: (warehouseData['height_cm'] as num).toDouble(),
      ),
      sku: warehouseData['sku'] as String,
      stockQuantity: warehouseData['stock'] as int,
      warehouse: warehouseData['warehouse_code'] as String? ?? 'default',
    );
  }
}

/// Digital product with download properties
@Morphy(generateJson: true)
abstract class $DigitalProduct implements $$Product {
  String get downloadUrl;
  int get fileSizeBytes;
  String get fileFormat;
  Duration get accessDuration;
  int get maxDownloads;

  /// Create digital product with computed values
  factory $DigitalProduct.create({
    required String name,
    required String description,
    required double price,
    required String downloadUrl,
    required String fileFormat,
    int? fileSizeBytes,
  }) {
    final now = DateTime.now();
    final productId = 'DIGI-${now.millisecondsSinceEpoch}';

    // Default access duration based on price tier
    final accessDuration = price > 50
        ? const Duration(days: 365) // Premium: 1 year
        : price > 20
            ? const Duration(days: 180) // Standard: 6 months
            : const Duration(days: 30); // Basic: 1 month

    // Max downloads based on price
    final maxDownloads = price > 50 ? 10 : price > 20 ? 5 : 3;

    return DigitalProduct._(
      id: productId,
      name: name,
      description: description,
      basePrice: price,
      status: ProductStatus.active,
      tags: ['digital', fileFormat.toLowerCase()],
      createdAt: now,
      updatedAt: now,
      downloadUrl: downloadUrl,
      fileSizeBytes: fileSizeBytes ?? 0,
      fileFormat: fileFormat,
      accessDuration: accessDuration,
      maxDownloads: maxDownloads,
    );
  }
}

/// Subscription product with recurring billing
@Morphy(generateJson: true)
abstract class $SubscriptionProduct implements $$Product {
  Duration get billingInterval;
  int get trialDays;
  double get setupFee;
  bool get autoRenew;
  Map<String, $Feature> get features;

  /// Create monthly subscription
  factory $SubscriptionProduct.monthly({
    required String name,
    required String description,
    required double monthlyPrice,
    int trialDays = 14,
    List<Feature> features = const [],
  }) {
    final now = DateTime.now();
    final productId = 'SUB-M-${now.millisecondsSinceEpoch}';

    // Convert feature list to map
    final featureMap = <String, Feature>{};
    for (var i = 0; i < features.length; i++) {
      featureMap['feature_$i'] = features[i];
    }

    return SubscriptionProduct._(
      id: productId,
      name: '$name (Monthly)',
      description: description,
      basePrice: monthlyPrice,
      status: ProductStatus.active,
      tags: ['subscription', 'monthly'],
      createdAt: now,
      updatedAt: now,
      billingInterval: const Duration(days: 30),
      trialDays: trialDays,
      setupFee: 0.0,
      autoRenew: true,
      features: featureMap,
    );
  }

  /// Create annual subscription with discount
  factory $SubscriptionProduct.annual({
    required String name,
    required String description,
    required double monthlyPrice,
    double discountPercent = 20.0,
    int trialDays = 30,
    List<Feature> features = const [],
  }) {
    final now = DateTime.now();
    final productId = 'SUB-A-${now.millisecondsSinceEpoch}';

    // Calculate annual price with discount
    final annualPrice = monthlyPrice * 12 * (1 - discountPercent / 100);
    final monthlySavings = monthlyPrice - (annualPrice / 12);

    // Convert feature list to map
    final featureMap = <String, Feature>{};
    for (var i = 0; i < features.length; i++) {
      featureMap['feature_$i'] = features[i];
    }

    return SubscriptionProduct._(
      id: productId,
      name: '$name (Annual - Save ${discountPercent.toInt()}%)',
      description: '$description\n\nSave \$${monthlySavings.toStringAsFixed(2)}/month!',
      basePrice: annualPrice,
      status: ProductStatus.active,
      tags: ['subscription', 'annual', 'best-value'],
      createdAt: now,
      updatedAt: now,
      billingInterval: const Duration(days: 365),
      trialDays: trialDays,
      setupFee: 0.0,
      autoRenew: true,
      features: featureMap,
    );
  }
}

/// Supporting models
@Morphy(generateJson: true)
abstract class $Dimensions {
  double get length; // cm
  double get width; // cm
  double get height; // cm
}

@Morphy(generateJson: true)
abstract class $Feature {
  String get name;
  String get description;
  bool get enabled;

  factory $Feature.create(String name, String description) {
    return Feature._(
      name: name,
      description: description,
      enabled: true,
    );
  }
}

// Extension methods for product utilities
extension ProductExtension on Product {
  /// Calculate final price with tax
  double get priceWithTax {
    return basePrice * 1.08; // 8% tax
  }

  /// Check if product is available
  bool get isAvailable {
    return status == ProductStatus.active;
  }

  /// Get display price
  String get displayPrice {
    return '\$${basePrice.toStringAsFixed(2)}';
  }
}

extension PhysicalProductExtension on PhysicalProduct {
  /// Calculate shipping cost based on weight
  double get shippingCost {
    if (weight < 1) return 5.99;
    if (weight < 5) return 9.99;
    if (weight < 10) return 14.99;
    return 19.99 + (weight - 10) * 2.0;
  }

  /// Calculate volumetric weight
  double get volumetricWeight {
    final volume = dimensions.length * dimensions.width * dimensions.height;
    return volume / 5000; // Standard volumetric divisor
  }

  /// Check if in stock
  bool get inStock => stockQuantity > 0;
}

extension DigitalProductExtension on DigitalProduct {
  /// Get file size in MB
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  /// Format file size
  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if access is unlimited
  bool get hasUnlimitedDownloads => maxDownloads >= 999;
}

extension SubscriptionProductExtension on SubscriptionProduct {
  /// Get monthly price (even for annual)
  double get effectiveMonthlyPrice {
    final months = billingInterval.inDays / 30;
    return basePrice / months;
  }

  /// Calculate savings for annual vs monthly
  double calculateSavingsVs(double monthlyPrice) {
    final annualMonthlyPrice = effectiveMonthlyPrice;
    return (monthlyPrice - annualMonthlyPrice) * 12;
  }

  /// Check if has trial
  bool get hasTrial => trialDays > 0;

  /// Get feature count
  int get featureCount => features.length;
}
