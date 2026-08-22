import 'package:flutter/material.dart';

/// v2 addition (spec request: "app bar ko har screen par khoobsurat banayen,
/// professional aur international level ka" + "chooser/naming/edit screen
/// par app ka naam overflow ho jaata hai / title bar mukammal nazar nahi
/// aata"): one shared, on-brand gradient app bar used across every screen
/// in the app instead of each screen rolling its own plain `AppBar`.
///
/// Two things this fixes at the same time:
/// - Visual consistency: a subtle primary-color gradient, a soft bottom
///   highlight line, and a rounded leading icon badge — the same "premium"
///   language the splash screen already uses — replace the flat default
///   Material app bar on every screen.
/// - Overflow safety: the title (and optional subtitle) are always wrapped
///   in `Flexible` + `TextOverflow.ellipsis` with `maxLines: 1`, and the
///   whole title block sits in a `Row` that only ever takes the space left
///   over after actions — so a long app name next to a "Done" button (the
///   exact combination that used to clip on the capture/gallery screen) now
///   always ellipsizes instead of overflowing off the edge of the app bar.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.onLeadingTap,
    this.actions,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withOpacity(0.86)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              if (onLeadingTap != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  onPressed: onLeadingTap,
                )
              else
                const SizedBox(width: 8),
              if (leadingIcon != null && onLeadingTap == null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(leadingIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (actions != null) ...[
                IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
