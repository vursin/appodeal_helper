// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

enum AppodealType {
  banner(Appodeal.BANNER),
  bannerRight(Appodeal.BANNER_RIGHT),
  bannerTop(Appodeal.BANNER_TOP),
  bannerLeft(Appodeal.BANNER_LEFT),
  bannerBottom(Appodeal.BANNER_BOTTOM),
  native(Appodeal.NATIVE),
  interstitial(Appodeal.INTERSTITIAL),
  rewarded(Appodeal.REWARDED_VIDEO),
  mrec(Appodeal.MREC),
  all(Appodeal.ALL);

  final int toAppodeal;

  const AppodealType(this.toAppodeal);
}

class AppodealHelper {
  AppodealHelper._();

  /// Return true if ads are allowed and false otherwise.
  static late bool isAllowedAds;

  /// Return true if current platform is Android or iOS and false otherwise.
  static final isSupportedPlatform =
      UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  /// Internal variables
  static String _appodealKey = '';
  static List<AppodealType> _appodealTypes = [];
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
    required List<AppodealType> appodealTypes,
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
  static Future<void> _initial() async {
    assert(_isConfiged == true,
        'Must call `AppodealHelper.config` before showing Ad');

    // Không triển khai ad ở ngoài 2 platform này
    if (_isInitialed) return;
    _isInitialed = true;

    if (!isAllowedAds) return;

    await _getConsent();

    // Kiểm tra phiên bản có cho phép Ads không
    isAllowedAds =
        await _checkAllowedAds(checkAllowAdsOption: _checkAllowAdsOption);

    if (_forceShowAd) isAllowedAds = true;

    await Future.wait([
      Appodeal.setTesting(_forceShowAd), //only not release mode
      Appodeal.setLogLevel(
        _debugLog ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone,
      ),
      Appodeal.muteVideosIfCallsMuted(true),
      Appodeal.setUseSafeArea(true),
    ]);

    await Appodeal.initialize(
      _appodealKey,
      [for (final type in _appodealTypes) type.toAppodeal],
    );
  }

  /// Destroy all Appodeal Ads. Default is to destroy all Appodeal ads.
  static Future<void> dispose([AppodealType type = AppodealType.all]) async {
    // Không triển khai ad ở ngoài 2 platform này hoặc không hỗ trợ Ads
    if (!isSupportedPlatform || !isAllowedAds) return;

    await Appodeal.destroy(type.toAppodeal);
  }

  /// Get banner Widget
  static Widget get bannerWidget => const _BannerAd();

  /// Get MREC Widget
  static Widget get mrecWidget => const _MrecAd();

  /// Hide specific ad
  static Future<void> hideAd(AppodealType type) async {
    await _initial();
    return Appodeal.hide(type.toAppodeal);
  }

  /// Show specific ad
  ///
  /// Returns true if ad can be shown with this placement, otherwise false.
  static Future<bool> showAd(AppodealType type) async {
    await _initial();
    return Appodeal.show(type.toAppodeal);
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
      future: AppodealHelper._initial(),
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
      future: AppodealHelper._initial(),
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

Future<bool> _getConsent() async {
  // Không triển khai ad ở ngoài 2 platform này
  if (!AppodealHelper.isSupportedPlatform) return false;

  ConsentManager.setConsentInfoUpdateListener(
    (onConsentInfoUpdated, consent) => {_printDebug(consent)},
    (onFailedToUpdateConsentInfo, error) => {_printDebug(error)},
  );
  await ConsentManager.requestConsentInfoUpdate(AppodealHelper._appodealKey);

  if ((await ConsentManager.shouldShowConsentDialog()) == ShouldShow.TRUE) {
    ConsentManager.setConsentFormListener(
      (onConsentFormLoaded) => {_printDebug(onConsentFormLoaded)},
      (onConsentFormError, error) => {_printDebug(error)},
      (onConsentFormOpened) => _printDebug(onConsentFormOpened),
      (onConsentFormClosed, consent) => {_printDebug(consent)},
    );

    await ConsentManager.loadConsentForm();

    _printDebug(
      'is consent form loaded: ${await ConsentManager.consentFormIsLoaded()}',
    );
    if (await ConsentManager.consentFormIsLoaded()) {
      await ConsentManager.showAsDialogConsentForm();
      // ConsentManager.showAsActivityConsentForm();
    }
  }

  final consentStatus = await ConsentManager.getConsentStatus();
  final hasConsent = consentStatus == Status.PERSONALIZED ||
      consentStatus == Status.PARTLY_PERSONALIZED;

  return hasConsent;
}

_printDebug(Object? object) =>
    // ignore: avoid_print
    AppodealHelper._debugLog ? print('[Appodeal Helper]: $object') : null;
