import 'dart:io';

void main() {
  final dest = File('lib/screens/paddy_color_sorter/paddy_color_sorter_screen.dart');
  var content = dest.readAsStringSync();

  // 1. Update the _showTechApplicationDialog
  final newDialog = '''
  void _showTechApplicationDialog(BuildContext context, String modelName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_mosaic,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chi Tiết Ứng Dụng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: const Text(
                    'Máy tách màu lúa giống và lúa cựa lứt SF7D Pro dùng để phân loại thóc và gạo xô tại cối hồi hoặc phễu của gầu tải (Tuỳ gầu), lượng gạo xô sau khi phân loại sẽ đi qua giai đoạn xát trắng mà không cần quay trở lại máy bóc vỏ, giúp giảm tỷ lệ gãy / vỡ đến 96%.\\n\\nĐồng thời, SF7D Pro giúp tăng sản lượng gạo xô thu hồi đến 99.99% sau giai đoạn gầu tải thóc.\\n\\nMáy tách màu lúa giống và lúa cựa lứt SF7D Pro được trang bị 7 máng với năng suất đạt được 3.5 - 7 tấn trong một giờ giúp sản lượng thành phẩm thu hoạch đạt được gấp 10 lần năng suất thông thường. Tuy có năng suất lớn nhưng công suất điện tiêu thụ chỉ đạt 3.5kW giúp tiết kiệm điện năng tốt nhất.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
              ),
              child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
''';
  final oldDialogRegex = RegExp(r'void _showTechApplicationDialog.*?\}\n\s*\}\n', dotAll: true);
  content = content.replaceFirst(oldDialogRegex, newDialog);
  
  // 2. Remove quick model selection
  // The quick model selection in color_sorter_screen is under "_buildSpecificationsTabs" specifically inside the second tab (tab index 2: "Thông số kỹ thuật").
  // It has a SizedBox(height: 70) and a ListView builder for models.
  // We can just regex replace it.
  final modelListRegex = RegExp(r'// -- Danh sách Model --.*?// -- Chi tiết thông số --', dotAll: true);
  content = content.replaceFirst(modelListRegex, '// -- Chi tiết thông số --');

  dest.writeAsStringSync(content);
}
