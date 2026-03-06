import 'package:flutter/material.dart';
import 'package:gf1/view/utils/color_constants.dart';
import 'package:shimmer/shimmer.dart';


class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Shimmer for the status header
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.subtextColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 24),
          // Shimmer for the grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0, // Adjusted for the new card design
            ),
            itemCount: 6, // Placeholder for 6 cards
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.accentColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
