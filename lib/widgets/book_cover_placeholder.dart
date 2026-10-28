import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookCoverPlaceholder extends StatelessWidget {
  final String title;
  final String author;
  final Color? color;

  const BookCoverPlaceholder({
    Key? key,
    required this.title,
    required this.author,
    this.color,
  }) : super(key: key);

  // Generate a consistent color based on the book title
  Color _getColorFromHash(String text) {
    if (color != null) {
      return color!;
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];

    int hash = 0;

    for (var i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getColorFromHash(title);

    // Get first letter of book title
    final firstLetter =
    title.isNotEmpty ? title[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor.withValues(alpha: 0.70),
            bgColor,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative background book icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.menu_book_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),

          // Decorative small icon
          Positioned(
            right: 12,
            top: 12,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),

          // Book content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // First letter
                Text(
                  firstLetter,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.50),
                  ),
                ),

                // Book title and author
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}