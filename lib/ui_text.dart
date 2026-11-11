import 'package:flutter/material.dart';
import 'l10n.dart';

/// Text that follows the app display language.
class Tx extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const Tx(this.data,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) => Text(L10n.I.tr(data),
      style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}

/// Text with values in it, such as "Page {1}".
class Txf extends StatelessWidget {
  final String template;
  final List<Object> values;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const Txf(this.template, this.values,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) => Text(L10n.I.trf(template, values),
      style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}
