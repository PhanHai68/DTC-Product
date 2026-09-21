import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/dtc_palette.dart';

/// Hiển thị đúng nội dung người dùng đã nhập (tên hiển thị + dòng giới
/// thiệu) — không tự thêm lời chào hay icon. Dùng chung cho Home (đọc từ
/// [SettingsProvider]) và phần "Xem trước" ở màn Cá nhân hóa trang chủ (đọc
/// từ giá trị nháp đang chỉnh sửa), để hai nơi luôn hiển thị giống nhau.
class HomePersonalizationPreview extends StatelessWidget {
  const HomePersonalizationPreview({
    super.key,
    required this.displayName,
    required this.shortText,
    required this.nameFontSize,
    required this.nameColor,
    required this.shortTextFontSize,
    required this.shortTextColor,
  });

  final String displayName;
  final String shortText;
  final double nameFontSize;
  final Color? nameColor;
  final double shortTextFontSize;
  final Color? shortTextColor;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final name = displayName.trim();
    final text = shortText.trim();
    if (name.isEmpty && text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: FontWeight.w600,
              color: nameColor ?? palette.muted,
            ),
          ),
        if (text.isNotEmpty) ...[
          if (name.isNotEmpty) const SizedBox(height: 3),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: shortTextFontSize,
              fontWeight: FontWeight.w800,
              color: shortTextColor ?? palette.ink,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Khu vực cá nhân hóa hiển thị phía trên Home — tự ẩn khi người dùng chưa
/// bật, không chiếm nhiều không gian và không thay đổi cấu trúc Home hiện
/// tại. Đọc setting qua [SettingsProvider].
class HomePersonalizationWidget extends StatelessWidget {
  const HomePersonalizationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.homePersonalizationEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: HomePersonalizationPreview(
        displayName: settings.homeDisplayName,
        shortText: settings.homeShortText,
        nameFontSize: settings.homeNameFontSize,
        nameColor: settings.homeNameColor,
        shortTextFontSize: settings.homeShortTextFontSize,
        shortTextColor: settings.homeShortTextColor,
      ),
    );
  }
}
