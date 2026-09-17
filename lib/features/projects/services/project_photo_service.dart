import 'package:image_picker/image_picker.dart';

import 'project_file_storage.dart';

class ProjectPhotoService {
  ProjectPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<ProjectPickedPhoto?> pick({
    required String projectId,
    required ImageSource source,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2400,
    );
    if (picked == null) return null;
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last
        : 'jpg';
    final fileName =
        'project_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = await persistProjectFile(
      projectId: projectId,
      sourcePath: picked.path,
      fileName: fileName,
      bytes: await picked.readAsBytes(),
    );
    return ProjectPickedPhoto(fileName: fileName, path: path);
  }

  Future<List<ProjectPickedPhoto>> pickMany({
    required String projectId,
    required ImageSource source,
  }) async {
    if (source == ImageSource.camera) {
      final photo = await pick(projectId: projectId, source: source);
      return photo == null ? const [] : [photo];
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 2400,
    );
    final result = <ProjectPickedPhoto>[];
    for (var index = 0; index < picked.length; index++) {
      final item = picked[index];
      final extension = item.name.contains('.')
          ? item.name.split('.').last
          : 'jpg';
      final fileName =
          'project_${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
      final path = await persistProjectFile(
        projectId: projectId,
        sourcePath: item.path,
        fileName: fileName,
        bytes: await item.readAsBytes(),
      );
      result.add(ProjectPickedPhoto(fileName: fileName, path: path));
    }
    return result;
  }
}

class ProjectPickedPhoto {
  const ProjectPickedPhoto({required this.fileName, required this.path});
  final String fileName;
  final String path;
}
