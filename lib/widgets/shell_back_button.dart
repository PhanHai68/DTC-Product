import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Nút quay lại cho màn nằm trong `ShellRoute` (Ngân hàng lỗi, Từ điển…).
///
/// Shell có Navigator con riêng, nên màn đầu tiên trong shell bị AppBar coi
/// là trang gốc và không tự hiện nút back. Android còn nút back hệ thống,
/// nhưng iOS/Safari web thì bị kẹt. Dùng làm `AppBar.leading`: ưu tiên pop
/// trong shell (vẫn tôn trọng PopScope), không được thì pop cả shell ra
/// ngoài, còn không có gì để pop (mở thẳng URL / tải lại trang) thì về Home.
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () async {
      if (await Navigator.of(context).maybePop() || !context.mounted) return;
      final router = GoRouter.of(context);
      router.canPop() ? router.pop() : router.go('/');
    },
  );
}
