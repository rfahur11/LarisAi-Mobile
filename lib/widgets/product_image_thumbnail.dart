import 'dart:io';
import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../services/image_storage_service.dart';

class ProductImageThumbnail extends StatelessWidget {
  final String imagePath;
  final String? productName;
  final String? barcode;
  final double width;
  final double height;
  final double borderRadius;
  final Widget? fallback;
  final BoxFit fit;

  const ProductImageThumbnail({
    super.key,
    required this.imagePath,
    this.productName,
    this.barcode,
    this.width = 44,
    this.height = 44,
    this.borderRadius = 10,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    var cleanPath = imagePath.trim();

    // Intelligent auto-match for starter products if imagePath is empty
    if (cleanPath.isEmpty) {
      final nameLower = (productName ?? '').toLowerCase();
      final code = barcode ?? '';
      if (code == '8992772111029' || nameLower.contains('aqua')) {
        cleanPath = 'aqua_600ml.jpg';
      } else if (code == '8992753112234' || nameLower.contains('indomie')) {
        cleanPath = 'indomie_goreng.jpg';
      } else if (code == '8999999002133' || nameLower.contains('teh botol')) {
        cleanPath = 'teh_botol.jpg';
      } else if (code == '8998866100124' || nameLower.contains('kapal api') || nameLower.contains('kopi')) {
        cleanPath = 'kopi_kapal_api.jpg';
      }
    }

    if (cleanPath.isEmpty) {
      return fallback ?? const SizedBox.shrink();
    }

    // 1. Direct Bundled Asset Match (Instant Synchronous Render)
    const bundledImages = {
      'aqua_600ml.jpg',
      'indomie_goreng.jpg',
      'teh_botol.jpg',
      'kopi_kapal_api.jpg',
    };
    if (bundledImages.contains(cleanPath)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/$cleanPath',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
        ),
      );
    }

    // 2. Direct Asset Path
    if (cleanPath.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          cleanPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
        ),
      );
    }

    // 2. Direct Network URL
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          cleanPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: Colors.grey.withValues(alpha: 0.1),
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    // 3. Local File with Asset / Network Fallbacks
    return FutureBuilder<File?>(
      future: ImageStorageService.instance.getLocalImageFile(cleanPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.file(
                snapshot.data!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
              ),
            );
          }

          // Check if file is bundled in assets/images/
          if (cleanPath.endsWith('.jpg') || cleanPath.endsWith('.png') || cleanPath.endsWith('.webp')) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.asset(
                'assets/images/$cleanPath',
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, _) {
                  if (!ApiConstants.isOfflineMode && ApiConstants.posBaseUrl.startsWith('http')) {
                    return Image.network(
                      '${ApiConstants.posBaseUrl}/api/v1/images/$cleanPath',
                      width: width,
                      height: height,
                      fit: fit,
                      errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
                    );
                  }
                  return fallback ?? const SizedBox.shrink();
                },
              ),
            );
          }

          // If connected to LAN host
          if (!ApiConstants.isOfflineMode && ApiConstants.posBaseUrl.startsWith('http')) {
            final remoteUrl = '${ApiConstants.posBaseUrl}/api/v1/images/$cleanPath';
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                remoteUrl,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, _) => fallback ?? const SizedBox.shrink(),
              ),
            );
          }
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
