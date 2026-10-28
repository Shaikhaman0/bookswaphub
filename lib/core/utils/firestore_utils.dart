import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a Firestore date field safely (server timestamps can be null for a moment).
DateTime readDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}

String readString(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

double readDouble(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

int readInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

List<String> readStringList(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];
