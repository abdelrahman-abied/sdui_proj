// lib/components/sdui_components.dart
import 'package:flutter/material.dart';

// 1. HEADER
class SDUIHeader extends StatelessWidget {
  final String title;
  final String iconUrl;

  const SDUIHeader({super.key, required this.title, required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Image.network(iconUrl, width: 40, height: 40, errorBuilder: (_,__,___) => const Icon(Icons.person)),
        ],
      ),
    );
  }
}

// 2. BANNER_CARD
class SDUIBanner extends StatelessWidget {
  final String imageUrl;

  const SDUIBanner({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// 3. PRODUCT_CARD
class SDUIProductCard extends StatelessWidget {
  final String name;
  final String price;

  const SDUIProductCard({super.key, required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 80, color: Colors.grey[300]), // Placeholder image
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(price, style: const TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}