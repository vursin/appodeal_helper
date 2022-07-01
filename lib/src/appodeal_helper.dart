// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

class AppodealHelper {
  AppodealHelper._();

  /// Return true if ads are allowed and false otherwise.
  static late bool isAllowedAds;

  /// Return true if current platform is Android or iOS and false otherwise.
  static final isSupportedPlatform =
      UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  /// Internal variables
  static String _appodealKey = '';
  static List<AppodealAdType> _appodealTypes = [];
  static bool _forceShowAd = true;
  static bool _debugLog = false;

  static late CheckAllowAdsOption _checkAllowAdsOption;

  static bool _isConfiged = false;
  static bool _isInitialed = false;

  static void config({
    required bool forceShowAd,
    required String keyAndroid,
    required String keyIOS,
    required CheckAllowAdsOption checkAllowAdsOption,
    required List<AppodealAdType> appodealTypes,
    bool debugLog = false,
  }) {
    if (_isConfiged) return;
    _isConfiged = true;

    _appodealKey = UniversalPlatform.isAndroid ? keyAndroid : keyIOS;
    _appodealTypes = appodealTypes;
    _forceShowAd = forceShowAd;
    _debugLog = debugLog;
    _checkAllowAdsOption = checkAllowAdsOption;

    // Nếu key không được đặt thì không hiện Ads cho platform này
    if (_appodealKey == '' || !isSupportedPlatform) isAllowedAds = false;

    if (_forceShowAd) isAllowedAds = true;
  }

  /// Initial ConsentManager and Appodeal plugin.
  /// The plugin will automatically call this function when needed.
  static Future<void> initial() async {
    assert(_isConfiged == true,
        'Must call `AppodealHelper.config` before showing Ad');

    // Không triển khai ad ở ngoài 2 platform này
    if (_isInitialed) return;
    _isInitialed = true;

    if (_forceShowAd) {
      isAllowedAds = true;
    } else {
      // Kiểm tra phiên bản có cho phép Ads không
      isAllowedAds =
          await _checkAllowedAds(checkAllowAdsOption: _checkAllowAdsOption);
    }

    if (!isAllowedAds) return;

    // await Future.wait([
    Appodeal.setTesting(_forceShowAd); //only not release mode
    Appodeal.setLogLevel(
      _debugLog ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone,
    );
    Appodeal.muteVideosIfCallsMuted(true);
    Appodeal.setUseSafeArea(true);
    // ]);

    await Appodeal.initialize(
      appKey: _appodealKey,
      adTypes: [for (final type in _appodealTypes) type],
    );
  }

  /// Destroy all Appodeal Ads. Default is to destroy all Appodeal ads.
  static Future<void> dispose(
      [AppodealAdType type = AppodealAdType.All]) async {
    // Không triển khai ad ở ngoài 2 platform này hoặc không hỗ trợ Ads
    if (!isSupportedPlatform || !isAllowedAds) return;

    await Appodeal.destroy(type);
  }

  /// Get banner Widget
  static Widget get bannerWidget => const _BannerAd();

  /// Get MREC Widget
  static Widget get mrecWidget => const _MrecAd();

  /// Hide specific ad
  static Future<void> hideAd(AppodealAdType type) async {
    await initial();
    return Appodeal.hide(type);
  }

  /// Show specific ad
  ///
  /// Returns true if ad can be shown with this placement, otherwise false.
  static Future<bool> showAd(AppodealAdType type) async {
    await initial();
    return Appodeal.show(type);
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
  final bool cloudAllowed;

  CheckAllowAdsOption({
    required this.prefVersion,
    required this.appVersion,
    required this.currentCount,
    required this.allowAfterCount,
    required this.writePref,
    required this.cloudAllowed,
  });

  @override
  String toString() {
    return 'CheckAllowAdsOption(prefVersion: $prefVersion, appVersion: $appVersion, count: $currentCount, allowAfterCount: $allowAfterCount, cloudAllowed: $cloudAllowed)';
  }
}

class _BannerAd extends StatelessWidget {
  const _BannerAd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppodealHelper.initial(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return AppodealHelper.isAllowedAds
            ? const AppodealBanner(
                adSize: AppodealBannerSize.BANNER,
                placement: "default",
              )
            : const SizedBox.shrink();
      },
    );
  }
}

class _MrecAd extends StatelessWidget {
  const _MrecAd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppodealHelper.initial(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return AppodealHelper.isAllowedAds
            ? const AppodealBanner(
                adSize: AppodealBannerSize.MEDIUM_RECTANGLE,
                placement: "default",
              )
            : const SizedBox.shrink();
      },
    );
  }
}

/// Kiểm tra phiên bản cũ trên máy, nếu khác với phiên bản app đang chạy
/// thì sẽ không hiện Ads (tránh tình trạng bot của Google click nhầm).
/// Sẽ đếm số lần mở app, nếu đủ 3 lần sẽ cho phép mở Ads lại.
Future<bool> _checkAllowedAds({
  required CheckAllowAdsOption checkAllowAdsOption,
}) async {
  if (checkAllowAdsOption.prefVersion != checkAllowAdsOption.appVersion) {
    checkAllowAdsOption.writePref(checkAllowAdsOption.appVersion, 1);

    _printDebug(
      'Pref config không hiện Ads cho phiên bản này: $checkAllowAdsOption',
    );

    return false;
  }

  if (checkAllowAdsOption.currentCount >= checkAllowAdsOption.allowAfterCount) {
    // Nếu cloud không cho hiện Ads thì không cho hiện Ads nhưng những bước
    // còn lại vẫn phải thực hiện.
    if (!checkAllowAdsOption.cloudAllowed) {
      _printDebug('Firebase remote config không hiện Ads cho phiên bản này');
      return false;
    }

    return true;
  }

  checkAllowAdsOption.writePref(
    checkAllowAdsOption.appVersion,
    checkAllowAdsOption.currentCount + 1,
  );

  _printDebug(
    'Pref config không hiện Ads cho phiên bản này: $checkAllowAdsOption',
  );

  return false;
}

_printDebug(Object? object) =>
    // ignore: avoid_print
    AppodealHelper._debugLog ? print('[Appodeal Helper]: $object') : null;
