import 'package:flutter/material.dart';
import 'package:bookswaphub/data/models/category.dart';

/// Fixed list of book categories (a taxonomy, not mock data).
/// The `id` is stored in Firestore as `categoryId`.
const List<BookCategory> bookCategories = [
  BookCategory(id: 'fiction', name: 'Fiction', icon: Icons.auto_stories, color: Colors.blue),
  BookCategory(id: 'programming', name: 'Programming', icon: Icons.code, color: Colors.green),
  BookCategory(id: 'science', name: 'Science', icon: Icons.science, color: Colors.purple),
  BookCategory(id: 'business', name: 'Business', icon: Icons.business_center, color: Colors.orange),
  BookCategory(id: 'self-help', name: 'Self Help', icon: Icons.psychology, color: Colors.teal),
  BookCategory(id: 'romance', name: 'Romance', icon: Icons.favorite, color: Colors.red),
  BookCategory(id: 'history', name: 'History', icon: Icons.history_edu, color: Colors.brown),
  BookCategory(id: 'education', name: 'Education', icon: Icons.school, color: Colors.indigo),
];

BookCategory? categoryById(String id) {
  for (final c in bookCategories) {
    if (c.id == id) return c;
  }
  return null;
}
