import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

class CloudinaryImageField extends StatefulWidget {
  const CloudinaryImageField({
    super.key,
    required this.folder,
    required this.tag,
    required this.onUploaded,
    this.initialUrl = '',
    this.label = 'Ảnh',
  });

  final String folder;
  final String tag;
  final String initialUrl;
  final String label;
  final ValueChanged<String> onUploaded;

  @override
  State<CloudinaryImageField> createState() => _CloudinaryImageFieldState();
}

class _CloudinaryImageFieldState extends State<CloudinaryImageField> {
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();

  Uint8List? _previewBytes;
  String? _fileName;
  String? _error;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _previewBytes = bytes;
        _fileName = file.name;
        _uploading = true;
        _error = null;
      });

      final url = await _cloudinary.uploadImage(
        file,
        folder: widget.folder,
        tag: widget.tag,
      );

      if (!mounted) return;

      widget.onUploaded(url);

      setState(() {
        _uploading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
        _error = _errorMessage(error);
      });
    }
  }

  @override
  void dispose() {
    _cloudinary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildPreview(),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _uploading
                ? 'Đang tải ảnh...'
                : _fileName ?? 'Chọn ảnh từ thiết bị',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 7),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    if (_previewBytes != null) {
      return Image.memory(_previewBytes!, fit: BoxFit.cover);
    }

    if (widget.initialUrl.trim().isNotEmpty) {
      return _NetworkImage(url: widget.initialUrl);
    }

    return const _ImagePlaceholder();
  }
}

class CloudinaryMultiImageField extends StatefulWidget {
  const CloudinaryMultiImageField({
    super.key,
    required this.folder,
    required this.tag,
    required this.onChanged,
    this.initialUrls = const [],
    this.label = 'Hình ảnh',
    this.maxImages,
  }) : assert(
         maxImages == null || maxImages > 0,
         'maxImages phải lớn hơn 0 hoặc bằng null.',
       );

  final String folder;
  final String tag;
  final List<String> initialUrls;
  final String label;

  /// Null nghĩa là không giới hạn số lượng ảnh.
  final int? maxImages;

  final ValueChanged<List<String>> onChanged;

  @override
  State<CloudinaryMultiImageField> createState() =>
      _CloudinaryMultiImageFieldState();
}

class _CloudinaryMultiImageFieldState extends State<CloudinaryMultiImageField> {
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();

  late final List<String> _urls;

  bool _uploading = false;
  int _uploadedCount = 0;
  int _totalUploading = 0;
  String? _error;

  @override
  void initState() {
    super.initState();

    final initialUrls = widget.initialUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    final limit = widget.maxImages;

    _urls = limit == null ? initialUrls : initialUrls.take(limit).toList();
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    final limit = widget.maxImages;
    final remaining = limit == null ? null : limit - _urls.length;

    if (remaining != null && remaining <= 0) {
      setState(() {
        _error = 'Chỉ được đăng tối đa $limit ảnh.';
      });
      return;
    }

    try {
      final selectedFiles = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (selectedFiles.isEmpty || !mounted) return;

      final files = remaining == null
          ? selectedFiles
          : selectedFiles.take(remaining).toList();

      if (files.isEmpty) return;

      setState(() {
        _uploading = true;
        _uploadedCount = 0;
        _totalUploading = files.length;

        if (remaining != null && selectedFiles.length > remaining) {
          _error = 'Bạn đã chọn quá giới hạn. Chỉ tải $remaining ảnh đầu tiên.';
        } else {
          _error = null;
        }
      });

      for (final file in files) {
        final url = await _cloudinary.uploadImage(
          file,
          folder: widget.folder,
          tag: widget.tag,
        );

        if (!mounted) return;

        final normalizedUrl = url.trim();

        setState(() {
          if (normalizedUrl.isNotEmpty && !_urls.contains(normalizedUrl)) {
            _urls.add(normalizedUrl);
          }

          _uploadedCount++;
        });

        _notifyChanged();
      }

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadedCount = 0;
        _totalUploading = 0;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
        _uploadedCount = 0;
        _totalUploading = 0;
        _error = _errorMessage(error);
      });
    }
  }

  void _removeImage(int index) {
    if (_uploading || index < 0 || index >= _urls.length) {
      return;
    }

    setState(() {
      _urls.removeAt(index);
      _error = null;
    });

    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged(List<String>.unmodifiable(_urls));
  }

  @override
  void dispose() {
    _cloudinary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final limit = widget.maxImages;

    final canAddMore = limit == null || _urls.length < limit;

    final imageCountText = limit == null
        ? '${_urls.length} ảnh'
        : '${_urls.length}/$limit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              imageCountText,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _urls.isEmpty
              ? 'Ảnh đầu tiên sẽ được dùng làm ảnh bìa.'
              : 'Giữ ảnh đầu tiên làm ảnh bìa.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _urls.length + (canAddMore ? 1 : 0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index == _urls.length) {
              return _AddImageTile(
                uploading: _uploading,
                progressText: _uploading
                    ? '$_uploadedCount/$_totalUploading'
                    : null,
                onTap: _pickAndUpload,
              );
            }

            return _SelectedImageTile(
              url: _urls[index],
              isCover: index == 0,
              enabled: !_uploading,
              onRemove: () => _removeImage(index),
            );
          },
        ),
        if (_uploading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _totalUploading <= 0
                ? null
                : _uploadedCount / _totalUploading,
          ),
          const SizedBox(height: 6),
          Text(
            'Đang tải $_uploadedCount/$_totalUploading ảnh...',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 7),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({
    required this.uploading,
    required this.onTap,
    this.progressText,
  });

  final bool uploading;
  final VoidCallback onTap;
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: uploading ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (uploading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 34,
                color: colors.primary,
              ),
            const SizedBox(height: 7),
            Text(
              uploading ? progressText ?? 'Đang tải' : 'Thêm nhiều ảnh',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedImageTile extends StatelessWidget {
  const _SelectedImageTile({
    required this.url,
    required this.isCover,
    required this.enabled,
    required this.onRemove,
  });

  final String url;
  final bool isCover;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _NetworkImage(url: url),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: IconButton.filled(
            tooltip: 'Xóa ảnh',
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded, size: 17),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              maximumSize: const Size(32, 32),
            ),
          ),
        ),
        if (isCover)
          const Positioned(
            left: 5,
            bottom: 5,
            child: Chip(
              label: Text('Ảnh bìa'),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;

        return ColoredBox(
          color: colors.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) {
        return ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
