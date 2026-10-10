import 'package:flutter/material.dart';
import '../services/language_manager.dart';

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        // translateSync is instant — JSON is already loaded in memory at startup.
        // No async needed, so language switches are truly instantaneous (0ms).
        final displayText = LanguageManager.instance.translateSync(text);
        return Text(
          displayText,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}
