class ScanCategory {
  final String id;
  final String name;
  final String emoji;
  final String geminiContext;
  final List<String> validTags;

  const ScanCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.geminiContext,
    required this.validTags,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'geminiContext': geminiContext,
    'validTags': validTags,
  };

  factory ScanCategory.fromJson(Map<String, dynamic> json) => ScanCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    geminiContext: json['geminiContext'] as String,
    validTags: List<String>.from(json['validTags'] as List),
  );

  ScanCategory copyWith({
    String? id,
    String? name,
    String? emoji,
    String? geminiContext,
    List<String>? validTags,
  }) {
    return ScanCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      geminiContext: geminiContext ?? this.geminiContext,
      validTags: validTags ?? this.validTags,
    );
  }

  static List<ScanCategory> get defaults => const [
    ScanCategory(
      id: 'planes',
      name: 'Planes',
      emoji: '✈️',
      geminiContext: 'aircraft or airplane',
      validTags: [
        'Fighter',
        'Bomber',
        'Transport/Cargo',
        'Attack Helicopter',
        'Utility Helicopter',
        'Surveillance/AWACS',
        'Tanker',
        'Trainer',
        'Drone/UAV',
        'Stealth',
        'Experimental',
        'Vintage Warbird',
        'Commercial/Civilian',
      ],
    ),
    ScanCategory(
      id: 'cars',
      name: 'Cars',
      emoji: '🚗',
      geminiContext: 'car or automobile',
      validTags: [
        'Sedan',
        'SUV',
        'Sports Car',
        'Truck',
        'Luxury',
        'Electric',
        'Classic/Vintage',
        'Supercar',
        'Convertible',
        'Wagon',
        'Van',
        'Crossover',
      ],
    ),
    ScanCategory(
      id: 'flowers',
      name: 'Flowers',
      emoji: '🌸',
      geminiContext: 'flower or plant bloom',
      validTags: [
        'Annual',
        'Perennial',
        'Wildflower',
        'Garden Flower',
        'Tropical',
        'Alpine',
        'Rare/Endangered',
        'Edible',
        'Fragrant',
        'Native',
        'Invasive',
      ],
    ),
    ScanCategory(
      id: 'trees',
      name: 'Trees',
      emoji: '🌳',
      geminiContext: 'tree or shrub',
      validTags: [
        'Deciduous',
        'Evergreen',
        'Conifer',
        'Fruit Tree',
        'Ornamental',
        'Native',
        'Tropical',
        'Palm',
        'Rare',
        'Ancient',
        'Invasive',
      ],
    ),
    ScanCategory(
      id: 'birds',
      name: 'Birds',
      emoji: '🐦',
      geminiContext: 'bird or avian species',
      validTags: [
        'Songbird',
        'Raptor',
        'Waterfowl',
        'Seabird',
        'Shorebird',
        'Hummingbird',
        'Parrot',
        'Owl',
        'Migratory',
        'Endemic',
        'Endangered',
      ],
    ),
  ];
}
