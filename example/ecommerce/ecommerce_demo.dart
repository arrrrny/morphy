/// Comprehensive E-Commerce Demo
///
/// This demo showcases ALL Morphy features in real-world scenarios:
/// - Polymorphic products (sealed classes with $$)
/// - Curly brace factories with complex logic
/// - Generic types (Preference<T>, Cart<T>)
/// - Explicit subtypes for type transformations
/// - Deep nested updates with patches
/// - Self-referencing trees (categories)
/// - JSON serialization
/// - Multiple inheritance
///
/// Run: dart run example/ecommerce/ecommerce_demo.dart

import 'product.dart';
import 'order.dart';
import 'customer.dart';
import 'category.dart';

void main() {
  print('═══════════════════════════════════════════════════════════');
  print('  Morphy E-Commerce Demo - ALL Features Showcase');
  print('═══════════════════════════════════════════════════════════\n');

  // 1. POLYMORPHIC PRODUCTS (Sealed Classes)
  print('1️⃣  POLYMORPHIC PRODUCTS (Sealed Classes with $$)');
  print('─────────────────────────────────────────────────────────────');

  final physicalProduct = PhysicalProduct.create(
    name: 'Wireless Headphones',
    description: 'Premium noise-cancelling headphones',
    price: 299.99,
    weight: 0.5,
    dimensions: Dimensions._(length: 20, width: 15, height: 10),
    sku: 'HEAD-001',
  );

  final digitalProduct = DigitalProduct.create(
    name: 'E-Book: Dart Mastery',
    description: 'Complete guide to Dart programming',
    price: 29.99,
    downloadUrl: 'https://example.com/downloads/dart-mastery.pdf',
    fileFormat: 'PDF',
    fileSizeBytes: 5242880, // 5 MB
  );

  final monthlySubscription = SubscriptionProduct.monthly(
    name: 'Premium Music Streaming',
    description: 'Unlimited music, ad-free',
    monthlyPrice: 9.99,
    features: [
      Feature.create('Unlimited Skips', 'Skip as many songs as you want'),
      Feature.create('Offline Mode', 'Download for offline listening'),
      Feature.create('High Quality', 'Stream in HD quality'),
    ],
  );

  final annualSubscription = SubscriptionProduct.annual(
    name: 'Premium Music Streaming',
    description: 'Unlimited music, ad-free',
    monthlyPrice: 9.99,
    discountPercent: 20.0,
    trialDays: 30,
    features: [
      Feature.create('Unlimited Skips', 'Skip as many songs as you want'),
      Feature.create('Offline Mode', 'Download for offline listening'),
      Feature.create('High Quality', 'Stream in HD quality'),
      Feature.create('Family Sharing', 'Share with up to 6 family members'),
    ],
  );

  print('Physical: ${physicalProduct.name} - \$${physicalProduct.basePrice}');
  print('  Weight: ${physicalProduct.weight}kg, Shipping: \$${physicalProduct.shippingCost}');
  print('  Stock: ${physicalProduct.stockQuantity}, SKU: ${physicalProduct.sku}');

  print('\nDigital: ${digitalProduct.name} - \$${digitalProduct.basePrice}');
  print('  Format: ${digitalProduct.fileFormat}, Size: ${digitalProduct.formattedFileSize}');
  print('  Access: ${digitalProduct.accessDuration.inDays} days, Max Downloads: ${digitalProduct.maxDownloads}');

  print('\nMonthly Sub: ${monthlySubscription.name} - \$${monthlySubscription.basePrice}/month');
  print('  Trial: ${monthlySubscription.trialDays} days, Features: ${monthlySubscription.featureCount}');

  print('\nAnnual Sub: ${annualSubscription.name} - \$${annualSubscription.basePrice}/year');
  print('  Effective Monthly: \$${annualSubscription.effectiveMonthlyPrice.toStringAsFixed(2)}');
  print('  Annual Savings: \$${annualSubscription.calculateSavingsVs(9.99).toStringAsFixed(2)}');
  print('  Trial: ${annualSubscription.trialDays} days, Features: ${annualSubscription.featureCount}');

  // Polymorphic handling
  print('\nPolymorphic Product Handling:');
  final products = <Product>[
    physicalProduct,
    digitalProduct,
    monthlySubscription,
  ];

  for (var product in products) {
    switch (product) {
      case PhysicalProduct p:
        print('  📦 ${p.name}: Ship ${p.weight}kg for \$${p.shippingCost}');
      case DigitalProduct d:
        print('  💾 ${d.name}: Download ${d.formattedFileSize}');
      case SubscriptionProduct s:
        print('  🔄 ${s.name}: Bill \$${s.basePrice} every ${s.billingInterval.inDays} days');
    }
  }

  // 2. CURLY BRACE FACTORIES WITH COMPLEX LOGIC
  print('\n2️⃣  CURLY BRACE FACTORIES (Complex Initialization)');
  print('─────────────────────────────────────────────────────────────');

  // Import from external warehouse system
  final warehouseProduct = PhysicalProduct.fromWarehouse(
    warehouseData: {
      'id': '12345',
      'name': 'Smart Watch',
      'description': 'Fitness tracking smartwatch',
      'price_cents': 19999,
      'weight_grams': 250,
      'length_cm': 5,
      'width_cm': 4,
      'height_cm': 1,
      'sku': 'WATCH-001',
      'stock': 50,
      'warehouse_code': 'US-WEST',
      'tags': ['electronics', 'wearables'],
      'created_at': '2024-01-01T00:00:00Z',
    },
  );

  print('Imported: ${warehouseProduct.name}');
  print('  Price: \$${warehouseProduct.basePrice} (from ${19999} cents)');
  print('  Weight: ${warehouseProduct.weight}kg (from ${250}g)');
  print('  Warehouse: ${warehouseProduct.warehouse}');

  // 3. GENERIC TYPES (Preference<T>, Cart<T>)
  print('\n3️⃣  GENERIC TYPES (Type-Safe Preferences)');
  print('─────────────────────────────────────────────────────────────');

  var customer = Customer.create(
    email: 'alice@example.com',
    firstName: 'Alice',
    lastName: 'Johnson',
  );

  print('Customer: ${customer.fullName} (${customer.tier})');
  print('  Language: ${customer.language.value}');
  print('  Currency: ${customer.currency.value}');
  print('  Marketing Emails: ${customer.marketingEmails.value}');
  print('  Notifications: ${customer.notificationSettings.value}');

  // Add favorite categories with type safety
  customer = customer.addFavoriteCategory('Electronics');
  customer = customer.addFavoriteCategory('Books');

  print('\nUpdated Favorites: ${customer.favoriteCategories.value}');

  // Generic cart
  final cart = Cart<CartItem>.create(customer.id);
  var updatedCart = cart
      .addItem(CartItem.create(
        productId: physicalProduct.id,
        productName: physicalProduct.name,
        quantity: 1,
        price: physicalProduct.basePrice,
      ))
      .addItem(CartItem.create(
        productId: digitalProduct.id,
        productName: digitalProduct.name,
        quantity: 1,
        price: digitalProduct.basePrice,
      ));

  print('\nCart: ${updatedCart.totalItems} items, Total: \$${updatedCart.total.toStringAsFixed(2)}');

  // 4. DEEP NESTED UPDATES WITH PATCHES
  print('\n4️⃣  DEEP NESTED UPDATES (Patch System)');
  print('─────────────────────────────────────────────────────────────');

  var order = Order.create(
    customerId: customer.id,
    items: [
      OrderItem.create(
        productId: physicalProduct.id,
        productName: physicalProduct.name,
        sku: physicalProduct.sku,
        quantity: 2,
        unitPrice: physicalProduct.basePrice,
        weight: physicalProduct.weight,
      ),
      OrderItem.create(
        productId: digitalProduct.id,
        productName: digitalProduct.name,
        sku: 'EBOOK-001',
        quantity: 1,
        unitPrice: digitalProduct.basePrice,
        weight: 0,
      ),
    ],
    shippingAddress: ShippingAddress.create(
      recipientName: customer.fullName,
      street: '123 Main St',
      city: 'San Francisco',
      state: 'CA',
      zipCode: '94102',
      phone: '555-1234',
    ),
    billingAddress: BillingAddress.create(
      name: customer.fullName,
      street: '123 Main St',
      city: 'San Francisco',
      state: 'CA',
      zipCode: '94102',
    ),
    promoCode: 'SAVE10',
  );

  print('Order Created: ${order.id}');
  print('  Subtotal: \$${order.subtotal.toStringAsFixed(2)}');
  print('  Tax: \$${order.taxAmount.toStringAsFixed(2)}');
  print('  Shipping: \$${order.shippingCost.toStringAsFixed(2)}');
  print('  Discount: -\$${order.discount.toStringAsFixed(2)}');
  print('  Total: \$${order.totalAmount.toStringAsFixed(2)}');
  print('  Status: ${order.status}');

  // Deep nested patch: Update shipping address
  order = order.updateShippingAddress(
    street: '456 Oak Ave',
    city: 'Los Angeles',
    zipCode: '90001',
  );

  print('\nAfter Address Update:');
  print('  Shipping to: ${order.shippingAddress.street}, ${order.shippingAddress.city}');

  // Process payment with nested patch
  final payment = PaymentMethod.card(
    last4: '4242',
    brand: 'Visa',
    amount: order.totalAmount,
  );

  order = order.processPayment('payment_1', payment);
  print('\nAfter Payment:');
  print('  Status: ${order.status}');
  print('  Payment: ${order.paymentMethods['payment_1']?.status}');

  // Update item quantity (recalculates totals)
  order = order.updateItemQuantity(0, 3); // Change first item quantity from 2 to 3
  print('\nAfter Quantity Update:');
  print('  Items[0] Quantity: ${order.items[0].quantity}');
  print('  New Subtotal: \$${order.subtotal.toStringAsFixed(2)}');
  print('  New Total: \$${order.totalAmount.toStringAsFixed(2)}');

  // Ship order
  order = order.ship('TRACKING-123456');
  print('\nAfter Shipping:');
  print('  Status: ${order.status}');
  print('  Tracking: ${order.trackingNumber}');

  // 5. SELF-REFERENCING TREES (Categories)
  print('\n5️⃣  SELF-REFERENCING TREES (Category Hierarchy)');
  print('─────────────────────────────────────────────────────────────');

  // Build category tree
  var electronics = Category.root(
    name: 'Electronics',
    description: 'All electronic products',
  );

  electronics = electronics.addChild(
    Category.subcategory(
      parent: electronics,
      name: 'Computers',
      description: 'Desktop and laptop computers',
    ),
  );

  final computers = electronics.children[0];
  var updatedComputers = computers
      .addChild(Category.subcategory(
        parent: computers,
        name: 'Laptops',
      ))
      .addChild(Category.subcategory(
        parent: computers,
        name: 'Desktops',
      ));

  // Update the electronics category with updated computers
  electronics = electronics.copyWithCategoryFn(
    children: () => [updatedComputers],
  );

  electronics = electronics.addChild(
    Category.subcategory(
      parent: electronics,
      name: 'Audio',
      description: 'Headphones, speakers, and more',
    ),
  );

  print('Category Tree:');
  print(electronics.toTreeString());

  print('Category Details:');
  print('  Root: ${electronics.name} (Level ${electronics.level})');
  print('  Total Categories: ${1 + electronics.allDescendants.length}');
  print('  Tree Depth: ${electronics.depth}');
  print('  Is Leaf: ${electronics.isLeaf}');

  final laptopsCategory = electronics.findByName('Laptops').first;
  print('\nFound Category: ${laptopsCategory.name}');
  print('  Full Path: ${laptopsCategory.fullPath}');
  print('  Breadcrumbs: ${laptopsCategory.breadcrumbs.map((c) => c.name).join(' > ')}');

  // Add products to category
  final updatedLaptops = laptopsCategory
      .addProduct(physicalProduct.id)
      .addProduct(warehouseProduct.id);

  print('  Products: ${updatedLaptops.productIds.length}');

  // 6. EXPLICIT SUBTYPES (Type Transformations)
  print('\n6️⃣  EXPLICIT SUBTYPES (Type Transformations)');
  print('─────────────────────────────────────────────────────────────');

  // Start with generic Product
  Product genericProduct = Product.fromJson({
    'id': 'PROD-999',
    'name': 'Mystery Product',
    'description': 'Could be anything',
    'basePrice': 99.99,
    'status': 'active',
    'tags': [],
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  });

  print('Generic Product: ${genericProduct.name}');

  // Transform to specific type using changeTo
  final specificPhysical = genericProduct.changeToPhysicalProduct(
    weight: 1.5,
    dimensions: Dimensions._(length: 30, width: 20, height: 10),
    sku: 'SKU-999',
    stockQuantity: 100,
    warehouse: 'US-EAST',
  );

  print('Transformed to Physical:');
  print('  Name: ${specificPhysical.name}');
  print('  Weight: ${specificPhysical.weight}kg');
  print('  Stock: ${specificPhysical.stockQuantity}');
  print('  Shipping Cost: \$${specificPhysical.shippingCost}');

  // 7. JSON SERIALIZATION
  print('\n7️⃣  JSON SERIALIZATION (Round-trip)');
  print('─────────────────────────────────────────────────────────────');

  final productJson = physicalProduct.toJson();
  print('Product to JSON:');
  print('  Keys: ${productJson.keys.join(', ')}');

  final restoredProduct = PhysicalProduct.fromJson(productJson);
  print('\nRestored from JSON:');
  print('  Name: ${restoredProduct.name}');
  print('  Price: \$${restoredProduct.basePrice}');
  print('  Equals Original: ${restoredProduct == physicalProduct}');

  // 8. CUSTOMER LIFECYCLE
  print('\n8️⃣  CUSTOMER LIFECYCLE (Complete Flow)');
  print('─────────────────────────────────────────────────────────────');

  print('Initial Customer:');
  print('  Tier: ${customer.tier} - ${customer.tierBenefits}');
  print('  Lifetime Value: \$${customer.lifetimeValue.toStringAsFixed(2)}');
  print('  Loyalty Points: ${customer.loyaltyPoints}');

  // Customer places order
  customer = customer.addOrder(order.id, order.totalAmount);
  print('\nAfter First Order:');
  print('  Lifetime Value: \$${customer.lifetimeValue.toStringAsFixed(2)}');
  print('  Loyalty Points: ${customer.loyaltyPoints}');
  print('  Order History: ${customer.orderHistory.length} orders');

  // Simulate more orders to upgrade tier
  customer = customer.addOrder('ORD-002', 500.00);
  customer = customer.addOrder('ORD-003', 750.00);
  customer = customer.updateTier();

  print('\nAfter Multiple Orders:');
  print('  New Tier: ${customer.tier} - ${customer.tierBenefits}');
  print('  Lifetime Value: \$${customer.lifetimeValue.toStringAsFixed(2)}');
  print('  Loyalty Points: ${customer.loyaltyPoints}');
  print('  Discount: ${(customer.tierDiscountPercent * 100).toStringAsFixed(0)}%');

  print('\n═══════════════════════════════════════════════════════════');
  print('  Demo Complete! All Morphy Features Demonstrated ✓');
  print('═══════════════════════════════════════════════════════════');
}
