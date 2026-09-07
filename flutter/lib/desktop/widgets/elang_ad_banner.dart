// Panel iklan Elang di beranda.
//
// Menyedot https://iklan.elangapp.net/api/ads.json (dikelola lewat panel admin
// Elang Ads), bukan me-render halaman /banner di dalam webview. Alasannya:
// webview di Windows bersandar pada WebView2 Runtime yang belum tentu ada di
// Windows 10 lama - persis mesin pelanggan yang paling butuh diremote. Dengan
// menggambar sendiri, tidak ada dependency baru sama sekali: paket http dan
// url_launcher sudah dipakai RustDesk.
//
// Kalau server tidak terjangkau atau belum ada iklan aktif, panel ini
// menghilang sama sekali sehingga aplikasi tampil seperti biasa.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String kElangAdsUrl = 'https://iklan.elangapp.net/api/ads.json';

/// Seberapa sering daftar iklan diambil ulang. Iklan baru yang dibuat di panel
/// muncul di client paling lama selang waktu ini, tanpa aplikasi ditutup.
const Duration kElangAdsRefresh = Duration(minutes: 5);

const double kElangAdHeight = 172;

class _ElangAd {
  final String title;
  final String subtitle;
  final String ctaText;
  final String linkUrl;
  final String photoUrl;
  final Color bgColor;

  _ElangAd({
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.linkUrl,
    required this.photoUrl,
    required this.bgColor,
  });

  static Color _parseColor(String? v) {
    const fallback = Color(0xFF29267F); // biru Elang
    if (v == null) return fallback;
    final hex = v.replaceAll('#', '').trim();
    if (hex.length != 6) return fallback;
    final n = int.tryParse(hex, radix: 16);
    return n == null ? fallback : Color(0xFF000000 | n);
  }

  static _ElangAd? fromJson(dynamic j) {
    if (j is! Map) return null;
    final title = (j['title'] ?? '').toString();
    final subtitle = (j['subtitle'] ?? '').toString();
    if (title.isEmpty && subtitle.isEmpty) return null;
    return _ElangAd(
      title: title,
      subtitle: subtitle,
      ctaText: (j['cta_text'] ?? '').toString(),
      linkUrl: (j['link_url'] ?? '').toString(),
      photoUrl: (j['photo_url'] ?? '').toString(),
      bgColor: _parseColor(j['bg_color']?.toString()),
    );
  }
}

class ElangAdBanner extends StatefulWidget {
  const ElangAdBanner({Key? key}) : super(key: key);

  @override
  State<ElangAdBanner> createState() => _ElangAdBannerState();
}

class _ElangAdBannerState extends State<ElangAdBanner> {
  List<_ElangAd> _ads = [];
  int _index = 0;
  int _slideSeconds = 8;
  Timer? _rotateTimer;
  Timer? _refreshTimer;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer = Timer.periodic(kElangAdsRefresh, (_) => _fetch());
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await http
          .get(Uri.parse(kElangAdsUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return;
      final list = <_ElangAd>[];
      for (final item in (body['ads'] as List? ?? [])) {
        final ad = _ElangAd.fromJson(item);
        if (ad != null) list.add(ad);
      }
      final secs = body['slide_seconds'];
      if (!mounted) return;
      setState(() {
        _ads = list;
        if (secs is int && secs >= 2 && secs <= 60) _slideSeconds = secs;
        if (_index >= _ads.length) _index = 0;
      });
      _restartRotation();
    } catch (_) {
      // Server iklan tidak wajib hidup agar aplikasi berfungsi - diamkan saja.
    }
  }

  void _restartRotation() {
    _rotateTimer?.cancel();
    if (_ads.length < 2) return;
    _rotateTimer = Timer.periodic(Duration(seconds: _slideSeconds), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _ads.length);
    });
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url));
    } catch (_) {}
  }

  /// Animasi masuk diundi tiap pergantian, meniru banner web: satu iklan yang
  /// sama tidak selalu muncul dengan gerakan yang sama.
  Widget _transition(Widget child, Animation<double> anim) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    switch (_rand.nextInt(4)) {
      case 0:
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .25), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      case 1:
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.18, 0), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      case 2:
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .88, end: 1).animate(curved),
            child: child,
          ),
        );
      default:
        return FadeTransition(opacity: curved, child: child);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final ad = _ads[_index];
    return Container(
      height: kElangAdHeight,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ad.bgColor, const Color(0xFF111111)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(ad.linkUrl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 620),
            transitionBuilder: _transition,
            child: _slide(ad, key: ValueKey(_index)),
          ),
        ),
      ),
    );
  }

  Widget _slide(_ElangAd ad, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(26, 18, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ad.title.isNotEmpty)
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                if (ad.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      ad.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.93),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (ad.ctaText.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 140),
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withOpacity(.42)),
              ),
              child: Text(
                ad.ctaText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          if (ad.photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  ad.photoUrl,
                  height: kElangAdHeight - 44,
                  fit: BoxFit.contain,
                  // Gambar gagal dimuat tidak boleh merusak tata letak iklan.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
