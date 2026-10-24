import 'package:flutter/material.dart';

import '../core/input/localized_number.dart';
import '../core/input/vnd_words.dart';

/// Ô nhập tiền dùng chung: tự thêm dấu `,` hàng nghìn khi gõ, đơn vị bên
/// phải và dòng chữ đọc số tiền VNĐ ngay bên dưới (thay chỗ [helperText]
/// khi đã có số). [onChanged] và [validator] nhận giá trị đã bỏ dấu `,`,
/// ví dụ `16000000000`.
class MoneyFormField extends StatefulWidget {
  const MoneyFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.unit = 'VNĐ',
    this.showWords = true,
    this.decimalDigits = 0,
    this.border = const OutlineInputBorder(),
    this.isDense = false,
    this.onChanged,
    this.validator,
  });

  /// Văn bản điền sẵn phải đã có dấu `,` (xem [formatThousands]).
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? unit;

  /// Tắt khi số không phải VNĐ (ví dụ USD) hoặc khi chữ hiển thị chỗ khác.
  final bool showWords;

  /// Số chữ số lẻ cho phép sau dấu `.`; VNĐ để 0.
  final int decimalDigits;
  final InputBorder? border;
  final bool isDense;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  State<MoneyFormField> createState() => _MoneyFormFieldState();
}

class _MoneyFormFieldState extends State<MoneyFormField> {
  TextEditingController? _ownController;
  String? _words;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateWords);
    _words = _wordsFor(_controller.text);
  }

  @override
  void didUpdateWidget(MoneyFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_updateWords);
      _controller.addListener(_updateWords);
    }
    _words = _wordsFor(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateWords);
    _ownController?.dispose();
    super.dispose();
  }

  String? _wordsFor(String text) =>
      widget.showWords ? vndTextToWords(text) : null;

  void _updateWords() {
    final words = _wordsFor(_controller.text);
    if (words != _words) setState(() => _words = words);
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final onChanged = widget.onChanged;
    final validator = widget.validator;
    return TextFormField(
      controller: _controller,
      keyboardType: widget.decimalDigits > 0
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        ThousandsSeparatorInputFormatter(decimalDigits: widget.decimalDigits),
      ],
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixText: widget.unit,
        helperText: words ?? widget.helperText,
        helperMaxLines: 3,
        helperStyle: words == null
            ? null
            : TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
        errorMaxLines: 2,
        border: widget.border,
        isDense: widget.isDense,
      ),
      onChanged: onChanged == null
          ? null
          : (value) => onChanged(stripThousandsSeparators(value)),
      validator: validator == null
          ? null
          : (value) => validator(
              value == null ? null : stripThousandsSeparators(value),
            ),
    );
  }
}
