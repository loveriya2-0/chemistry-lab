import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Custom 5-star rating widget that allows users to select a rating.
class RatingWidget extends StatelessWidget {
  const RatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 48,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;

        return GestureDetector(
          onTap: () => onRatingChanged(starValue),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: isFilled ? LabColors.warning : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }
}
