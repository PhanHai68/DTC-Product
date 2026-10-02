import 'package:flutter/material.dart';

/// Chạy một thao tác ghi dữ liệu; nếu lỗi thì báo SnackBar và trả về false.
Future<bool> runSalesGoalAction(
  BuildContext context,
  Future<void> Function() action, {
  String errorMessage = 'Không thể lưu dữ liệu. Vui lòng thử lại.',
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    return true;
  } catch (error, stackTrace) {
    debugPrint('SalesGoal action failed: $error\n$stackTrace');
    messenger?.showSnackBar(SnackBar(content: Text(errorMessage)));
    return false;
  }
}
