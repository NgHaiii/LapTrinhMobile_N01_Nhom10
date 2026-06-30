import 'package:flutter/material.dart';

class CustomerImageCarousel extends StatefulWidget {
  const CustomerImageCarousel({
    super.key,
    required this.images,
    this.fallbackIcon = Icons.image_outlined,
    this.borderRadius = BorderRadius.zero,
  });

  final List<String> images;
  final IconData fallbackIcon;
  final BorderRadius borderRadius;

  @override
  State<CustomerImageCarousel> createState() => _CustomerImageCarouselState();
}

class _CustomerImageCarouselState extends State<CustomerImageCarousel> {
  int _currentIndex = 0;

  List<String> get _images {
    return widget.images
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void didUpdateWidget(covariant CustomerImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final images = _images;

    if (images.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= images.length) {
      _currentIndex = images.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = _images;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Center(
            child: Icon(
              widget.fallbackIcon,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  final expected = progress.expectedTotalBytes;

                  final value = expected == null
                      ? null
                      : progress.cumulativeBytesLoaded / expected;

                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 46,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_currentIndex + 1}/'
                        '${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 9,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    child: Text(
                      'Vuốt để xem ảnh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
