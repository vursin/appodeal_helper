# Appodeal Helper

Easier to use `stack_appodeal_flutter`

## Usage

``` dart
/// Config AppodealHelper
 AppodealHelper.config(
    isTesting: !kReleaseMode,
    keyAndroid: '',
    keyIOS: '',
    checkAllowAdsOption: CheckAllowAdsOption(
        prefVersion: prefs.getString('prefAdsVersion') ?? '1.0.0',
        appVersion: declare.appVersion,
        count: prefs.getInt('prefAdsCount') ?? 0,
        allowAfterCount: 3,
        writePref: (version, count) {
            prefs.setString('prefAdsVersion', version);
            prefs.setInt('prefAdsCount', count);
        },
        cloudAllowed: FirebaseConfig.get('cloudAllowed'),
    ),
    appodealTypes: [AppodealType.banner],
);

/// Get banner ad widget
final banner = AppodealHelper.bannerWidget;

/// Get MREC ad widget
final banner = AppodealHelper.mrecWidget;

/// Show special Ad 
AppodealHelper.showAd(AppodealType.reward);

/// Hide special Ad 
AppodealHelper.hideAd(AppodealType.reward);

```