import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/project.dart';
import '../models/project_attachment.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';
import 'project_file_storage.dart';

abstract final class ProjectReportPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleGreen = PdfColor(235, 247, 241);
  static final _paleBlue = PdfColor(243, 247, 249);

  static Future<Uint8List> build({
    required Project project,
    required List<ProjectStage> stages,
    required List<ProjectStageSubmission> submissions,
    required List<ProjectAttachment> attachments,
  }) async {
    final generatedAt = DateTime.now();
    final fonts = await _ProjectPdfFonts.load();
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final stamp = Uint8List.sublistView(
      await rootBundle.load('assets/images/verified_dtc_product_ink.png'),
    );
    final photoBytes = <String, Uint8List>{};
    for (final attachment in attachments.where(
      (item) => item.fileType == ProjectFileType.photo,
    )) {
      final bytes = await readProjectFile(attachment.displayPath);
      if (bytes != null && bytes.isNotEmpty) photoBytes[attachment.id] = bytes;
    }

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..orientation = PdfPageOrientation.landscape
      ..margins.all = 0;
    _drawOverview(
      document.pages.add(),
      project,
      stages,
      submissions,
      logo,
      stamp,
      fonts,
      generatedAt,
    );
    for (final stage in stages) {
      final updates =
          submissions
              .where(
                (item) => item.stageId == stage.id && !item.isFinalConfirmation,
              )
              .toList()
            ..sort((a, b) => a.workDate.compareTo(b.workDate));
      final stagePhotos = attachments
          .where(
            (item) =>
                item.stageId == stage.id &&
                item.fileType == ProjectFileType.photo,
          )
          .toList();
      _sortStagePhotos(stagePhotos, updates);
      
      final attachmentsById = {for (final item in stagePhotos) item.id: item};
      final usedPhotoIds = <String>{};
      final groups = <(ProjectStageSubmission?, List<ProjectAttachment>)>[];
      for (final update in updates) {
        final groupPhotos =
            (update.data['photoIds'] as List<dynamic>? ?? const [])
                .map((id) => attachmentsById['$id'])
                .whereType<ProjectAttachment>()
                .toList()
              ..sort(
                (a, b) =>
                    _categoryRank(a.category)
                        .compareTo(_categoryRank(b.category)),
              );
        usedPhotoIds.addAll(groupPhotos.map((item) => item.id));
        groups.add((update, groupPhotos));
      }
      final unmatched = stagePhotos
          .where((item) => !usedPhotoIds.contains(item.id))
          .toList();
      if (unmatched.isNotEmpty) groups.add((null, unmatched));

      if (groups.isEmpty) {
        _drawStagePage(
          document.pages.add(),
          project,
          stage,
          null,
          [],
          updates.length,
          photoBytes,
          stamp,
          fonts,
          generatedAt,
        );
      } else {
        for (final group in groups) {
          final update = group.$1;
          final allPhotos = group.$2;
          
          if (allPhotos.isEmpty) {
            _drawStagePage(
              document.pages.add(),
              project,
              stage,
              update,
              [],
              updates.length,
              photoBytes,
              stamp,
              fonts,
              generatedAt,
            );
          } else {
            const maxPhotosPerPage = 4;
            for (var i = 0; i < allPhotos.length; i += maxPhotosPerPage) {
              final chunk = allPhotos.sublist(
                i,
                math.min(i + maxPhotosPerPage, allPhotos.length),
              );
              _drawStagePage(
                document.pages.add(),
                project,
                stage,
                update,
                chunk,
                updates.length,
                photoBytes,
                stamp,
                fonts,
                generatedAt,
              );
            }
          }
        }
      }
    }
    for (var index = 0; index < document.pages.count; index++) {
      _footer(
        document.pages[index],
        fonts,
        index + 1,
        document.pages.count,
      );
    }
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static void _sortStagePhotos(
    List<ProjectAttachment> photos,
    List<ProjectStageSubmission> updates,
  ) {
    final dates = <String, DateTime>{};
    for (final update in updates) {
      for (final id
          in (update.data['photoIds'] as List<dynamic>? ?? const [])) {
        dates['$id'] = update.workDate;
      }
    }
    int categoryOrder(ProjectAttachment item) =>
        switch (_categorySuffix(item.category)) {
          'rawMaterial' => 0,
          'finishedProduct' => 1,
          'rejectProduct' => 2,
          _ => 3,
        };
    photos.sort((a, b) {
      final byCategory = categoryOrder(a).compareTo(categoryOrder(b));
      if (byCategory != 0) return byCategory;
      return (dates[a.id] ?? a.createdAt).compareTo(dates[b.id] ?? b.createdAt);
    });
  }

  static void _drawOverview(
    PdfPage page,
    Project project,
    List<ProjectStage> stages,
    List<ProjectStageSubmission> submissions,
    Uint8List logo,
    Uint8List stamp,
    _ProjectPdfFonts fonts,
    DateTime generatedAt,
  ) {
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 26.0;
    final width = size.width - margin * 2;
    _topBar(graphics, size);
    _drawImageContain(
      graphics,
      PdfBitmap(logo),
      const ui.Rect.fromLTWH(margin, 16, 135, 42),
    );
    _text(
      graphics,
      'BÁO CÁO THEO DÕI DỰ ÁN',
      fonts.bold(18),
      ui.Rect.fromLTWH(180, 18, width - 150, 24),
      color: _navy,
      align: PdfTextAlignment.right,
    );
    _text(
      graphics,
      'PROJECT TRACKING REPORT',
      fonts.regular(8.5),
      ui.Rect.fromLTWH(180, 41, width - 150, 14),
      color: _muted,
      align: PdfTextAlignment.right,
    );
    graphics.drawLine(
      PdfPen(_border),
      const ui.Offset(margin, 68),
      ui.Offset(size.width - margin, 68),
    );

    _section(graphics, fonts, 'I. THÔNG TIN DỰ ÁN', margin, 82, width);
    final model = project.machines.isEmpty ? '—' : project.machines.first.model;
    _keyValueGrid(
      graphics,
      fonts,
      [
        ('Tên dự án', project.projectName),
        ('Model máy', model),
        ('Địa điểm', project.location),
        (
          'Kỹ sư phụ trách',
          project.technicalEngineer.isEmpty ? '—' : project.technicalEngineer,
        ),
      ],
      margin,
      106,
      width * 0.65,
    );

    _section(graphics, fonts, 'II. TIẾN ĐỘ & THỜI GIAN THỰC HIỆN', margin, 188, width);
    var y = 214.0;
    for (final stage in stages) {
      graphics.drawRectangle(
        brush: PdfSolidBrush(
          stage.status == ProjectStageStatus.completed ? _paleGreen : _paleBlue,
        ),
        pen: PdfPen(_border, width: .5),
        bounds: ui.Rect.fromLTWH(margin, y, width, 45),
      );
      _text(
        graphics,
        '${stage.stageOrder + 1}. ${stage.stageName}',
        fonts.bold(10),
        ui.Rect.fromLTWH(margin + 11, y + 5, width * .42, 18),
        color: _navy,
      );
      _text(
        graphics,
        stage.status.label,
        fonts.bold(8.5),
        ui.Rect.fromLTWH(margin + width * .68, y + 5, width * .29 - 10, 18),
        color: stage.status == ProjectStageStatus.completed ? _green : _muted,
        align: PdfTextAlignment.right,
      );
      _text(
        graphics,
        'Bắt đầu: ${_dateTime(stage.startDate)}   •   Hoàn thành: ${_dateTime(stage.completedDate)}',
        fonts.regular(8),
        ui.Rect.fromLTWH(margin + 11, y + 27, width - 22, 13),
        color: _muted,
      );
      y += 50;
    }
    _verifiedStamp(
      graphics,
      stamp,
      size.width - margin - 67,
      size.height - 110,
    );
    _text(
      graphics,
      'Thời gian in:\n${_dateTime(generatedAt)}',
      fonts.regular(6),
      ui.Rect.fromLTWH(size.width - margin - 67, size.height - 54, 62, 16),
      color: _muted,
      align: PdfTextAlignment.center,
    );
  }

  static void _drawStagePage(
    PdfPage page,
    Project project,
    ProjectStage stage,
    ProjectStageSubmission? update,
    List<ProjectAttachment> groupPhotos,
    int totalUpdates,
    Map<String, Uint8List> photos,
    Uint8List stamp,
    _ProjectPdfFonts fonts,
    DateTime generatedAt,
  ) {
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 24.0;
    final width = size.width - margin * 2;
    _topBar(graphics, size);
    _text(
      graphics,
      stage.stageName.toUpperCase(),
      fonts.bold(17),
      ui.Rect.fromLTWH(margin, 18, width, 23),
      color: _navy,
    );
    _text(
      graphics,
      project.trackingTitle,
      fonts.regular(8.5),
      ui.Rect.fromLTWH(margin, 41, width, 14),
      color: _muted,
    );

    const top = 70.0;
    final bottom = size.height - 42;
    const leftWidth = 120.0;
    const gap = 10.0;
    final rightX = margin + leftWidth + gap;
    final rightWidth = size.width - margin - rightX;
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleBlue),
      pen: PdfPen(_border, width: .6),
      bounds: ui.Rect.fromLTWH(margin, top, leftWidth, bottom - top),
    );
    _text(
      graphics,
      'THỜI GIAN THỰC HIỆN',
      fonts.bold(7.8),
      const ui.Rect.fromLTWH(margin + 7, top + 8, leftWidth - 14, 16),
      color: _navy,
    );
    _text(
      graphics,
      'Bắt đầu:\n${_dateTime(stage.startDate)}\n\nHoàn thành:\n${_dateTime(stage.completedDate)}',
      fonts.regular(6.8),
      const ui.Rect.fromLTWH(margin + 7, top + 28, leftWidth - 14, 70),
      color: _muted,
      lineAlignment: PdfVerticalAlignment.top,
    );
    graphics.drawLine(
      PdfPen(_border, width: .5),
      const ui.Offset(margin + 7, top + 108),
      const ui.Offset(margin + leftWidth - 7, top + 108),
    );
    _text(
      graphics,
      'TRẠNG THÁI',
      fonts.bold(7.8),
      const ui.Rect.fromLTWH(margin + 7, top + 116, leftWidth - 14, 16),
      color: _navy,
    );
    _text(
      graphics,
      stage.status.label,
      fonts.regular(6.8),
      const ui.Rect.fromLTWH(margin + 7, top + 136, leftWidth - 14, 16),
      color: stage.status == ProjectStageStatus.completed ? _green : _muted,
      lineAlignment: PdfVerticalAlignment.top,
    );
    _verifiedStamp(graphics, stamp, margin + 7, bottom - 71);
    _text(
      graphics,
      'Thời gian in:\n${_dateTime(generatedAt)}',
      fonts.regular(6),
      ui.Rect.fromLTWH(margin + 7, bottom - 15, 62, 16),
      color: _muted,
      align: PdfTextAlignment.center,
    );

    _text(
      graphics,
      'KẾT QUẢ VÀ HÌNH ẢNH THEO NGÀY',
      fonts.bold(9),
      ui.Rect.fromLTWH(rightX, top, rightWidth, 16),
      color: _navy,
    );
    final gridTop = top + 22;
    final gridHeight = bottom - gridTop;
    
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleBlue),
      pen: PdfPen(_border, width: .6),
      bounds: ui.Rect.fromLTWH(rightX, gridTop, rightWidth, gridHeight),
    );

    if (update == null && groupPhotos.isEmpty) {
      _text(
        graphics,
        'Chưa có hình ảnh cho giai đoạn này.',
        fonts.regular(9),
        ui.Rect.fromLTWH(rightX, gridTop, rightWidth, gridHeight),
        color: _muted,
        align: PdfTextAlignment.center,
      );
      return;
    }

    final fontSize = 7.5;
    final productivity = '${update?.data['productivity'] ?? ''}'.trim();
    final note = '${update?.data['acceptanceNote'] ?? ''}'.trim();
    final hasExtra = productivity.isNotEmpty || note.isNotEmpty;
    final headerHeight = hasExtra ? 42.0 : 28.0;

    final dateString = update == null ? 'ẢNH CHƯA GẮN NGÀY' : _date(update.workDate);
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(rightX + 7, gridTop + 5, 85, 18),
    );
    _text(
      graphics,
      dateString,
      fonts.bold(8.5),
      ui.Rect.fromLTWH(rightX + 7, gridTop + 5, 85, 18),
      color: PdfColor(255, 255, 255),
      align: PdfTextAlignment.center,
    );

    _text(
      graphics,
      update == null
          ? 'Hình ảnh chưa thuộc bản cập nhật theo ngày.'
          : 'Kết quả: ${update.result}',
      fonts.regular(fontSize),
      ui.Rect.fromLTWH(rightX + 100, gridTop + 5, rightWidth - 107, 18),
      color: _navy,
    );
    if (hasExtra) {
      _text(
        graphics,
        [
          if (productivity.isNotEmpty) 'Năng suất: $productivity',
          if (note.isNotEmpty) 'Ghi chú: $note',
        ].join('   •   '),
        fonts.regular(fontSize),
        ui.Rect.fromLTWH(rightX + 7, gridTop + 25, rightWidth - 14, 14),
        color: _navy,
      );
    }
    graphics.drawLine(
      PdfPen(_border, width: .5),
      ui.Offset(rightX + 6, gridTop + headerHeight),
      ui.Offset(rightX + rightWidth - 6, gridTop + headerHeight),
    );

    final photosX = rightX + 7;
    final photosWidth = rightWidth - 14;
    final photosY = gridTop + headerHeight + 4;
    final photosHeight = gridHeight - headerHeight - 9;
    
    if (groupPhotos.isEmpty) {
      _text(
        graphics,
        'Chưa có hình ảnh cho ngày này.',
        fonts.regular(fontSize),
        ui.Rect.fromLTWH(photosX, photosY, photosWidth, photosHeight),
        color: _muted,
        align: PdfTextAlignment.center,
      );
      return;
    }
    
    final rows = groupPhotos.length > 2 ? 2 : 1;
    final columns = (groupPhotos.length + rows - 1) ~/ rows;
    const photoGap = 5.0;
    final cardWidth = (photosWidth - photoGap * (columns - 1)) / columns;
    final cardHeight = (photosHeight - photoGap * (rows - 1)) / rows;
    final captionHeight = 14.0;
    
    for (var index = 0; index < groupPhotos.length; index++) {
      final attachment = groupPhotos[index];
      final left = photosX + (index % columns) * (cardWidth + photoGap);
      final y = photosY + (index ~/ columns) * (cardHeight + photoGap);
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        pen: PdfPen(_border, width: .5),
        bounds: ui.Rect.fromLTWH(left, y, cardWidth, cardHeight),
      );
      final bytes = photos[attachment.id];
      if (bytes != null) {
        try {
          _drawImageContain(
            graphics,
            PdfBitmap(bytes),
            ui.Rect.fromLTWH(
              left + 3,
              y + 3,
              cardWidth - 6,
              cardHeight - captionHeight - 5,
            ),
          );
        } catch (_) {
          _photoPlaceholder(graphics, fonts, left, y, cardWidth, cardHeight);
        }
      } else {
        _photoPlaceholder(graphics, fonts, left, y, cardWidth, cardHeight);
      }
      _text(
        graphics,
        '${_categoryLabel(attachment.category)} • ${update == null ? 'Chưa gắn ngày' : _date(update.workDate)}',
        fonts.bold(6.5),
        ui.Rect.fromLTWH(
          left + 3,
          y + cardHeight - captionHeight,
          cardWidth - 6,
          captionHeight - 1,
        ),
        color: _navy,
        align: PdfTextAlignment.center,
      );
    }
  }

  static int _categoryRank(String category) =>
      switch (_categorySuffix(category)) {
        'rawMaterial' => 0,
        'finishedProduct' => 1,
        'rejectProduct' => 2,
        _ => 3,
      };

  static String _categorySuffix(String category) =>
      category.contains('|') ? category.split('|').last : category;

  static String _categoryLabel(String category) =>
      switch (_categorySuffix(category)) {
        'rawMaterial' => '1. Nguyên liệu',
        'finishedProduct' => '2. Thành phẩm',
        'rejectProduct' => '3. Phế phẩm',
        'compressorResult' => 'Kết quả vận hành',
        _ => 'Ảnh hiện trường',
      };

  static void _keyValueGrid(
    PdfGraphics graphics,
    _ProjectPdfFonts fonts,
    List<(String, String)> values,
    double x,
    double y,
    double width,
  ) {
    final cellWidth = width / 2;
    const rowHeight = 34.0;
    for (var index = 0; index < values.length; index++) {
      final left = x + (index % 2) * cellWidth;
      final top = y + (index ~/ 2) * rowHeight;
      graphics.drawRectangle(
        brush: PdfSolidBrush(
          index.isEven ? _paleBlue : PdfColor(255, 255, 255),
        ),
        pen: PdfPen(_border, width: .5),
        bounds: ui.Rect.fromLTWH(left, top, cellWidth, rowHeight),
      );
      _text(
        graphics,
        values[index].$1,
        fonts.regular(7),
        ui.Rect.fromLTWH(left + 7, top + 3, cellWidth - 14, 10),
        color: _muted,
      );
      _text(
        graphics,
        values[index].$2,
        fonts.bold(8.5),
        ui.Rect.fromLTWH(left + 7, top + 14, cellWidth - 14, 16),
        color: _navy,
      );
    }
  }

  static void _section(
    PdfGraphics graphics,
    _ProjectPdfFonts fonts,
    String title,
    double x,
    double y,
    double width,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(x, y + 1, 4, 16),
    );
    _text(
      graphics,
      title,
      fonts.bold(10),
      ui.Rect.fromLTWH(x + 10, y, width - 10, 18),
      color: _navy,
    );
  }

  static void _topBar(PdfGraphics graphics, ui.Size size) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
    );
  }

  static void _verifiedStamp(
    PdfGraphics graphics,
    Uint8List stamp,
    double x,
    double y,
  ) {
    _drawImageContain(
      graphics,
      PdfBitmap(stamp),
      ui.Rect.fromLTWH(x, y, 62, 54),
    );
  }

  static void _footer(
    PdfPage page,
    _ProjectPdfFonts fonts,
    int current,
    int total,
  ) {
    final size = page.getClientSize();
    page.graphics.drawLine(
      PdfPen(_border, width: .6),
      ui.Offset(24, size.height - 29),
      ui.Offset(size.width - 24, size.height - 29),
    );
    _text(
      page.graphics,
      'Project Timeline',
      fonts.regular(7.2),
      ui.Rect.fromLTWH(24, size.height - 23, size.width - 100, 12),
      color: _muted,
    );
    _text(
      page.graphics,
      '$current / $total',
      fonts.bold(7.2),
      ui.Rect.fromLTWH(size.width - 70, size.height - 23, 46, 12),
      color: _muted,
      align: PdfTextAlignment.right,
    );
  }

  static void _photoPlaceholder(
    PdfGraphics graphics,
    _ProjectPdfFonts fonts,
    double left,
    double top,
    double width,
    double height,
  ) {
    _text(
      graphics,
      'Không thể đọc ảnh',
      fonts.regular(7),
      ui.Rect.fromLTWH(left + 4, top + 4, width - 8, height - 8),
      color: _muted,
      align: PdfTextAlignment.center,
    );
  }

  static void _text(
    PdfGraphics graphics,
    String value,
    PdfFont font,
    ui.Rect bounds, {
    required PdfColor color,
    PdfTextAlignment align = PdfTextAlignment.left,
    PdfVerticalAlignment lineAlignment = PdfVerticalAlignment.middle,
  }) {
    graphics.drawString(
      value,
      font,
      brush: PdfSolidBrush(color),
      bounds: bounds,
      format: PdfStringFormat(alignment: align, lineAlignment: lineAlignment),
    );
  }

  static void _drawImageContain(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
  ) {
    final aspect = image.width / image.height;
    var width = bounds.width;
    var height = width / aspect;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * aspect;
    }
    graphics.drawImage(
      image,
      ui.Rect.fromLTWH(
        bounds.left + (bounds.width - width) / 2,
        bounds.top + (bounds.height - height) / 2,
        width,
        height,
      ),
    );
  }

  static void _drawImageCover(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
  ) {
    graphics.save();
    graphics.setClip(bounds: bounds);
    final boundsAspect = bounds.width / bounds.height;
    final imageAspect = image.width / image.height;
    double width, height;
    if (imageAspect > boundsAspect) {
      height = bounds.height;
      width = height * imageAspect;
    } else {
      width = bounds.width;
      height = width / imageAspect;
    }
    graphics.drawImage(
      image,
      ui.Rect.fromLTWH(
        bounds.left + (bounds.width - width) / 2,
        bounds.top + (bounds.height - height) / 2,
        width,
        height,
      ),
    );
    graphics.restore();
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _dateTime(DateTime? value) => value == null
      ? '—'
      : '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static String _duration(Duration value) {
    final days = value.inDays;
    final hours = value.inHours.remainder(24);
    final minutes = value.inMinutes.remainder(60);
    return '${days > 0 ? '$days ngày ' : ''}${hours}g ${minutes}p';
  }
}

class _ProjectPdfFonts {
  const _ProjectPdfFonts(this.regularBytes, this.boldBytes);
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  static Future<_ProjectPdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _ProjectPdfFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
