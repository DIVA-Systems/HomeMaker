class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.license,
    required this.attribution,
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    required this.iconAsset,
    required this.modelAsset,
    this.sourceLibrary,
    this.creator,
  });

  final String id;
  final String name;
  final String category;
  final String license;
  final String attribution;
  final double widthCm;
  final double depthCm;
  final double heightCm;
  final String iconAsset;
  final String modelAsset;
  final String? sourceLibrary;
  final String? creator;

  bool get isUserImport => iconAsset.startsWith('user:');

  String get iconPath =>
      isUserImport ? iconAsset : 'assets/catalog/$iconAsset';

  String get modelPath =>
      modelAsset.isEmpty ? '' : 'assets/catalog/$modelAsset';

  bool get hasModel => modelAsset.isNotEmpty;

  String get categoryLabel {
    switch (category) {
      case 'livingRoom':
        return 'Living';
      case 'bedroom':
        return 'Bedroom';
      case 'kitchen':
        return 'Kitchen';
      case 'bathroom':
        return 'Bath';
      case 'office':
        return 'Office';
      default:
        return category;
    }
  }

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      license: json['license'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
      widthCm: (json['widthCm'] as num).toDouble(),
      depthCm: (json['depthCm'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      iconAsset: json['iconAsset'] as String,
      modelAsset: json['modelAsset'] as String,
      sourceLibrary: json['sourceLibrary'] as String?,
      creator: json['creator'] as String?,
    );
  }
}

enum CatalogCategory {
  all,
  livingRoom,
  bedroom,
  kitchen,
  bathroom,
  office;

  String get label {
    switch (this) {
      case CatalogCategory.all:
        return 'All';
      case CatalogCategory.livingRoom:
        return 'Living';
      case CatalogCategory.bedroom:
        return 'Bedroom';
      case CatalogCategory.kitchen:
        return 'Kitchen';
      case CatalogCategory.bathroom:
        return 'Bath';
      case CatalogCategory.office:
        return 'Office';
    }
  }

  String? get jsonKey {
    switch (this) {
      case CatalogCategory.all:
        return null;
      case CatalogCategory.livingRoom:
        return 'livingRoom';
      case CatalogCategory.bedroom:
        return 'bedroom';
      case CatalogCategory.kitchen:
        return 'kitchen';
      case CatalogCategory.bathroom:
        return 'bathroom';
      case CatalogCategory.office:
        return 'office';
    }
  }
}
