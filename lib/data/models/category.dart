import 'package:flutter/material.dart';

class BookCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int bookCount;

  const BookCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.bookCount = 0,
  });
}
