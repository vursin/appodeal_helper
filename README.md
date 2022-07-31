# Appodeal Helper

Easier to use `stack_appodeal_flutter`

## Usage

``` dart
final appodealHelper = AppodealHelper.instance;

/// Config AppodealHelper. Must call this function before show any ads
appodealHelper.config(
    forceShowAd: !kReleaseMode,
    lastGuard: true,
    isTestAd: !kReleaseMode,
    keyAndroid: '',
    keyIOS: '',
    appodealTypes: [
        AppodealAdType.Banner,
        AppodealAdType.RewardedVideo,
    ],
    debugLog: !kReleaseMode,
);

/// Initial ads
///
/// You don't need to use this function, the plugin will automatically call this function when needed
await appodealHelper.initial();

/// Get banner ad widget
final banner = appodealHelper.bannerWidget;

/// Get MREC ad widget
final banner = appodealHelper.mrecWidget;

/// Show special Ad 
appodealHelper.showAd(AppodealAdType.RewardedVideo);

/// Hide special Ad 
appodealHelper.hideAd(AppodealAdType.RewardedVideo);

/// Dispose Ad
appodealHelper.dispose(AppodealAdType.RewardedVideo);

/// Set callbacks for rewarded video ads
appodeadHelper.setRewardedVideoCallbacks(
    onFinished: (double amount, String reward) {},
    onClosed: (bool isFinished) {}, 
    onClicked: () {},
    onFailed: () {},
);

/// Set callbacks for interstitial ads
appodealHelper.setInterstitialCallbacks(
    onClosed: () {},
    onClicked: () {},
    onFailed: () {},
);

/// Check if ads is initialized or not
final isInitialized = await appodealHelper.isInitialized(AppodealAdType.RewardedVideo);

/// Check if ads can show or not
final canShow = await appodealHelper.canShow(AppodealAdType.RewardedVideo);

/// Auto check and show rewarded video ads
final isShowed = await appodealHelper.showRewaredVideo();
```
