import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/site_layout_models.dart';
import '../providers/site_layout_provider.dart';
import '../services/site_layout_file_storage.dart';
import '../services/site_photo_service.dart';

class SitePhotoGalleryScreen extends StatefulWidget {
  const SitePhotoGalleryScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<SitePhotoGalleryScreen> createState() => _SitePhotoGalleryScreenState();
}

class _SitePhotoGalleryScreenState extends State<SitePhotoGalleryScreen> {
  final _service = SitePhotoService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteLayoutProvider>();
    final photos = provider.bundle?.project.id == widget.projectId
        ? provider.bundle!.photos
        : const <SitePhoto>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Ảnh khảo sát')),
      body: photos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có ảnh khảo sát. Chụp ảnh hoặc chọn ảnh từ thư viện, sau đó gắn marker tương ứng trên mặt bằng.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: photos.length,
              itemBuilder: (_, index) {
                final photo = photos[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StoredImage(
                          path: photo.thumbnailPath ?? photo.originalPath,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    photo.caption.isEmpty
                                        ? 'Ảnh khảo sát ${index + 1}'
                                        : photo.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (photo.note.isNotEmpty)
                                    Text(
                                      photo.note,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa ảnh',
                              onPressed: () => _deletePhoto(photo),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Chọn từ thư viện'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Chụp ảnh'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final photos = await _service.pick(
        projectId: widget.projectId,
        source: source,
      );
      if (!mounted) return;
      for (final photo in photos) {
        final annotated = await _describe(photo);
        if (annotated != null && mounted) {
          await context.read<SiteLayoutProvider>().addPhoto(annotated);
        } else if (annotated == null) {
          await deleteSiteLayoutFile(photo.originalPath);
          if (photo.thumbnailPath != null) {
            await deleteSiteLayoutFile(photo.thumbnailPath!);
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể thêm ảnh: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto(SitePhoto photo) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ảnh khảo sát?'),
        content: const Text(
          'Ảnh và tất cả marker đang liên kết với ảnh này sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await context.read<SiteLayoutProvider>().deletePhoto(photo);
    }
  }

  Future<SitePhoto?> _describe(SitePhoto photo) async {
    final caption = TextEditingController(text: photo.caption);
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông tin ảnh khảo sát'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: caption,
              decoration: const InputDecoration(labelText: 'Chú thích ảnh'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ghi chú hiện trường',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bỏ ảnh'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu ảnh'),
          ),
        ],
      ),
    );
    final result = accepted == true
        ? SitePhoto(
            id: photo.id,
            projectId: photo.projectId,
            originalPath: photo.originalPath,
            thumbnailPath: photo.thumbnailPath,
            caption: caption.text.trim(),
            note: note.text.trim(),
            capturedAt: photo.capturedAt,
            createdAt: photo.createdAt,
          )
        : null;
    caption.dispose();
    note.dispose();
    return result;
  }
}

class _StoredImage extends StatelessWidget {
  const _StoredImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: readSiteLayoutFile(path),
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
