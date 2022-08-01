// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

final HiveInterface _hive = HiveImpl();
Box? _hiveBox;

class AppodealHelper {
  static final instance = AppodealHelper._();

  AppodealHelper._();

  /// Return true if ads are allowed and false otherwise.
  bool isAllowedAds = false;

  /// Return true if current platform is Android or iOS and false otherwise.
  final isSupportedPlatform =
      UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  /// Internal variables
  String _appodealKey = '';
  List<AppodealAdType> _appodealAdTypes = [];
  bool _forceShowAd = false;
  bool _isTestAd = true;
  bool _debugLog = false;

  bool _lastGuard = false;

  int _allowAfterCount = 3;

  bool _isConfiged = false;
  bool _isInitialed = false;

  int _maxAdReloadAttempts = 3;
  int _rewaredAttempts = 0;

  final Completer _configCompleter = Completer<bool>();

  static const String _prefix = 'AppodealHelper';

  /// Configure for appodeal helper
  ///
  /// [forceShowAd] Force to show ad if `true`. Default value is `false`.
  ///
  /// [isTestAd] Use test ad if `true`. Default value is `true`.
  ///
  /// [keyAndroid] Appodeal key for Android
  ///
  /// [keyIOS] Appodeal key for IOS
  ///
  /// [appodealAdTypes] Ad types that you want to show in your app
  ///
  /// [lastGuard] Last value to check for allowing to show ad or not. It can be a config on
  /// cloud (if this value is false then all other progress will be false).
  ///
  /// [allowAfterCount] Allow the app to show ads after this opening times
  ///
  /// [maxAdReloadAttempts] Use for interstitial and rewarded video. The ads will disable
  /// if the reloading times reach this value. (Prevent breaking Ads provider policy).
  ///
  /// [isShowConsent] The consent is automatically called when the app needs to show ad,
  /// if you want to call it before that, you need to set this value to `true`.
  ///
  /// [debugLog] show verbose debug log if `true`. Default value is `false`.
  void config({
    required bool forceShowAd,
    required bool isTestAd,
    required String keyAndroid,
    required String keyIOS,
    required List<AppodealAdType> appodealAdTypes,

    /// Last value to check for allowing show ad or not. It can be a config on
    /// cloud (if this value is false then all other progress will be false).
    bool lastGuard = true,
    int allowAfterCount = 3,
    int maxAdReloadAttempts = 3,
    bool debugLog = false,
    bool isShowConsent = false,
  }) {
    if (_isConfiged) return;
    _isConfiged = true;

    _appodealKey = UniversalPlatform.isAndroid ? keyAndroid : keyIOS;
    _appodealAdTypes = appodealAdTypes;
    _forceShowAd = forceShowAd;
    _isTestAd = isTestAd;
    _debugLog = debugLog;
    _lastGuard = lastGuard;
    _allowAfterCount = allowAfterCount;
    _maxAdReloadAttempts = maxAdReloadAttempts;

    // Nếu key không được đặt thì không hiện Ads cho platform này
    if (_appodealKey == '' || !isSupportedPlatform) isAllowedAds = false;

    if (_forceShowAd) isAllowedAds = true;

    if (isShowConsent) {
      showConsent()
          .then((value) => _printDebug('Call showConsent result: $value'));
    }

    _configCompleter.complete(true);
  }

  /// Initial ConsentManager and Appodeal plugin.
  ///
  /// You dont need to use this method because the plugin will automatically call this method when needed.
  Future<bool> initial() async {
    // Không triển khai ad ở ngoài 2 platform này
    if (_isInitialed) {
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }
    _isInitialed = true;

    // Wait until config is called
    await _configCompleter.future;

    if (_forceShowAd) {
      isAllowedAds = true;

      _printDebug('Force to show Ad');
    } else {
      // Kiểm tra phiên bản có cho phép Ads không
      isAllowedAds = await _checkAllowedAds();
    }

    _printDebug('Is allowed Ads: $isAllowedAds');
    if (!isAllowedAds) return false;

    // await Future.wait([
    await Appodeal.setTesting(_isTestAd); //only not release mode
    await Appodeal.setLogLevel(
      _debugLog ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone,
    );
    await Appodeal.muteVideosIfCallsMuted(true);
    await Appodeal.setUseSafeArea(true);
    // ]);

    await Appodeal.initialize(
      appKey: _appodealKey,
      adTypes: [for (final type in _appodealAdTypes) type],
    );

    _printDebug('Appodeal has been initialized');
    return true;
  }

  /// Destroy all Appodeal Ads. Default is to destroy all Appodeal ads.
  Future<void> dispose([AppodealAdType type = AppodealAdType.All]) async {
    // Không triển khai ad ở ngoài 2 platform này hoặc không hỗ trợ Ads
    if (!isSupportedPlatform || !isAllowedAds) return;

    await Appodeal.destroy(type);
  }

  /// Get banner Widget
  Widget get bannerWidget => const _BannerAd();

  /// Get MREC Widget
  Widget get mrecWidget => const _MrecAd();

  /// Hide specific ad
  Future<void> hideAd(AppodealAdType type) async {
    if (!await initial()) return;
    return Appodeal.hide(type);
  }

  /// Show specific ad
  ///
  /// Returns true if ad can be shown with this placement, otherwise false.
  Future<bool> showAd(AppodealAdType type) async {
    if (!await initial()) return false;
    return Appodeal.show(type);
  }

  /// Is initialized ad
  Future<bool> isInitialized(AppodealAdType adType) async {
    if (!await initial()) return false;
    return Appodeal.isInitialized(adType);
  }

  /// Can show ad
  Future<bool> canShow(AppodealAdType adType) async {
    if (!await initial()) return false;
    return Appodeal.canShow(adType);
  }

  /// Show rewarded ad = [showAd(AppodealAdType.RewardedVideo)]
  Future<bool> showRewaredVideo() async {
    final isInitialized =
        await Appodeal.isInitialized(AppodealAdType.RewardedVideo);
    if (!isInitialized) {
      _printDebug('Rewarded video is not initialized, try again..');
      await Future.delayed(const Duration(milliseconds: 500));
      return showRewaredVideo();
    }
    _printDebug('Rewarded video is initialized!');

    final isCanShow = await Appodeal.canShow(AppodealAdType.RewardedVideo);
    if (!isCanShow) {
      _printDebug('Rewarded video can not show, try again..');
      await Future.delayed(const Duration(milliseconds: 500));
      return showRewaredVideo();
    }
    _printDebug('Rewarded video can show!');

    final isShowed = await showAd(AppodealAdType.RewardedVideo);
    if (!isShowed) {
      _rewaredAttempts++;
      if (_rewaredAttempts < _maxAdReloadAttempts) {
        _printDebug('Rewared video is not shown, try again...');
        await Future.delayed(const Duration(milliseconds: 500));
        return showRewaredVideo();
      } else {
        _printDebug('Rewared video is not shown, max attempts exceeded');
      }
    } else {
      _printDebug('Rewared video is shown!');
    }

    _rewaredAttempts = 0;

    return isShowed;
  }

  /// Show interstitial ad = [showAd(AppodealAdType.Interstitial)]
  Future<bool> showInterstitial() async {
    // TODO: Add more detail
    return showAd(AppodealAdType.Interstitial);
  }

  /// Show banner ad = [showAd(AppodealAdType.Banner)]
  Future<bool> showBanner() async {
    return showAd(AppodealAdType.Banner);
  }

  /// Set callbacks for Rewarded Video Ad
  void setRewardedVideoCallbacks({
    void Function(double amount, String reward)? onFinished,
    void Function(bool isFinished)? onClosed,
    void Function()? onClicked,
    void Function()? onFailed,
  }) {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) => {},
      onRewardedVideoFailedToLoad: onFailed,
      onRewardedVideoShown: () => {},
      onRewardedVideoShowFailed: onFailed,
      onRewardedVideoFinished: onFinished,
      onRewardedVideoClosed: onClosed,
      onRewardedVideoExpired: () => {},
      onRewardedVideoClicked: onClicked,
    );
  }

  /// Set callbacks for Interstitial Ad
  void setInterstitialCallbacks({
    void Function()? onClosed,
    void Function()? onClicked,
    void Function()? onFailed,
  }) {
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) => {},
      onInterstitialFailedToLoad: onFailed,
      onInterstitialShown: () => {},
      onInterstitialShowFailed: onFailed,
      onInterstitialClicked: onClicked,
      onInterstitialClosed: onClosed,
      onInterstitialExpired: () => {},
    );
  }

  /// Consent automatically called when you cal `config`
  Future<bool> showConsent() async {
    final completer = Completer<bool>();
    Appodeal.loadConsentForm(
        appKey: _appodealKey,
        onLoaded: () {
          Appodeal.showConsentForm(
            onClosed: () => completer.complete(true),
            onShowFailed: (error) => completer.complete(false),
          );
        },
        onLoadFailed: (error) => completer.complete(false));
    return completer.future;
  }
}

class CheckAllowAdsOption {
  /// Version read from prefs
  final String prefVersion;

  /// Version read from current app
  final String appVersion;

  /// Count read from prefs
  final int currentCount;

  /// Allow ads after this count
  final int allowAfterCount;

  /// Write to prefs callback
  final void Function(String, int) writePref;

  /// Config from cloud as a last checking before serving Ads. Default is false
  final bool lastGuard;

  CheckAllowAdsOption({
    required this.prefVersion,
    required this.appVersion,
    required this.currentCount,
    required this.allowAfterCount,
    required this.writePref,
    required this.lastGuard,
  });

  @override
  String toString() {
    return 'CheckAllowAdsOption(prefVersion: $prefVersion, appVersion: $appVersion, count: $currentCount, allowAfterCount: $allowAfterCount, cloudAllowed: $lastGuard)';
  }
}

class _BannerAd extends StatefulWidget {
  const _BannerAd({Key? key}) : super(key: key);

  @override
  State<_BannerAd> createState() => __BannerAdState();
}

class __BannerAdState extends State<_BannerAd> {
  @override
  void dispose() {
    Appodeal.destroy(AppodealAdType.Banner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppodealHelper.instance.initial(),
      builder: (_, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }

        return AppodealHelper.instance.isAllowedAds
            ? const AppodealBanner(
                adSize: AppodealBannerSize.BANNER,
                placement: "default",
              )
            : const SizedBox.shrink();
      },
    );
  }
}

class _MrecAd extends StatefulWidget {
  const _MrecAd({Key? key}) : super(key: key);

  @override
  State<_MrecAd> createState() => __MrecAdState();
}

class __MrecAdState extends State<_MrecAd> {
  @override
  void dispose() {
    Appodeal.destroy(AppodealAdType.MREC);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppodealHelper.instance.initial(),
      builder: (_, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }

        return AppodealHelper.instance.isAllowedAds
            ? const AppodealBanner(
                adSize: AppodealBannerSize.MEDIUM_RECTANGLE,
                placement: "default",
              )
            : const SizedBox.shrink();
      },
    );
  }
}

@visibleForTesting
Future<bool> checkAllowedAds() => _checkAllowedAds();

Future<Box> getHiveBox() async {
  if (_hiveBox != null) return _hiveBox!;

  await _hive.initFlutter(AppodealHelper._prefix);
  _hiveBox = await _hive.openBox(AppodealHelper._prefix);

  return _hiveBox!;
}

/// Kiểm tra phiên bản cũ trên máy, nếu khác với phiên bản app đang chạy
/// thì sẽ không hiện Ads (tránh tình trạng bot của Google click nhầm).
/// Sẽ đếm số lần mở app, nếu đủ `allowAfterCount` lần sẽ cho phép mở Ads lại.
Future<bool> _checkAllowedAds() async {
  final box = await getHiveBox();
  final packageInfo = await PackageInfo.fromPlatform();

  final checkAllowAdsOption = CheckAllowAdsOption(
    prefVersion: (box.get('prefVersion') as String?) ?? '1.0.0',
    appVersion: packageInfo.version,
    currentCount: (box.get('currentCount') as int?) ?? 1,
    allowAfterCount: AppodealHelper.instance._allowAfterCount,
    writePref: (version, count) {
      box.put('prefVersion', version);
      box.put('currentCount', count);
    },
    lastGuard: AppodealHelper.instance._lastGuard,
  );

  if (checkAllowAdsOption.prefVersion != checkAllowAdsOption.appVersion) {
    checkAllowAdsOption.writePref(checkAllowAdsOption.appVersion, 1);

    _printDebug(
      'Pref config do not allow showing Ad on this version: $checkAllowAdsOption',
    );

    return false;
  }

  final count = checkAllowAdsOption.currentCount + 1;

  if (count >= checkAllowAdsOption.allowAfterCount) {
    // Nếu cloud không cho hiện Ads thì không cho hiện Ads nhưng những bước
    // còn lại vẫn phải thực hiện.
    if (!checkAllowAdsOption.lastGuard) {
      _printDebug('lastGuard do not allow showing Ad');
      return false;
    }

    return true;
  }

  checkAllowAdsOption.writePref(
    checkAllowAdsOption.appVersion,
    count,
  );

  _printDebug(
    'Pref config do not allow showing Ad on this version: $checkAllowAdsOption',
  );

  return false;
}

_printDebug(Object? object) => AppodealHelper.instance._debugLog
    // ignore: avoid_print
    ? print('[Appodeal Helper]: $object')
    : null;
