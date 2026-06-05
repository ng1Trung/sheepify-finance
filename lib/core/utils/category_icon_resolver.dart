import 'package:flutter/material.dart';

const List<IconData> _categoryIcons = [
  Icons.receipt,
  Icons.fastfood,
  Icons.restaurant,
  Icons.local_cafe,
  Icons.local_bar,
  Icons.cake,
  Icons.kitchen,
  Icons.directions_car,
  Icons.motorcycle,
  Icons.directions_bus,
  Icons.flight,
  Icons.local_gas_station,
  Icons.shopping_cart,
  Icons.shopping_bag,
  Icons.checkroom,
  Icons.local_mall,
  Icons.card_giftcard,
  Icons.home,
  Icons.build,
  Icons.wifi,
  Icons.electrical_services,
  Icons.local_laundry_service,
  Icons.medical_services,
  Icons.fitness_center,
  Icons.spa,
  Icons.local_pharmacy,
  Icons.movie,
  Icons.sports_esports,
  Icons.school,
  Icons.book,
  Icons.music_note,
  Icons.attach_money,
  Icons.savings,
  Icons.work,
  Icons.pets,
  Icons.child_friendly,
  Icons.category,
  Icons.help,
];

IconData resolveCategoryIcon(int codePoint) {
  for (final icon in _categoryIcons) {
    if (icon.codePoint == codePoint) {
      return icon;
    }
  }
  return Icons.category;
}
