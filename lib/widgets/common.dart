import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 36 : 42,
        height: compact ? 39 : 45,
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.sports_soccer,
          color: AppColors.forest,
          size: 26,
        ),
      ),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: AppColors.ink,
              ),
              children: [
                TextSpan(text: 'joga'),
                TextSpan(
                  text: 'contra',
                  style: TextStyle(color: AppColors.green),
                ),
              ],
            ),
          ),
          const Text(
            'ENCONTRE. COMBINE. JOGUE.',
            style: TextStyle(
              fontSize: 7,
              letterSpacing: 1.2,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );
}

class PitchLinesPainter extends CustomPainter {
  const PitchLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final field = Rect.fromLTWH(
      size.width * .48,
      size.height * .08,
      size.width * .46,
      size.height * .84,
    );
    canvas.drawRect(field, line);
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      line,
    );
    canvas.drawCircle(field.center, size.height * .17, line);
    canvas.drawRect(
      Rect.fromLTWH(
        field.left,
        field.top + field.height * .29,
        field.width * .2,
        field.height * .42,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        field.right - field.width * .2,
        field.top + field.height * .29,
        field.width * .2,
        field.height * .42,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Crest extends StatelessWidget {
  const Crest({super.key, this.label = 'UFC', this.small = false});
  final String label;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
    width: small ? 40 : 60,
    height: small ? 44 : 66,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2E8),
      border: Border.all(color: const Color(0xFFD5E1D4)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.forest,
            fontSize: small ? 9 : 11,
          ),
        ),
        Icon(
          label == 'RA' ? Icons.emoji_events_outlined : Icons.sports_soccer,
          color: AppColors.green,
          size: small ? 14 : 20,
        ),
        if (!small)
          const Text(
            '2015',
            style: TextStyle(fontSize: 7, color: AppColors.muted),
          ),
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            color: AppColors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}

class TagPill extends StatelessWidget {
  const TagPill(
    this.text, {
    super.key,
    this.green = false,
    this.orange = false,
  });
  final String text;
  final bool green, orange;
  @override
  Widget build(BuildContext context) {
    final bg = green
        ? const Color(0xFFEAF4E8)
        : orange
        ? const Color(0xFFFFF1DC)
        : const Color(0xFFF2F4F2);
    final fg = green
        ? AppColors.green
        : orange
        ? const Color(0xFF98631E)
        : const Color(0xFF667168);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.outline = false,
    this.danger = false,
    this.expand = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outline, danger, expand;
  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFC64343)
        : outline
        ? Colors.white
        : AppColors.lime;
    final fg = danger ? Colors.white : AppColors.forest;
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: BorderSide(color: outline ? AppColors.border : bg),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});
  final Game game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Crest(label: game.crest),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${game.city} · ${game.distance}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            TagPill(game.sport, green: game.sport == 'Futebol'),
            TagPill(game.category),
            TagPill(game.level),
          ],
        ),
        const Divider(height: 22, color: AppColors.border),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.green,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${game.date} · ${game.time}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 21, top: 5),
          child: Text(
            game.place,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.circle, size: 8, color: AppColors.green),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Procurando adversário',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
            Flexible(
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward, size: 15),
                label: const Text('Ver detalhes'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const Icon(Icons.sports_soccer, size: 38, color: AppColors.green),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}
