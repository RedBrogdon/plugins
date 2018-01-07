// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// [MobileAd] status changes reported to [MobileAdListener]s.
///
/// Applications can wait until an ad is [MobileAdEvent.loaded] before showing
/// it, to ensure that the ad is displayed promptly.
enum MobileAdEvent {
  loaded,
  failedToLoad,
  clicked,
  impression,
  opened,
  leftApplication,
  closed,
}

/// The user's gender for the sake of ad targeting using [MobileAdTargetingInfo].
// Warning: the index values of the enums must match the values of the corresponding
// AdMob constants. For example MobileAdGender.female.index == kGADGenderFemale.
enum MobileAdGender {
  unknown,
  male,
  female,
}

/// Signature for a [MobileAd] status change callback.
typedef void MobileAdListener(MobileAdEvent event);

/// Targeting info per the native AdMob API.
///
/// This class's properties mirror the native AdRequest API. See for example:
/// [AdRequest.Builder for Android](https://firebase.google.com/docs/reference/android/com/google/android/gms/ads/AdRequest.Builder).
class MobileAdTargetingInfo {
  const MobileAdTargetingInfo({
    this.keywords,
    this.contentUrl,
    this.birthday,
    this.gender,
    this.designedForFamilies,
    this.childDirected,
    this.testDevices,
  });

  final List<String> keywords;
  final String contentUrl;
  final DateTime birthday;
  final MobileAdGender gender;
  final bool designedForFamilies;
  final bool childDirected;
  final List<String> testDevices;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'requestAgent': 'flutter-alpha',
    };

    if (keywords != null && keywords.isNotEmpty) {
      assert(keywords.every((String s) => s != null && s.isNotEmpty));
      json['keywords'] = keywords;
    }
    if (contentUrl != null && contentUrl.isNotEmpty)
      json['contentUrl'] = contentUrl;
    if (birthday != null) json['birthday'] = birthday.millisecondsSinceEpoch;
    if (gender != null) json['gender'] = gender.index;
    if (designedForFamilies != null)
      json['designedForFamilies'] = designedForFamilies;
    if (childDirected != null) json['childDirected'] = childDirected;
    if (testDevices != null && testDevices.isNotEmpty) {
      assert(testDevices.every((String s) => s != null && s.isNotEmpty));
      json['testDevices'] = testDevices;
    }

    return json;
  }
}

/// A mobile [BannerAd] or [InterstitialAd] for the [FirebaseAdMobPlugin].
///
/// A [MobileAd] must be loaded with [load] before it is shown with [show].
///
/// A valid [unitId] is required.
abstract class MobileAd {
  static final Map<int, MobileAd> _allAds = <int, MobileAd>{};

  /// Default constructor, used by subclasses.
  MobileAd(
      {@required this.unitId,
      MobileAdTargetingInfo targetingInfo,
      this.listener})
      : _targetingInfo = targetingInfo ?? const MobileAdTargetingInfo() {
    assert(unitId != null && unitId.isNotEmpty);
    assert(_allAds[id] == null);
    _allAds[id] = this;
  }

  /// Optional targeting info per the native AdMob API.
  MobileAdTargetingInfo get targetingInfo => _targetingInfo;
  final MobileAdTargetingInfo _targetingInfo;

  /// Identifies the source of ads for your application.
  ///
  /// For testing use a [sample ad unit](https://developers.google.com/admob/ios/test-ads#sample_ad_units).
  final String unitId;

  /// Called when the status of the ad changes.
  final MobileAdListener listener;

  /// An internal id that identifies this mobile ad to the native AdMob plugin.
  ///
  /// Plugin log messages will identify this property as the ad's `mobileAdId`.
  int get id => hashCode;

  MethodChannel get _channel => FirebaseAdMob.instance._channel;

  /// Start loading this ad.
  Future<bool> load();

  /// Show this ad.
  ///
  /// The ad must have been loaded with [load] first. If loading hasn't finished
  /// the ad will not actually appear until the ad has finished loading.
  ///
  /// The [listener] will be notified when the ad has finished loading or fails
  /// to do so. An ad that fails to load will not be shown.
  Future<bool> show() {
    return _channel.invokeMethod("showAd", <String, dynamic>{'id': id});
  }

  /// Free the plugin resources associated with this ad.
  ///
  /// Disposing a banner ad that's been shown removes it from the screen. Interstitial
  /// ads can't be programatically removed from view.
  Future<bool> dispose() {
    assert(_allAds[id] != null);
    _allAds[id] = null;
    return _channel.invokeMethod("disposeAd", <String, dynamic>{'id': id});
  }

  Future<bool> _doLoad(String loadMethod) {
    return _channel.invokeMethod(loadMethod, <String, dynamic>{
      'id': id,
      'unitId': unitId,
      'targetingInfo': targetingInfo?.toJson(),
    });
  }
}

/// A banner ad for the [FirebaseAdMobPlugin].
class BannerAd extends MobileAd {
  /// Create a BannerAd.
  ///
  /// A valid [unitId] is required.
  BannerAd({
    @required String unitId,
    MobileAdTargetingInfo targetingInfo,
    MobileAdListener listener,
  })
      : super(unitId: unitId, targetingInfo: targetingInfo, listener: listener);

  @override
  Future<bool> load() => _doLoad("loadBannerAd");
}

/// A full-screen interstitial ad for the [FirebaseAdMobPlugin].
class InterstitialAd extends MobileAd {
  /// Create an Interstitial.
  ///
  /// A valid [unitId] is required.
  InterstitialAd({
    String unitId,
    MobileAdTargetingInfo targetingInfo,
    MobileAdListener listener,
  })
      : super(unitId: unitId, targetingInfo: targetingInfo, listener: listener);

  @override
  Future<bool> load() => _doLoad("loadInterstitialAd");
}

/// [RewardedVideoAd] status changes reported to [RewardedVideoAdListener]s.
///
/// The [rewarded] event is particularly important, since it indicates that the
/// user has watched a video to completion and should be given an in-app reward.
enum RewardedVideoAdEvent {
  loaded,
  failedToLoad,
  opened,
  leftApplication,
  closed,
  rewarded,
  started,
}

/// Signature for a [RewardedVideoAd] status change callback. The optional
/// parameters are only used when the [RewardedVideoAdEvent.rewarded] event
/// is sent, and will be null for all others.
typedef void RewardedVideoAdListener(RewardedVideoAdEvent event,
    [String rewardType, int rewardAmount]);

/// The AdMob rewarded video ad. The AdMob API uses a singleton for its rewarded
/// video ads, and this class is designed to match.
///
/// Apps should assign a callback function to [RewardedVideoAd]'s listener
/// property in order to receive reward notifications from the AdMob SDK:
/// ```
/// RewardedVideoAd.instance.listener = (RewardedVideoAdEvent event,
///     [String rewardType, int rewardAmount]) {
///     print("You were rewarded with $rewardAmount $rewardType!");
///   }
/// };
/// ```
///
/// The function will be invoked when any of the events in
/// [RewardedVideoAdEvent] occur.
///
/// To load and show ads, call the load method:
/// ```
/// RewardedVideoAd.instance.load(myAdUnitString, myTargetingInfoObj);
/// ```
///
/// Later (any point after your listener callback receives the
/// RewardedVideoAdEvent.loaded event), call the show method:
/// ```
/// RewardedVideoAd.instance.show();
/// ```
///
/// Only one rewarded video ad can be loaded at a time. Because the creatives
/// are so large, it's a good idea to start loading an ad well in advance of
/// when it's likely to be needed.
class RewardedVideoAd {
  static final RewardedVideoAd _instance = new RewardedVideoAd.private();

  RewardedVideoAd.private();

  /// The one and only instance of this class.
  static RewardedVideoAd get instance => _instance;

  /// Callback invoked for events in the rewarded video ad lifecycle.
  RewardedVideoAdListener listener;

  MethodChannel get _channel => FirebaseAdMob.instance._channel;

  /// Shows a rewarded video ad if one has been loaded.
  Future<bool> show() {
    return _channel.invokeMethod("showRewardedVideoAd");
  }

  /// Loads a rewarded video ad using the provided ad unit ID.
  Future<bool> load(String adUnitId, MobileAdTargetingInfo targetingInfo) {
    assert(adUnitId != null && adUnitId.isNotEmpty);
    return _channel.invokeMethod("loadRewardedVideoAd", <String, dynamic>{
      'adUnitId': adUnitId,
      'targetingInfo': targetingInfo?.toJson(),
    });
  }
}

/// Support for Google AdMob mobile ads.
///
/// Before loading or showing an ad the plugin must be initialized with
/// an AdMob app id:
/// ```
/// FirebaseAdMob.instance.initialize(appId: myAppId);
/// ```
///
/// Apps can create, load, and show mobile ads. For example:
/// ```
/// BannerAd myBanner = new BannerAd(unitId: myBannerAdUnitId)
///   ..load()
///   ..show();
/// ```
///
/// See also:
///
///  * The example associated with this plugin.
///  * [BannerAd], a small rectangular ad displayed at the bottom of the screen.
///  * [InterstitialAd], a full screen ad that must be dismissed by the user.
///  * [RewardedVideoAd], a full screen video ad that provides in-app user
///    rewards.
class FirebaseAdMob {
  @visibleForTesting
  FirebaseAdMob.private(MethodChannel channel) : _channel = channel {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static final FirebaseAdMob _instance = new FirebaseAdMob.private(
    const MethodChannel('plugins.flutter.io/firebase_admob'),
  );

  /// The single shared instance of this plugin.
  static FirebaseAdMob get instance => _instance;

  final MethodChannel _channel;

  static const Map<String, MobileAdEvent> _methodToMobileAdEvent =
      const <String, MobileAdEvent>{
    'onAdLoaded': MobileAdEvent.loaded,
    'onAdFailedToLoad': MobileAdEvent.failedToLoad,
    'onAdClicked': MobileAdEvent.clicked,
    'onAdImpression': MobileAdEvent.impression,
    'onAdOpened': MobileAdEvent.opened,
    'onAdLeftApplication': MobileAdEvent.leftApplication,
    'onAdClosed': MobileAdEvent.closed,
  };

  static const Map<String, RewardedVideoAdEvent> _methodToRewardedVideoAdEvent =
      const <String, RewardedVideoAdEvent>{
    'onRewarded': RewardedVideoAdEvent.rewarded,
    'onRewardedVideoAdClosed': RewardedVideoAdEvent.closed,
    'onRewardedVideoAdFailedToLoad': RewardedVideoAdEvent.failedToLoad,
    'onRewardedVideoAdLeftApplication': RewardedVideoAdEvent.leftApplication,
    'onRewardedVideoAdLoaded': RewardedVideoAdEvent.loaded,
    'onRewardedVideoAdOpened': RewardedVideoAdEvent.opened,
    'onRewardedVideoStarted': RewardedVideoAdEvent.started,
  };

  /// Initialize this plugin for the AdMob app specified by `appId`.
  Future<bool> initialize(
      {@required String appId,
      String trackingId,
      bool analyticsEnabled: false}) {
    assert(appId != null && appId.isNotEmpty);
    assert(analyticsEnabled != null);
    return _channel.invokeMethod("initialize", <String, dynamic>{
      'appId': appId,
      'trackingId': trackingId,
      'analyticsEnabled': analyticsEnabled,
    });
  }

  Future<dynamic> _handleMethod(MethodCall call) {
    assert(call.arguments is Map);
    final Map<String, dynamic> argumentsMap = call.arguments;
    final RewardedVideoAdEvent rewardedEvent =
        _methodToRewardedVideoAdEvent[call.method];
    if (rewardedEvent != null) {
      if (RewardedVideoAd.instance.listener != null) {
        if (rewardedEvent == RewardedVideoAdEvent.rewarded) {
          RewardedVideoAd.instance.listener(rewardedEvent,
              argumentsMap['rewardType'], argumentsMap['rewardAmount']);
        } else {
          RewardedVideoAd.instance.listener(rewardedEvent);
        }
      }
    } else {
      final int id = argumentsMap['id'];
      if (id != null && MobileAd._allAds[id] != null) {
        final MobileAd ad = MobileAd._allAds[id];
        final MobileAdEvent mobileAdEvent = _methodToMobileAdEvent[call.method];
        if (mobileAdEvent != null && ad.listener != null) {
          ad.listener(mobileAdEvent);
        }
      }
    }

    return new Future<Null>(null);
  }
}
