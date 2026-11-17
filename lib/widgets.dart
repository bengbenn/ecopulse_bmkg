import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class PageList extends StatelessWidget {
  final List<Widget> children;
  const PageList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: children,
      ),
    ),
  );
}

class EcoCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  const EcoCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (dark ? C.charcoal : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final String? sub;
  const Section(this.title, {super.key, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (sub != null)
          Text(sub!, style: const TextStyle(fontSize: 12, color: C.slate)),
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class Metric extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final String? note;
  const Metric(
    this.label,
    this.value,
    this.unit,
    this.color, {
    super.key,
    this.note,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Container(
      color: isDark(context) ? C.charcoal : Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: C.slate, fontSize: 12),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      TextSpan(
                        text: unit.isEmpty ? '' : ' $unit',
                        style: const TextStyle(fontSize: 11, color: C.slate),
                      ),
                    ],
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: const TextStyle(fontSize: 10, color: C.slate),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Kolom input angka manual (tidak melompat kursor saat mengetik).
class NumField extends StatefulWidget {
  final String label, suffix;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const NumField({
    super.key,
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController c = TextEditingController(
    text: _fmt(widget.value),
  );

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void didUpdateWidget(NumField old) {
    super.didUpdateWidget(old);
    final p = double.tryParse(c.text.replaceAll(',', '.'));
    if (p != null && p != widget.value) c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: widget.suffix,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onChanged: (t) {
      final v = double.tryParse(t.replaceAll(',', '.'));
      if (v == null) return;
      widget.onChanged(v.clamp(widget.min, widget.max).toDouble());
    },
  );
}

/// Kartu penjelasan yang bisa dibuka-tutup.
class Explain extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  const Explain(
    this.icon,
    this.title,
    this.body, {
    super.key,
    this.color = C.emerald,
  });

  @override
  Widget build(BuildContext context) => EcoCard(
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: const TextStyle(fontSize: 13, height: 1.55)),
        ],
      ),
    ),
  );
}
