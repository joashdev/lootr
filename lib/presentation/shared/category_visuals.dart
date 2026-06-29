import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';

class CategoryIconOption {
  const CategoryIconOption({
    required this.value,
    required this.label,
    this.icon,
    this.emoji,
  });

  final String value;
  final String label;
  final IconData? icon;
  final String? emoji;

  bool get isEmoji => emoji != null;
}

class CategoryColorOption {
  const CategoryColorOption(this.label, this.hex, this.color);

  final String label;
  final String hex;
  final Color color;
}

const categoryIconOptions = <CategoryIconOption>[
  CategoryIconOption(
    value: 'shopping-bag',
    label: 'Shopping',
    icon: Icons.shopping_bag_outlined,
  ),
  CategoryIconOption(
    value: 'utensils',
    label: 'Food',
    icon: Icons.restaurant_outlined,
  ),
  CategoryIconOption(
    value: 'transport',
    label: 'Transport',
    icon: Icons.directions_bus_rounded,
  ),
  CategoryIconOption(value: 'house', label: 'Home', icon: Icons.home_outlined),
  CategoryIconOption(
    value: 'medical',
    label: 'Medical',
    icon: Icons.local_hospital_outlined,
  ),
  CategoryIconOption(value: 'salary', label: 'Work', icon: Icons.work_outline),
  CategoryIconOption(value: 'tag', label: 'General', icon: Icons.sell_outlined),
  CategoryIconOption(
    value: 'entertainment',
    label: 'Fun',
    icon: Icons.movie_outlined,
  ),
  CategoryIconOption(
    value: 'utilities',
    label: 'Utilities',
    icon: Icons.bolt_outlined,
  ),
  CategoryIconOption(
    value: 'coffee',
    label: 'Coffee',
    icon: Icons.local_cafe_outlined,
  ),
  CategoryIconOption(
    value: 'cart',
    label: 'Groceries',
    icon: Icons.local_grocery_store_outlined,
  ),
  CategoryIconOption(
    value: 'fuel',
    label: 'Fuel',
    icon: Icons.local_gas_station_outlined,
  ),
  CategoryIconOption(
    value: 'wifi',
    label: 'Internet',
    icon: Icons.wifi_outlined,
  ),
  CategoryIconOption(
    value: 'book',
    label: 'Books',
    icon: Icons.menu_book_outlined,
  ),
  CategoryIconOption(
    value: 'gift',
    label: 'Gifts',
    icon: Icons.redeem_outlined,
  ),
  CategoryIconOption(
    value: 'briefcase',
    label: 'Business',
    icon: Icons.business_center_outlined,
  ),
  CategoryIconOption(
    value: 'credit-card',
    label: 'Card',
    icon: Icons.credit_card_outlined,
  ),
  CategoryIconOption(
    value: 'camera',
    label: 'Camera',
    icon: Icons.photo_camera_outlined,
  ),
  CategoryIconOption(
    value: 'music',
    label: 'Music',
    icon: Icons.music_note_outlined,
  ),
  CategoryIconOption(
    value: 'phone',
    label: 'Phone',
    icon: Icons.phone_iphone_outlined,
  ),
  CategoryIconOption(
    value: 'beauty',
    label: 'Beauty',
    icon: Icons.face_retouching_natural_outlined,
  ),
  CategoryIconOption(value: 'pets', label: 'Pets', icon: Icons.pets_outlined),
  CategoryIconOption(
    value: 'baby',
    label: 'Baby',
    icon: Icons.child_friendly_outlined,
  ),
  CategoryIconOption(
    value: 'travel',
    label: 'Travel',
    icon: Icons.luggage_outlined,
  ),
  CategoryIconOption(value: 'emoji:🍔', label: 'Burger', emoji: '🍔'),
  CategoryIconOption(value: 'emoji:🍜', label: 'Noodles', emoji: '🍜'),
  CategoryIconOption(value: 'emoji:🛒', label: 'Basket', emoji: '🛒'),
  CategoryIconOption(value: 'emoji:🧋', label: 'Drink', emoji: '🧋'),
  CategoryIconOption(value: 'emoji:🎮', label: 'Gaming', emoji: '🎮'),
  CategoryIconOption(value: 'emoji:🎬', label: 'Movies', emoji: '🎬'),
  CategoryIconOption(value: 'emoji:💄', label: 'Makeup', emoji: '💄'),
  CategoryIconOption(value: 'emoji:✂️', label: 'Salon', emoji: '✂️'),
  CategoryIconOption(value: 'emoji:📚', label: 'Study', emoji: '📚'),
  CategoryIconOption(value: 'emoji:⚽', label: 'Sports', emoji: '⚽'),
  CategoryIconOption(value: 'emoji:🎁', label: 'Presents', emoji: '🎁'),
  CategoryIconOption(value: 'emoji:🐶', label: 'Pets', emoji: '🐶'),
  CategoryIconOption(value: 'emoji:🍼', label: 'Baby', emoji: '🍼'),
  CategoryIconOption(value: 'emoji:⛵', label: 'Boat', emoji: '⛵'),
  CategoryIconOption(value: 'emoji:🏠', label: 'House', emoji: '🏠'),
  CategoryIconOption(value: 'emoji:💼', label: 'Office', emoji: '💼'),
  CategoryIconOption(value: 'emoji:🧾', label: 'Bills', emoji: '🧾'),
  CategoryIconOption(
    value: 'subscriptions',
    label: 'Subscriptions',
    icon: LucideIcons.repeat,
  ),
  CategoryIconOption(
    value: 'education',
    label: 'Education',
    icon: LucideIcons.graduationCap,
  ),
  CategoryIconOption(
    value: 'fitness',
    label: 'Fitness',
    icon: LucideIcons.dumbbell,
  ),
  CategoryIconOption(
    value: 'health',
    label: 'Health',
    icon: LucideIcons.heartPulse,
  ),
  CategoryIconOption(
    value: 'savings',
    label: 'Savings',
    icon: LucideIcons.piggyBank,
  ),
  CategoryIconOption(
    value: 'insurance',
    label: 'Insurance',
    icon: LucideIcons.shieldCheck,
  ),
  CategoryIconOption(
    value: 'investment',
    label: 'Investment',
    icon: LucideIcons.trendingUp,
  ),
  CategoryIconOption(
    value: 'clothing',
    label: 'Clothing',
    icon: LucideIcons.shirt,
  ),
  CategoryIconOption(
    value: 'charity',
    label: 'Charity',
    icon: LucideIcons.heartHandshake,
  ),
  CategoryIconOption(
    value: 'taxes',
    label: 'Taxes',
    icon: LucideIcons.receiptText,
  ),
  CategoryIconOption(
    value: 'childcare',
    label: 'Childcare',
    icon: LucideIcons.baby,
  ),
  CategoryIconOption(
    value: 'electronics',
    label: 'Electronics',
    icon: LucideIcons.smartphone,
  ),
  CategoryIconOption(value: 'rent', label: 'Rent', icon: LucideIcons.building2),
  CategoryIconOption(
    value: 'mortgage',
    label: 'Mortgage',
    icon: LucideIcons.landmark,
  ),
  CategoryIconOption(value: 'car', label: 'Car', icon: LucideIcons.car),
  CategoryIconOption(
    value: 'taxi',
    label: 'Ride',
    icon: LucideIcons.carTaxiFront,
  ),
  CategoryIconOption(value: 'bus', label: 'Bus', icon: LucideIcons.bus),
  CategoryIconOption(
    value: 'train',
    label: 'Train',
    icon: LucideIcons.trainFront,
  ),
  CategoryIconOption(value: 'plane', label: 'Flight', icon: LucideIcons.plane),
  CategoryIconOption(
    value: 'parking',
    label: 'Parking',
    icon: LucideIcons.squareParking,
  ),
  CategoryIconOption(
    value: 'dining',
    label: 'Dining',
    icon: LucideIcons.utensilsCrossed,
  ),
  CategoryIconOption(value: 'pizza', label: 'Pizza', icon: LucideIcons.pizza),
  CategoryIconOption(value: 'beer', label: 'Drinks', icon: LucideIcons.beer),
  CategoryIconOption(value: 'wine', label: 'Wine', icon: LucideIcons.wine),
  CategoryIconOption(
    value: 'grocery',
    label: 'Grocery',
    icon: LucideIcons.shoppingCart,
  ),
  CategoryIconOption(value: 'apple', label: 'Produce', icon: LucideIcons.apple),
  CategoryIconOption(value: 'fuel-pump', label: 'Fuel', icon: LucideIcons.fuel),
  CategoryIconOption(
    value: 'electricity',
    label: 'Power',
    icon: LucideIcons.zap,
  ),
  CategoryIconOption(value: 'water', label: 'Water', icon: LucideIcons.droplet),
  CategoryIconOption(value: 'gas', label: 'Gas', icon: LucideIcons.flame),
  CategoryIconOption(value: 'trash', label: 'Waste', icon: LucideIcons.trash2),
  CategoryIconOption(value: 'tv-service', label: 'TV', icon: LucideIcons.tv),
  CategoryIconOption(
    value: 'streaming',
    label: 'Streaming',
    icon: LucideIcons.monitorPlay,
  ),
  CategoryIconOption(
    value: 'gaming',
    label: 'Gaming',
    icon: LucideIcons.gamepad2,
  ),
  CategoryIconOption(value: 'gym', label: 'Gym', icon: LucideIcons.dumbbell),
  CategoryIconOption(value: 'pill', label: 'Pharmacy', icon: LucideIcons.pill),
  CategoryIconOption(
    value: 'stethoscope',
    label: 'Doctor',
    icon: LucideIcons.stethoscope,
  ),
  CategoryIconOption(
    value: 'school',
    label: 'School',
    icon: LucideIcons.school,
  ),
  CategoryIconOption(value: 'pet', label: 'Pets', icon: LucideIcons.pawPrint),
  CategoryIconOption(
    value: 'wallet',
    label: 'Wallet',
    icon: LucideIcons.wallet,
  ),
  CategoryIconOption(value: 'bank', label: 'Bank', icon: LucideIcons.landmark),
  CategoryIconOption(value: 'coins', label: 'Cash', icon: LucideIcons.coins),
  CategoryIconOption(
    value: 'banknote',
    label: 'Salary',
    icon: LucideIcons.banknote,
  ),
  CategoryIconOption(
    value: 'percent',
    label: 'Interest',
    icon: LucideIcons.percent,
  ),
  CategoryIconOption(
    value: 'chart',
    label: 'Stocks',
    icon: LucideIcons.chartLine,
  ),
  CategoryIconOption(
    value: 'shield',
    label: 'Insurance',
    icon: LucideIcons.shield,
  ),
  CategoryIconOption(value: 'gift-box', label: 'Gifts', icon: LucideIcons.gift),
  CategoryIconOption(value: 'cake', label: 'Birthday', icon: LucideIcons.cake),
  CategoryIconOption(
    value: 'baby-stroller',
    label: 'Baby',
    icon: LucideIcons.baby,
  ),
  CategoryIconOption(
    value: 'shirt-2',
    label: 'Clothing',
    icon: LucideIcons.shirt,
  ),
  CategoryIconOption(
    value: 'scissors',
    label: 'Salon',
    icon: LucideIcons.scissors,
  ),
  CategoryIconOption(
    value: 'sparkles',
    label: 'Beauty',
    icon: LucideIcons.sparkles,
  ),
  CategoryIconOption(
    value: 'hammer',
    label: 'Repairs',
    icon: LucideIcons.hammer,
  ),
  CategoryIconOption(
    value: 'wrench',
    label: 'Maintenance',
    icon: LucideIcons.wrench,
  ),
  CategoryIconOption(value: 'plant', label: 'Garden', icon: LucideIcons.sprout),
  CategoryIconOption(
    value: 'palette',
    label: 'Hobbies',
    icon: LucideIcons.palette,
  ),
  CategoryIconOption(
    value: 'camera-2',
    label: 'Photo',
    icon: LucideIcons.camera,
  ),
  CategoryIconOption(
    value: 'ticket',
    label: 'Events',
    icon: LucideIcons.ticket,
  ),
  CategoryIconOption(value: 'globe', label: 'Travel', icon: LucideIcons.globe),
  CategoryIconOption(
    value: 'hotel',
    label: 'Hotel',
    icon: LucideIcons.bedDouble,
  ),
  CategoryIconOption(
    value: 'coffee-2',
    label: 'Cafe',
    icon: LucideIcons.coffee,
  ),
  CategoryIconOption(
    value: 'phone-bill',
    label: 'Phone',
    icon: LucideIcons.smartphone,
  ),
  CategoryIconOption(
    value: 'newspaper',
    label: 'News',
    icon: LucideIcons.newspaper,
  ),
  CategoryIconOption(
    value: 'church',
    label: 'Donations',
    icon: LucideIcons.heartHandshake,
  ),
  CategoryIconOption(
    value: 'piggy',
    label: 'Savings',
    icon: LucideIcons.piggyBank,
  ),
  CategoryIconOption(
    value: 'calendar',
    label: 'Subscription',
    icon: LucideIcons.calendarClock,
  ),
  CategoryIconOption(emoji: '💊', value: 'emoji:💊', label: 'Pharmacy'),
  CategoryIconOption(emoji: '🏥', value: 'emoji:🏥', label: 'Hospital'),
  CategoryIconOption(emoji: '✈️', value: 'emoji:✈️', label: 'Flight'),
  CategoryIconOption(emoji: '🏨', value: 'emoji:🏨', label: 'Hotel'),
  CategoryIconOption(emoji: '🎓', value: 'emoji:🎓', label: 'School'),
  CategoryIconOption(emoji: '🧹', value: 'emoji:🧹', label: 'Cleaning'),
  CategoryIconOption(emoji: '🔧', value: 'emoji:🔧', label: 'Repairs'),
  CategoryIconOption(emoji: '🎉', value: 'emoji:🎉', label: 'Party'),
  CategoryIconOption(emoji: '🌿', value: 'emoji:🌿', label: 'Plants'),
  CategoryIconOption(emoji: '🧘', value: 'emoji:🧘', label: 'Wellness'),
  CategoryIconOption(emoji: '🎨', value: 'emoji:🎨', label: 'Art'),
];

const categoryColorOptions = <CategoryColorOption>[
  CategoryColorOption('Indigo Mist', '#5C64CC', AppColors.primary600),
  CategoryColorOption('Sky', '#38BDF8', Color(0xFF38BDF8)),
  CategoryColorOption('Indigo', '#4F46E5', Color(0xFF4F46E5)),
  CategoryColorOption('Mint', '#059669', AppColors.success600),
  CategoryColorOption('Forest', '#16A34A', Color(0xFF16A34A)),
  CategoryColorOption('Teal', '#0F766E', Color(0xFF0F766E)),
  CategoryColorOption('Amber', '#D97706', AppColors.warning600),
  CategoryColorOption('Sunflower', '#F59E0B', Color(0xFFF59E0B)),
  CategoryColorOption('Coral', '#D97757', AppColors.danger600),
  CategoryColorOption('Rose', '#E11D48', Color(0xFFE11D48)),
  CategoryColorOption('Violet', '#7C3AED', Color(0xFF7C3AED)),
  CategoryColorOption('Slate', '#64748B', Color(0xFF64748B)),
  CategoryColorOption('Graphite', '#334155', Color(0xFF334155)),
];

CategoryIconOption categoryIconOptionFor(String? value) {
  if (value == null || value.isEmpty) {
    return categoryIconOptions.first;
  }

  return categoryIconOptions.firstWhere(
    (option) => option.value == value,
    orElse: () => categoryIconOptions.first,
  );
}

CategoryColorOption categoryColorOptionFor(String? value) {
  if (value == null || value.isEmpty) {
    return categoryColorOptions.first;
  }

  return categoryColorOptions.firstWhere(
    (option) => option.hex == value,
    orElse: () => categoryColorOptions.first,
  );
}

Color parseCategoryColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) {
    return AppColors.primary600;
  }

  final hex = hexColor.replaceFirst('#', '');
  final parsed = int.tryParse('FF$hex', radix: 16);
  return parsed == null ? AppColors.primary600 : Color(parsed);
}

Widget buildCategoryVisual(
  String? value, {
  required Color color,
  double size = 20,
}) {
  final option = categoryIconOptionFor(value);
  if (option.isEmoji) {
    return Text(option.emoji!, style: TextStyle(fontSize: size));
  }

  return Icon(option.icon ?? Icons.sell_outlined, size: size, color: color);
}
