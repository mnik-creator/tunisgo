// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/helpers/locale_provider.dart';
import '../../core/helpers/theme_provider.dart';
import '../../core/models/station.dart';
import '../../core/models/stop_time.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/db_update_service.dart';
import '../favorites/favorites_provider.dart';

final _settingsStationsMapProvider =
    FutureProvider<Map<String, Station>>((ref) async {
  final stations = await ref.read(stationRepositoryProvider).getAllStations();
  return {for (final s in stations) s.id: s};
});

final _settingsTripStopTimesProvider =
    FutureProvider.family<List<StopTime>, String>((ref, tripId) {
  return ref.read(tripRepositoryProvider).getStopTimesForTrip(tripId);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentTheme = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const supportedLocales = [
      (code: 'fr', label: 'Français'),
      (code: 'ar', label: 'العربية'),
      (code: 'en', label: 'English'),
      (code: 'ru', label: 'Русский'),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 24),
        children: [
          Text(
            loc.settings,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // ── My Favorites ─────────────────────────────────────────────────
          _SectionHeader(label: loc.my_favorites),
          const SizedBox(height: 8),
          _FavoritesCard(isDark: isDark, loc: loc),
          const SizedBox(height: 24),

          // ── Preferences ──────────────────────────────────────────────────
          _SectionHeader(label: loc.preferences),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme pill selector
                _PillSelectorCard(
                  children: [
                    _PillButton(
                      icon: Icons.light_mode_outlined,
                      label: loc.theme_light,
                      selected: currentTheme == ThemeMode.light,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setTheme(ThemeMode.light),
                    ),
                    _PillButton(
                      icon: Icons.dark_mode_outlined,
                      label: loc.theme_dark,
                      selected: currentTheme == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setTheme(ThemeMode.dark),
                    ),
                    _PillButton(
                      icon: Icons.settings_brightness_outlined,
                      label: loc.theme_system,
                      selected: currentTheme == ThemeMode.system,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .setTheme(ThemeMode.system),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Language dropdown
                Row(
                  children: [
                    const Icon(Icons.language, color: kEmerald500, size: 20),
                    const SizedBox(width: 12),
                    Text(loc.language, style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    DropdownButton<String>(
                      value: currentLocale.languageCode,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: supportedLocales
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.code,
                              child: Text(
                                l.label,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (code) {
                        if (code != null) {
                          ref
                              .read(localeProvider.notifier)
                              .setLocale(Locale(code));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader(label: loc.about),
          const SizedBox(height: 12),
          _AboutCard(isDark: isDark, loc: loc),
        ],
      ),
    );
  }
}

// ── Favorites card ───────────────────────────────────────────────────────────

class _FavoritesCard extends ConsumerWidget {
  const _FavoritesCard({required this.isDark, required this.loc});
  final bool isDark;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteTripIdsProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 16, color: kEmerald500),
              const SizedBox(width: 6),
              Text(
                loc.favorites_reminder_info,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (favorites.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              loc.no_favorites,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...favorites.map((tripId) => _FavoriteRouteRow(
                  tripId: tripId,
                  loc: loc,
                )),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.star_border, size: 16),
              label: Text(loc.see_favorites,
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.push('/favorites'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteRouteRow extends ConsumerWidget {
  const _FavoriteRouteRow({required this.tripId, required this.loc});
  final String tripId;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopTimesAsync = ref.watch(_settingsTripStopTimesProvider(tripId));
    final stationsAsync = ref.watch(_settingsStationsMapProvider);
    final locale = ref.watch(localeProvider);

    final routeLabel = stopTimesAsync.whenOrNull(
      data: (stopTimes) {
        if (stopTimes.isEmpty) return null;
        return stationsAsync.whenOrNull(
          data: (stationsMap) {
            final origin = stationsMap[stopTimes.first.stationId];
            final dest = stationsMap[stopTimes.last.stationId];
            if (origin == null || dest == null) return null;
            return '${origin.localizedName(locale.languageCode)} → ${dest.localizedName(locale.languageCode)}';
          },
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.train_outlined, size: 16, color: kEmerald500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc.train_number} $tripId',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (routeLabel != null)
                  Text(
                    routeLabel,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(favoriteTripIdsProvider.notifier).remove(tripId),
            child: Icon(Icons.star, size: 18, color: Colors.amber.shade600),
          ),
        ],
      ),
    );
  }
}

// ── About card ───────────────────────────────────────────────────────────────

class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.isDark, required this.loc});
  final bool isDark;
  final AppLocalizations loc;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  String _localVersion = '…';
  String _appVersion = '…';
  bool _isChecking = false;
  double? _progress;
  String? _resultMsg;

  @override
  void initState() {
    super.initState();
    DbUpdateService.getLocalVersion().then((v) {
      if (mounted) setState(() => _localVersion = v);
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _isChecking = true;
      _progress = null;
      _resultMsg = null;
    });

    final status = await DbUpdateService.checkAndUpdate(
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;

    final msg = switch (status) {
      DbUpdateStatus.updated => widget.loc.schedule_updated_success,
      DbUpdateStatus.upToDate => widget.loc.schedule_up_to_date,
      DbUpdateStatus.noConnection => widget.loc.error_no_connection,
      DbUpdateStatus.serverError => widget.loc.error_server_unavailable,
      DbUpdateStatus.checksumMismatch ||
      DbUpdateStatus.unknown =>
        widget.loc.error_download_retry,
    };

    if (status == DbUpdateStatus.updated) {
      final v = await DbUpdateService.getLocalVersion();
      if (mounted) setState(() => _localVersion = v);
    }

    setState(() {
      _isChecking = false;
      _progress = null;
      _resultMsg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App identity row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.train, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'TunisGO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                widget.loc.app_version,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 4),
              Text(
                _appVersion,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            widget.loc.disclaimer,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey.shade200),

          // DB version + update
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_outlined,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Text(
                      widget.loc.version_label,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    Text(
                      _localVersion,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isChecking)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 3,
                        ),
                      ),
                      if (_progress != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(_progress! * 100).toInt()}%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sync, size: 16),
                    label: Text(
                      widget.loc.check_for_updates,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _checkUpdate,
                  ),
                if (_resultMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _resultMsg!,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),

          // Report issue
          InkWell(
            onTap: () => _showReportSheet(context, widget.loc),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.bug_report_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Text(widget.loc.report_issue,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade700)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),

          // Privacy policy
          InkWell(
            onTap: () => _showPrivacyPolicy(context, widget.loc),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Text(widget.loc.privacy_policy,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade700)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),

          // Terms of Service
          InkWell(
            onTap: () => _showTermsOfService(context, widget.loc),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Text(widget.loc.terms_of_service,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade700)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),

          // License
          InkWell(
            onTap: () => _showLicense(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.gavel_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Text(
                    'License',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportSheet(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportIssueSheet(loc: loc),
    );
  }

  void _showTermsOfService(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HtmlSheet(
        assetPath: 'terms-of-service.html',
        title: 'Terms of Service',
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HtmlSheet(
        assetPath: 'privacy-policy.html',
        title: 'Privacy Policy',
      ),
    );
  }

  void _showLicense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TextAssetSheet(
        assetPath: 'LICENSE',
        title: 'License',
      ),
    );
  }
}

// ── Report issue bottom sheet (email only) ───────────────────────────────────

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({required this.loc});
  final AppLocalizations loc;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  static const _supportEmail = 'mnik.dev@proton.me';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    setState(() => _sending = true);
    final subject = Uri.encodeComponent(widget.loc.report_issue_subject);
    final body = Uri.encodeComponent(_controller.text.trim());
    final uri = Uri.parse('mailto:$_supportEmail?subject=$subject&body=$body');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) Navigator.of(context).pop();
      } else {
        await Clipboard.setData(const ClipboardData(text: _supportEmail));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_supportEmail copied to clipboard')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.loc.report_issue_title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: widget.loc.report_issue_hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.email_outlined),
              label: Text(widget.loc.report_issue_send),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed:
                  (_sending || _controller.text.trim().isEmpty) ? null : _sendEmail,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy-policy bottom sheet (WebView) ────────────────────────────────────

class _HtmlSheet extends StatefulWidget {
  const _HtmlSheet({required this.assetPath, required this.title});
  final String assetPath;
  final String title;

  @override
  State<_HtmlSheet> createState() => _HtmlSheetState();
}

class _HtmlSheetState extends State<_HtmlSheet> {
  late final WebViewController _wvController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _wvController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
    rootBundle.loadString(widget.assetPath).then((html) {
      _wvController.loadHtmlString(html);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _wvController),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plain-text asset bottom sheet (License) ──────────────────────────────────

class _TextAssetSheet extends StatefulWidget {
  const _TextAssetSheet({required this.assetPath, required this.title});
  final String assetPath;
  final String title;

  @override
  State<_TextAssetSheet> createState() => _TextAssetSheetState();
}

class _TextAssetSheetState extends State<_TextAssetSheet> {
  String? _content;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(widget.assetPath).then((text) {
      if (mounted) setState(() => _content = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _content == null
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: Text(
                        _content!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          fontFamily: 'monospace',
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _PillSelectorCard extends StatelessWidget {
  const _PillSelectorCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: children.map((c) => Expanded(child: c)).toList()),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kEmerald500 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
