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
  AppodealHelper._();

  /// Return true if ads are allowed and false otherwise.
  static bool isAllowedAds = false;

  /// Return true if current platform is Android or iOS and false otherwise.
  static final isSupportedPlatform =
      UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  /// Internal variables
  static String _appodealKey = '';
  static List<AppodealAdType> _appodealTypes = [];
  static bool _forceShowAd = true;
  static bool _isTestAd = true;
  static bool _debugLog = false;

  static bool _lastGuard = false;

  static int _allowAfterCount = 3;

  static bool _isConfiged = false;
  static bool _isInitialed = false;

  static const String _prefix = 'AppodealHelper';

  static void config({
    required bool forceShowAd,
    required bool isTestAd,
    required String keyAndroid,
    required String keyIOS,

    /// Last value to check for allowing show ad or not. It can be a config on
    /// cloud (if this value is false then all other progress will be false).
    bool lastGuard = true,
    int allowAfterCount = 3,
    required List<AppodealAdType> appodealTypes,
    bool debugLog = false,
  }) {
    if (_isConfiged) return;
    _isConfiged = true;

    _appodealKey = UniversalPlatform.isAndroid ? keyAndroid : keyIOS;
    _appodealTypes = appodealTypes;
    _forceShowAd = forceShowAd;
    _isTestAd = isTestAd;
    _debugLog = debugLog;
    _lastGuard = lastGuard;
    _allowAfterCount = allowAfterCount;

    // Nếu key không được đặt thì không hiện Ads cho platform này
    if (_appodealKey == '' || !isSupportedPlatform) isAllowedAds = false;

    if (_forceShowAd) isAllowedAds = true;
  }

  /// Initial ConsentManager and Appodeal plugin.
  /// The plugin will automatically call this function when needed.
  static Future<bool> initial() async {
    assert(_isConfiged == true,
        'Must call `AppodealHelper.config` before showing Ad');

    // Không triển khai ad ở ngoài 2 platform này
    if (_isInitialed) return true;
    _isInitialed = true;

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
      adTypes: [for (final type in _appodealTypes) type],
    );

    _printDebug('Appodeal has been initialized');
    return true;
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
    if (!await initial()) return;
    return Appodeal.hide(type);
  }

  /// Show specific ad
  ///
  /// Returns true if ad can be shown with this placement, otherwise false.
  static Future<bool> showAd(AppodealAdType type) async {
    if (!await initial()) return false;
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

class _BannerAd extends StatelessWidget {
  const _BannerAd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppodealHelper.initial(),
      builder: (_, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }

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
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }

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
/// Sẽ đếm số lần mở app, nếu đủ 3 lần sẽ cho phép mở Ads lại.
Future<bool> _checkAllowedAds() async {
  final box = await getHiveBox();
  final packageInfo = await PackageInfo.fromPlatform();

  final checkAllowAdsOption = CheckAllowAdsOption(
    prefVersion: (box.get('prefVersion') as String?) ?? '1.0.0',
    appVersion: packageInfo.version,
    currentCount: (box.get('currentCount') as int?) ?? 1,
    allowAfterCount: AppodealHelper._allowAfterCount,
    writePref: (version, count) {
      box.put('prefVersion', version);
      box.put('currentCount', count);
    },
    lastGuard: AppodealHelper._lastGuard,
  );

  if (checkAllowAdsOption.prefVersion != checkAllowAdsOption.appVersion) {
    checkAllowAdsOption.writePref(checkAllowAdsOption.appVersion, 1);

    _printDebug(
      'Pref config do not allow showing Ad on this version: $checkAllowAdsOption',
    );

    return false;
  }

  if (checkAllowAdsOption.currentCount >= checkAllowAdsOption.allowAfterCount) {
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
    checkAllowAdsOption.currentCount + 1,
  );

  _printDebug(
    'Pref config do not allow showing Ad on this version: $checkAllowAdsOption',
  );

  return false;
}

_printDebug(Object? object) =>
    // ignore: avoid_print
    AppodealHelper._debugLog ? print('[Appodeal Helper]: $object') : null;
