import 'package:zikzak_morphy_annotation/zikzak_morphy_annotation.dart';

part 'category.morphy.dart';
part 'category.g.dart';

/// Self-referencing category tree demonstrating recursive structures
@Morphy(generateJson: true)
abstract class $Category {
  String get id;
  String get name;
  String get slug;
  String get description;
  $Category? get parent;
  List<$Category> get children;
  int get level;
  int get sortOrder;
  List<String> get productIds;
  String? get imageUrl;
  Map<String, String> get metadata;
  bool get isActive;
  DateTime get createdAt;
  DateTime get updatedAt;

  /// Create root category
  factory $Category.root({
    required String name,
    String description = '',
    String? imageUrl,
  }) {
    final now = DateTime.now();
    final slug = _generateSlug(name);
    final categoryId = 'CAT-${now.millisecondsSinceEpoch}';

    return Category._(
      id: categoryId,
      name: name,
      slug: slug,
      description: description,
      parent: null,
      children: [],
      level: 0,
      sortOrder: 0,
      productIds: [],
      imageUrl: imageUrl,
      metadata: {},
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create subcategory
  factory $Category.subcategory({
    required Category parent,
    required String name,
    String description = '',
    String? imageUrl,
  }) {
    final now = DateTime.now();
    final slug = '${parent.slug}/${_generateSlug(name)}';
    final categoryId = 'CAT-${now.millisecondsSinceEpoch}';

    return Category._(
      id: categoryId,
      name: name,
      slug: slug,
      description: description,
      parent: parent,
      children: [],
      level: parent.level + 1,
      sortOrder: parent.children.length,
      productIds: [],
      imageUrl: imageUrl,
      metadata: {},
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create category hierarchy from path
  factory $Category.fromPath({
    required List<String> path,
    String description = '',
  }) {
    if (path.isEmpty) {
      throw ArgumentError('Path cannot be empty');
    }

    // Create root category
    Category? current = Category.root(name: path[0], description: description);

    // Create subcategories
    for (int i = 1; i < path.length; i++) {
      final child = Category.subcategory(
        parent: current,
        name: path[i],
        description: description,
      );

      // Update parent's children
      current = current.copyWithCategoryFn(
        children: () => [...current!.children, child],
        updatedAt: () => DateTime.now(),
      );

      current = child;
    }

    return current;
  }

  static String _generateSlug(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Category with featured products
@Morphy(generateJson: true)
abstract class $FeaturedCategory implements $Category {
  List<String> get featuredProductIds;
  String get bannerUrl;
  String? get promoText;
  DateTime? get promoStartDate;
  DateTime? get promoEndDate;

  factory $FeaturedCategory.create({
    required Category baseCategory,
    required List<String> featuredProductIds,
    required String bannerUrl,
    String? promoText,
    DateTime? promoStartDate,
    DateTime? promoEndDate,
  }) {
    final now = DateTime.now();

    return FeaturedCategory._(
      id: baseCategory.id,
      name: baseCategory.name,
      slug: baseCategory.slug,
      description: baseCategory.description,
      parent: baseCategory.parent,
      children: baseCategory.children,
      level: baseCategory.level,
      sortOrder: baseCategory.sortOrder,
      productIds: baseCategory.productIds,
      imageUrl: baseCategory.imageUrl,
      metadata: baseCategory.metadata,
      isActive: baseCategory.isActive,
      createdAt: baseCategory.createdAt,
      updatedAt: now,
      featuredProductIds: featuredProductIds,
      bannerUrl: bannerUrl,
      promoText: promoText,
      promoStartDate: promoStartDate,
      promoEndDate: promoEndDate,
    );
  }
}

// Extensions for category operations
extension CategoryExtension on Category {
  /// Get full path
  String get fullPath {
    if (parent == null) return name;
    return '${parent!.fullPath} > $name';
  }

  /// Get breadcrumb list
  List<Category> get breadcrumbs {
    final List<Category> result = [];
    Category? current = this;

    while (current != null) {
      result.insert(0, current);
      current = current.parent;
    }

    return result;
  }

  /// Get root category
  Category get root {
    Category current = this;
    while (current.parent != null) {
      current = current.parent!;
    }
    return current;
  }

  /// Check if is leaf category
  bool get isLeaf => children.isEmpty;

  /// Check if has products
  bool get hasProducts => productIds.isNotEmpty;

  /// Get total product count (including children)
  int get totalProductCount {
    int count = productIds.length;
    for (var child in children) {
      count += child.totalProductCount;
    }
    return count;
  }

  /// Add child category
  Category addChild(Category child) {
    // Update child to set this as parent
    final updatedChild = child.copyWithCategoryFn(
      parent: () => this,
      level: () => level + 1,
      sortOrder: () => children.length,
      updatedAt: () => DateTime.now(),
    );

    // Add to children
    return copyWithCategoryFn(
      children: () => [...children, updatedChild],
      updatedAt: () => DateTime.now(),
    );
  }

  /// Remove child category
  Category removeChild(String childId) {
    final newChildren = children.where((c) => c.id != childId).toList();

    // Reorder remaining children
    final reorderedChildren = <Category>[];
    for (int i = 0; i < newChildren.length; i++) {
      reorderedChildren.add(
        newChildren[i].copyWithCategoryFn(
          sortOrder: () => i,
        ),
      );
    }

    return copyWithCategoryFn(
      children: () => reorderedChildren,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Add product
  Category addProduct(String productId) {
    if (productIds.contains(productId)) return this;

    return copyWithCategoryFn(
      productIds: () => [...productIds, productId],
      updatedAt: () => DateTime.now(),
    );
  }

  /// Remove product
  Category removeProduct(String productId) {
    return copyWithCategoryFn(
      productIds: () => productIds.where((id) => id != productId).toList(),
      updatedAt: () => DateTime.now(),
    );
  }

  /// Move to new parent
  Category moveTo(Category newParent) {
    return copyWithCategoryFn(
      parent: () => newParent,
      level: () => newParent.level + 1,
      slug: () => '${newParent.slug}/${name.toLowerCase().replaceAll(' ', '-')}',
      sortOrder: () => newParent.children.length,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Reorder children
  Category reorderChildren(List<String> orderedIds) {
    final childMap = {for (var child in children) child.id: child};
    final reordered = <Category>[];

    for (int i = 0; i < orderedIds.length; i++) {
      final child = childMap[orderedIds[i]];
      if (child != null) {
        reordered.add(
          child.copyWithCategoryFn(
            sortOrder: () => i,
          ),
        );
      }
    }

    return copyWithCategoryFn(
      children: () => reordered,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Find category by ID in tree
  Category? findById(String categoryId) {
    if (id == categoryId) return this;

    for (var child in children) {
      final found = child.findById(categoryId);
      if (found != null) return found;
    }

    return null;
  }

  /// Find categories by name pattern
  List<Category> findByName(String pattern) {
    final results = <Category>[];
    final regex = RegExp(pattern, caseSensitive: false);

    if (regex.hasMatch(name)) {
      results.add(this);
    }

    for (var child in children) {
      results.addAll(child.findByName(pattern));
    }

    return results;
  }

  /// Get all descendant categories (flattened)
  List<Category> get allDescendants {
    final List<Category> result = [];

    for (var child in children) {
      result.add(child);
      result.addAll(child.allDescendants);
    }

    return result;
  }

  /// Get tree depth
  int get depth {
    if (children.isEmpty) return 0;
    return 1 + children.map((c) => c.depth).reduce((a, b) => a > b ? a : b);
  }

  /// Activate/deactivate category and all children
  Category setActiveRecursive(bool active) {
    final updatedChildren = children.map((child) {
      return child.setActiveRecursive(active);
    }).toList();

    return copyWithCategoryFn(
      isActive: () => active,
      children: () => updatedChildren,
      updatedAt: () => DateTime.now(),
    );
  }

  /// Export tree structure as string
  String toTreeString([int indent = 0]) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;

    buffer.writeln('$prefix├─ $name (${productIds.length} products)');

    for (int i = 0; i < children.length; i++) {
      buffer.write(children[i].toTreeString(indent + 1));
    }

    return buffer.toString();
  }
}

extension FeaturedCategoryExtension on FeaturedCategory {
  /// Check if promo is active
  bool get isPromoActive {
    if (promoStartDate == null || promoEndDate == null) return false;

    final now = DateTime.now();
    return now.isAfter(promoStartDate!) && now.isBefore(promoEndDate!);
  }

  /// Get featured products count
  int get featuredCount => featuredProductIds.length;
}
