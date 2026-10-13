import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';

class ProductImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  /// Helper retained for backward compatibility with callers
  static String getLocalAssetOrUrl(String originalUrl) => originalUrl.trim();

  @override
  Widget build(BuildContext context) {
    final double iconSize = width != null ? width! * 0.45 : 32;
    
    // Target display cache resolutions (helps save memory)
    final int? cacheW = width != null ? (width! * 2.5).round() : null;
    final int? cacheH = height != null ? (height! * 2.5).round() : null;

    final String trimmedUrl = imageUrl.trim();

    // 1. Empty or null image URL -> Display sleek eco fallback icon
    if (trimmedUrl.isEmpty || trimmedUrl == 'null') {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.eco_outlined,
            size: iconSize,
            color: AppColors.primary,
          ),
        ),
      );
    }

    // 2. Local asset (e.g. assets/images/...)
    if (trimmedUrl.startsWith('assets/')) {
      return Image.asset(
        trimmedUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.eco_outlined,
              size: iconSize,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    // 3. Network URL (from Supabase Storage Bucket SabzeeWala)
    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 50),
      fadeOutDuration: const Duration(milliseconds: 50),
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade50,
        child: Center(
          child: Icon(
            Icons.eco_outlined,
            size: iconSize,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.eco_outlined,
            size: iconSize,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
