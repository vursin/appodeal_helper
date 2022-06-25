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

  static bool isAllowedAds = false;

  static String _appodealKey = '';

  static List<AppodealType> _appodealTypes = [];

  static bool _isTesting = true;

  static bool _debugLog = false;

  static final isSupportedPlatform =
      UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  static bool _isInitialed = false;

  static Future<void> initial({
    required bool isTesting,
    required String keyAndroid,
    required String keyIOS,
    required CheckAllowAdsOption checkAllowAdsOption,
    required List<AppodealType> appodealTypes,
    bool debugLog = false,
  }) async {
    _appodealKey = UniversalPlatform.isAndroid ? keyAndroid : keyIOS;
    _appodealTypes = appodealTypes;
    _isTesting = isTesting;
    _debugLog = debugLog;

    // Không triển khai ad ở ngoài 2 platform này
    if (!isSupportedPlatform || _isInitialed) return;
    _isInitialed = true;

    // Nếu key không được đặt thì không hiện Ads cho platform này
    if (_appodealKey == '') {
      isAllowedAds = false;

      return;
    }

    await _getConsent();

    // Kiểm tra phiên bản có cho phép Ads không
    isAllowedAds =
        await _checkAllowedAds(checkAllowAdsOption: checkAllowAdsOption);

    if (isTesting) isAllowedAds = true;

    if (!isAllowedAds) return;

    await Future.wait([
      Appodeal.setTesting(_isTesting), //only not release mode
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

  static void dispose() async {
    // Không triển khai ad ở ngoài 2 platform này hoặc không hỗ trợ Ads
    if (!isSupportedPlatform || !isAllowedAds) return;

    await Future.wait(
      [for (final type in _appodealTypes) Appodeal.destroy(type.toAppodeal)],
    );
  }

  static Future<bool> _getConsent() async {
    // Không triển khai ad ở ngoài 2 platform này
    if (!isSupportedPlatform) return false;

    ConsentManager.setConsentInfoUpdateListener(
      (onConsentInfoUpdated, consent) => {_printDebug(consent)},
      (onFailedToUpdateConsentInfo, error) => {_printDebug(error)},
    );
    await ConsentManager.requestConsentInfoUpdate(_appodealKey);

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

  /// Kiểm tra phiên bản cũ trên máy, nếu khác với phiên bản app đang chạy
  /// thì sẽ không hiện Ads (tránh tình trạng bot của Google click nhầm).
  /// Sẽ đếm số lần mở app, nếu đủ 3 lần sẽ cho phép mở Ads lại.
  static Future<bool> _checkAllowedAds({
    required CheckAllowAdsOption checkAllowAdsOption,
  }) async {
    if (checkAllowAdsOption.prefVersion != checkAllowAdsOption.appVersion) {
      checkAllowAdsOption.writePref(checkAllowAdsOption.appVersion, 1);

      _printDebug(
        'Pref config không hiện Ads cho phiên bản này: $checkAllowAdsOption',
      );

      return false;
    }

    if (checkAllowAdsOption.count >= checkAllowAdsOption.allowAfterCount) {
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
      checkAllowAdsOption.count + 1,
    );

    _printDebug(
      'Pref config không hiện Ads cho phiên bản này: $checkAllowAdsOption',
    );

    return false;
  }

  static Widget get bannerWidget => const _BannerAd();
  static Widget get mrecWidget => const _MrecAd();

  // ignore: avoid_print
  static _printDebug(Object? object) => _debugLog ? print(object) : null;
}

class CheckAllowAdsOption {
  /// Version read from prefs
  final String prefVersion;

  /// Version read from current app
  final String appVersion;

  /// Count read from prefs
  final int count;

  /// Allow ads after this count
  final int allowAfterCount;

  /// Write to prefs callback
  final void Function(String, int) writePref;

  /// Config from cloud as a last checking before serving Ads. Default is false
  final bool cloudAllowed;

  CheckAllowAdsOption({
    required this.prefVersion,
    required this.appVersion,
    required this.count,
    required this.allowAfterCount,
    required this.writePref,
    this.cloudAllowed = false,
  });

  @override
  String toString() {
    return 'CheckAllowAdsOption(prefVersion: $prefVersion, appVersion: $appVersion, count: $count, allowAfterCount: $allowAfterCount, cloudAllowed: $cloudAllowed)';
  }
}

class _BannerAd extends StatefulWidget {
  const _BannerAd({Key? key}) : super(key: key);

  @override
  State<_BannerAd> createState() => _BannerAdState();
}

class _BannerAdState extends State<_BannerAd> {
  @override
  void dispose() {
    if (AppodealHelper.isAllowedAds) Appodeal.hide(Appodeal.BANNER);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppodealHelper.isAllowedAds
        ? const AppodealBanner(
            adSize: AppodealBannerSize.BANNER,
            placement: "default",
          )
        : const SizedBox.shrink();
  }
}

class _MrecAd extends StatefulWidget {
  const _MrecAd({Key? key}) : super(key: key);

  @override
  State<_MrecAd> createState() => _MrecAdState();
}

class _MrecAdState extends State<_MrecAd> {
  @override
  void dispose() {
    if (AppodealHelper.isAllowedAds) Appodeal.hide(Appodeal.MREC);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppodealHelper.isAllowedAds
        ? const AppodealBanner(
            adSize: AppodealBannerSize.MEDIUM_RECTANGLE,
            placement: "default",
          )
        : const SizedBox.shrink();
  }
}
