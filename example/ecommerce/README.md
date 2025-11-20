# Morphy E-Commerce Example Suite

This comprehensive example suite demonstrates **ALL** Morphy features in real-world e-commerce scenarios.

## 🎯 What's Included

### 1. **product.dart** - Polymorphic Products
Demonstrates:
- ✅ Sealed classes with `$$` prefix
- ✅ **Curly brace factories** with complex initialization logic
- ✅ Explicit subtypes for type transformations
- ✅ Multiple product types (Physical, Digital, Subscription)
- ✅ Computed values in factory methods
- ✅ Extension methods for utilities

**Key Features:**
- `PhysicalProduct.create()` - Curly brace factory with ID generation
- `PhysicalProduct.fromWarehouse()` - Complex data transformation
- `DigitalProduct.create()` - Price-based tier calculation
- `SubscriptionProduct.monthly/annual()` - Discount calculations
- Polymorphic product handling with pattern matching

### 2. **order.dart** - Complex Nested Structures
Demonstrates:
- ✅ Deep nested object structures
- ✅ **Patch-based deep updates** (updatePaymentMethodsValue, withShippingAddressPatchFunc)
- ✅ Curly brace factories with multi-step calculations
- ✅ Complex business logic (tax, shipping, discounts)
- ✅ Extension methods for operations

**Key Features:**
- `Order.create()` - Multi-step total calculations
- Deep nested patches for updating orders
- Recalculation on item quantity changes
- Order lifecycle management

### 3. **customer.dart** - Generic Types
Demonstrates:
- ✅ **Generic types** (`Preference<T>`, `Cart<T>`)
- ✅ Type-safe preference system
- ✅ Generic cart implementation
- ✅ Curly brace factories with legacy data import
- ✅ Complex customer operations

**Key Features:**
- `Preference<T>` - Generic preference values
- `Cart<TItem>` - Generic shopping cart
- `Customer.fromLegacy()` - Complex data migration
- Tier-based benefits and discounts
- Loyalty points system

### 4. **category.dart** - Self-Referencing Trees
Demonstrates:
- ✅ **Self-referencing structures** (`$Category? parent`, `List<$Category> children`)
- ✅ Recursive operations
- ✅ Tree traversal and manipulation
- ✅ Curly brace factories for hierarchy creation

**Key Features:**
- `Category.root()` - Create root categories
- `Category.subcategory()` - Build hierarchy
- `Category.fromPath()` - Create from path array
- Tree operations (find, traverse, reorder)
- Breadcrumb navigation

### 5. **ecommerce_demo.dart** - Complete Integration
Demonstrates:
- ✅ All features working together
- ✅ Real-world workflows
- ✅ Customer lifecycle
- ✅ Order processing
- ✅ JSON serialization
- ✅ Type transformations

## 🚀 Running the Demo

```bash
# From the repository root
cd example/ecommerce

# Generate code
dart run build_runner build

# Run the demo
dart run ecommerce_demo.dart
```

## 📖 Feature Showcase

### Curly Brace Factories (NEW in v2.9.0)

```dart
factory $PhysicalProduct.create({
  required String name,
  required double price,
  required double weight,
}) {
  final now = DateTime.now();
  final generatedSku = 'PHYS-${now.millisecondsSinceEpoch}';
  final productId = 'PROD-${now.millisecondsSinceEpoch}';

  return PhysicalProduct._(
    id: productId,
    sku: generatedSku,
    name: name,
    basePrice: price,
    weight: weight,
    createdAt: now,
    updatedAt: now,
    // ... more fields
  );
}
```

### Polymorphic Products

```dart
// Sealed base class
@Morphy(explicitSubTypes: [$PhysicalProduct, $DigitalProduct])
abstract class $$Product { ... }

// Concrete implementations
abstract class $PhysicalProduct implements $$Product { ... }
abstract class $DigitalProduct implements $$Product { ... }

// Pattern matching
switch (product) {
  case PhysicalProduct p:
    print('Ship ${p.weight}kg');
  case DigitalProduct d:
    print('Download ${d.downloadUrl}');
}
```

### Generic Types

```dart
// Generic preference
@Morphy()
abstract class $Preference<T> {
  T get value;
}

// Usage with type safety
Preference<String> language;
Preference<bool> marketingEmails;
Preference<List<String>> categories;
Preference<Map<String, int>> settings;
```

### Deep Nested Patches

```dart
// Update nested structures
final orderPatch = OrderPatch.create()
  ..withStatus(OrderStatus.processing)
  ..withShippingAddressPatchFunc((addressPatch) => addressPatch
    ..withStreet('New Street')
    ..withCity('New City'))
  ..updatePaymentMethodsValue('card_1', (paymentPatch) => paymentPatch
    ..withStatus(PaymentStatus.captured));

final updatedOrder = orderPatch.applyTo(order);
```

### Self-Referencing Trees

```dart
// Build category hierarchy
var electronics = Category.root(name: 'Electronics');
electronics = electronics.addChild(
  Category.subcategory(parent: electronics, name: 'Computers')
);

// Navigate tree
print(category.fullPath);  // "Electronics > Computers > Laptops"
final breadcrumbs = category.breadcrumbs;
final descendants = category.allDescendants;
```

### Explicit Subtypes

```dart
// Transform generic to specific
Product genericProduct = Product.fromJson(json);

PhysicalProduct physical = genericProduct.changeToPhysicalProduct(
  weight: 1.5,
  sku: 'SKU-123',
  stockQuantity: 100,
);
```

## 📚 Learning Path

1. **Start with product.dart** - Learn polymorphism and curly brace factories
2. **Move to customer.dart** - Understand generic types
3. **Explore order.dart** - Master deep nested updates
4. **Study category.dart** - Learn self-referencing structures
5. **Run ecommerce_demo.dart** - See it all working together

## 🎓 Real-World Applications

These patterns are production-ready and can be used for:

- **E-commerce platforms** - Products, orders, customers
- **Content management** - Categories, articles, media
- **SaaS applications** - Subscriptions, features, users
- **Social networks** - Posts, comments, users
- **Enterprise software** - Complex domain models

## 💡 Tips

1. **Use sealed classes (`$$`)** for type-safe polymorphism
2. **Use curly brace factories** for complex initialization
3. **Use generic types** for reusable components
4. **Use patches** for complex nested updates
5. **Use explicit subtypes** for type transformations

## 🔗 More Resources

- [Main README](../../README.md)
- [CHANGELOG](../../CHANGELOG.md)
- [Morphy v3.0.0 Proposal](../../MORPHY_V3_PROPOSAL.md)
