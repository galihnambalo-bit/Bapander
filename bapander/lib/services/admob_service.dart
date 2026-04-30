import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  // Ad Unit IDs dari screenshot kamu
  static const String bannerAdUnitId = 'ca-app-pub-4744122948371705/5499211634';
  static const String nativeAdUnitId = 'ca-app-pub-4744122948371705/9246884957';
  static const String appOpenAdUnitId = 'ca-app-pub-4744122948371705/7095364334';
  static const String rewardedAdUnitId = 'ca-app-pub-4744122948371705/7853912232';

  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // ─── BANNER AD ────────────────────────────────────────────
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => print('Banner Ad loaded'),
        onAdFailedToLoad: (ad, err) {
          print('Banner Ad failed: $err');
          ad.dispose();
        },
      ),
    );
  }

  // ─── INTERSTITIAL AD (antara status) ──────────────────────
  Future<InterstitialAd?> loadInterstitialAd() async {
    InterstitialAd? ad;
    await InterstitialAd.load(
      adUnitId: 'ca-app-pub-4744122948371705/5499211634',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (loadedAd) => ad = loadedAd,
        onAdFailedToLoad: (err) => print('Interstitial failed: $err'),
      ),
    );
    return ad;
  }

  // ─── REWARDED AD (di cari teman) ──────────────────────────
  Future<RewardedAd?> loadRewardedAd() async {
    RewardedAd? ad;
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (loadedAd) => ad = loadedAd,
        onAdFailedToLoad: (err) => print('Rewarded failed: $err'),
      ),
    );
    return ad;
  }
}

// ─── BANNER AD WIDGET ─────────────────────────────────────
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = AdMobService().createBannerAd();
    ad.load().then((_) {
      if (mounted) setState(() {
        _bannerAd = ad;
        _isLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
