//
//  SEEventConstants.h
//  SolarEngineSDK
//
//  Created by PBX on 2022/1/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Built-in event types
typedef NS_ENUM(NSUInteger, SEPresetEventType) {
    SEPresetEventTypeAppInstall,
    SEPresetEventTypeAppStart,
    SEPresetEventTypeAppEnd,
    SEPresetEventTypeAppAll // This event represents all built-in events
};

typedef NS_OPTIONS(NSInteger, SEAutoTrackEventType) {
    SEAutoTrackEventTypeNone = 0,               // Disable auto tracking
    SEAutoTrackEventTypeAppClick = 1 << 0,      // Auto track control clicks
    SEAutoTrackEventTypeAppViewScreen = 1 << 1, // Auto track page views
};

typedef NS_OPTIONS(NSInteger, SEUserDeleteType) {
    SEUserDeleteTypeByAccountId, // Delete user by AccountId
    SEUserDeleteTypeByVisitorId, // Delete user by VisitorId
};

/*
This enum is deprecated since SDK v1.1.0 (inclusive). You need to pass the corresponding string values (i.e., the values below),

 The first part is the value to pass, the second part is the platform name
 csj：csj Ads Domestic
 pangle：pangle Ads International
 tencent：Tencent Youlianghui（Tencent Ad Network - TAN）
 baidu：Baidu Baiqingteng
 kuaishou：Kuaishou
 oppo：OPPO
 vivo：vivo
 mi：Xiaomi
 huawei：Huawei
 applovin：Applovin
 sigmob：Sigmob
 mintegral：Mintegral
 oneway：OneWay
 vungle：Vungle
 facebook：Facebook
 admob：AdMob
 unity：UnityAds
 is：IronSource
 adtiming：AdTiming
 klein：Youkeying
 fyber：Fyber
 chartboost：Chartboost
 adcolony：Adcolony

extern NSString * const SEMonetizationPlatformNameCSJ;
extern NSString * const SEMonetizationPlatformNameYLH;
extern NSString * const SEMonetizationPlatformNameBQT;
extern NSString * const SEMonetizationPlatformNameKuai;
extern NSString * const SEMonetizationPlatformNameSigmob;
extern NSString * const SEMonetizationPlatformNameMintegral;
extern NSString * const SEMonetizationPlatformNameOneWay;
extern NSString * const SEMonetizationPlatformNameVungle;
extern NSString * const SEMonetizationPlatformNameFacebook;
extern NSString * const SEMonetizationPlatformNameAdMob;
extern NSString * const SEMonetizationPlatformNameUnityAds;
extern NSString * const SEMonetizationPlatformNameIronSource;
extern NSString * const SEMonetizationPlatformNameAdTiming;
extern NSString * const SEMonetizationPlatformNameKlein;
*/

/*
 AdImpression Event properties
 */
extern NSString *const SEAdImpressionPropertyAdPlatform;
extern NSString *const SEAdImpressionPropertyAppID;
extern NSString *const SEAdImpressionPropertyPlacementID;
extern NSString *const SEAdImpressionPropertyAdType;
extern NSString *const SEAdImpressionPropertyEcpm;
extern NSString *const SEAdImpressionPropertyCurrency;
extern NSString *const SEAdImpressionPropertyMediationPlatform;
extern NSString *const SEAdImpressionPropertyRendered;

extern NSString *const SEAppAttrPropertyIsAttr;
extern NSString *const SEAppAttrPropertyAdNetwork;
extern NSString *const SEAppAttrPropertySubChannel;
extern NSString *const SEAppAttrPropertyAdAccountID;
extern NSString *const SEAppAttrPropertyAdAccountName;
extern NSString *const SEAppAttrPropertyAdCampaignID;
extern NSString *const SEAppAttrPropertyAdCampaignName;
extern NSString *const SEAppAttrPropertyAdOfferID;
extern NSString *const SEAppAttrPropertyAdOfferName;
extern NSString *const SEAppAttrPropertyAdCreativeID;
extern NSString *const SEAppAttrPropertyAdCreativeName;
extern NSString *const SEAppAttrPropertyAttributionPlatform;

/*
 IAP Event properties
 */
extern NSString *const SEIAPEventProductID;
extern NSString *const SEIAPEventProductName;
extern NSString *const SEIAPEventProductCount;
extern NSString *const SEIAPEventOrderID;
extern NSString *const SEIAPEventCurrency;
extern NSString *const SEIAPEventPaystatus;
extern NSString *const SEIAPEventPayType;
extern NSString *const SEIAPEventProductPayAmount;
extern NSString *const SEIAPEventFailReason;

/*
 Register Event properties
 */
extern NSString *const SERegisterPropertyType;
extern NSString *const SERegisterPropertyStatus;

/*
 Login Event properties
 */
extern NSString *const SELoginPropertyType;
extern NSString *const SELoginPropertyStatus;

/*
 Order Event properties
 */
extern NSString *const SEOrderPropertyID;
extern NSString *const SEOrderPropertyPayAmount;
extern NSString *const SEOrderPropertyCurrencyType;
extern NSString *const SEOrderPropertyPayType;
extern NSString *const SEOrderPropertyStatus;

/*
 PayType
 */
extern NSString *const SEIAPEventPayTypeAlipay;
extern NSString *const SEIAPEventPayTypeWeixin;
extern NSString *const SEIAPEventPayTypeApplePay;
extern NSString *const SEIAPEventPayTypePaypal;

/// IAP Status
typedef NS_ENUM(NSInteger, SolarEngineIAPStatus) {
    SolarEngineIAPNone = 0,
    SolarEngineIAPSuccess = 1,
    SolarEngineIAPFail = 2,
    SolarEngineIAPRestored = 3
};

/*

This enum is deprecated since SDK v1.1.0 (inclusive). Users must pass integer values to the interface, and the integer values correspond to the following:
v1.3.0.4 restored enum
 */
/// Ad Type
typedef NS_ENUM(NSInteger, SolarEngineAdType) {
    SolarEngineAdTypeOther = 0,             // Other
    SolarEngineAdTypeRewardVideo = 1,       // Reward Video
    SolarEngineAdTypeSplash = 2,            // Splash
    SolarEngineAdTypeInterstitial = 3,      // Interstitial
    SolarEngineAdTypeInterstitialVideo = 4, // Full Screen Video
    SolarEngineAdTypeBanner = 5,            // Banner
    SolarEngineAdTypeNative = 6,            // Native
    SolarEngineAdTypeNativeVideo = 7,       // Native Video
    SolarEngineAdTypeBigBanner = 8,         // Big Banner
    SolarEngineAdTypeInStream = 9,          // In-Stream Video
    SolarEngineAdTypeMediumBanner = 10,     // Medium Banner
};

@interface SEEventBaseAttribute : NSObject

/// Unique identifier for the first event
@property(nonatomic, copy) NSString *firstCheckId;

@end

@interface SECustomEventAttribute : SEEventBaseAttribute

/// Custom event name
@property(nonatomic, copy) NSString *eventName;

/// Custom event alias
@property(nonatomic, copy, nullable) NSString *customEventAlias;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

/// Preset properties
@property(nonatomic, copy) NSDictionary *presetProperties;

@end

@interface SEIAPEventAttribute : SEEventBaseAttribute

/// Product ID for purchase
@property(nonatomic, copy, nonnull) NSString *productID;

/// Product name
@property(nonatomic, copy, nonnull) NSString *productName;

/// Product quantity
@property(nonatomic, assign) NSInteger productCount;

/// Order ID
@property(nonatomic, copy, nonnull) NSString *orderId;

/// Payment amount
@property(nonatomic, assign) double payAmount;

/// Currency type. Follows ISO 4217 international standard, such as CNY, USD
@property(nonatomic, copy, nonnull) NSString *currencyType;

/*
 Payment type
 Your should use below value, or customize your own value if not contains the paytype you using

 extern NSString * const SEIAPEventPayTypeAlipay;
 extern NSString * const SEIAPEventPayTypeWeixin;
 extern NSString * const SEIAPEventPayTypeApplePay;
 extern NSString * const SEIAPEventPayTypePaypal;
 */
@property(nonatomic, copy, nonnull) NSString *payType;

/// Payment status
@property(nonatomic, assign) SolarEngineIAPStatus payStatus;

/// Reason for payment failure
@property(nonatomic, copy) NSString *failReason;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

@interface SEAdImpressionEventAttribute : SEEventBaseAttribute

/// Ad type (such as splash, reward video, etc.)
/* Users must pass integer values to the interface, and the integer values correspond to the following:
1: Reward Video
2: Splash
3: Interstitial
4: Full Screen Video
5: Banner
6: Native
7: Native Video
8: Big Banner
9: In-Stream Video
10: Medium Banner
0: Other

If you cannot find the relevant value, please check the integration documentation or contact our technical support.
 */
@property(nonatomic, assign) SolarEngineAdType adType;

/*
 adNetworkPlatform
 Monetization platform

 Monetization platform, the first part is the value to pass, the second part is the platform name
 csj：csj Ads Domestic
 pangle：pangle Ads International ccc
 tencent：Tencent Youlianghui（Tencent Ad Network - TAN）
 baidu：Baidu Baiqingteng
 kuaishou：Kuaishou
 oppo：OPPO
 vivo：vivo
 mi：Xiaomi
 huawei：Huawei
 applovin：Applovin
 sigmob：Sigmob
 mintegral：Mintegral
 oneway：OneWay
 vungle：Vungle
 facebook：Facebook
 admob：AdMob
 unity：UnityAds
 is：IronSource
 adtiming：AdTiming
 klein：Youkeying
 fyber：Fyber
 chartboost：Chartboost
 adcolony：Adcolony

 If you cannot find the relevant value, please check the integration documentation or contact our technical support.
 */
@property(nonatomic, copy, nonnull) NSString *adNetworkPlatform;

/// Ad Network Platform App ID
@property(nonatomic, copy) NSString *adNetworkAppID;

/// Ad Network Platform Placement ID
@property(nonatomic, copy, nonnull) NSString *adNetworkPlacementID;

/// currency
@property(nonatomic, copy, nonnull) NSString *currency;

/// Ad revenue per thousand impressions
@property(nonatomic, assign) double ecpm;

/// mediationPlatform
@property(nonatomic, copy, nonnull) NSString *mediationPlatform;

/// Whether to render (default value is YES)
@property(nonatomic, assign) BOOL rendered;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

/// User registration event properties
@interface SERegisterEventAttribute : SEEventBaseAttribute

/// Registration type, no more than 32 characters
@property(nonatomic, copy, nonnull) NSString *registerType;

/// Registration status
@property(nonatomic, copy) NSString *registerStatus;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

/// Login event properties
@interface SELoginEventAttribute : SEEventBaseAttribute

/// Login type, no more than 32 characters
@property(nonatomic, copy, nonnull) NSString *loginType;

/// Login status
@property(nonatomic, copy) NSString *loginStatus;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

/// Order event properties
@interface SEOrderEventAttribute : SEEventBaseAttribute

/// Order ID, no more than 128 characters
@property(nonatomic, copy, nonnull) NSString *orderID;

/// Order amount, unit: yuan
@property(nonatomic, assign) double payAmount;

/// Currency type. Follows ISO 4217 international standard, such as CNY, USD
@property(nonatomic, copy, nonnull) NSString *currencyType;

/// Payment type
@property(nonatomic, copy) NSString *payType;

/// Order status
@property(nonatomic, copy) NSString *status;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

@interface SEAdClickEventAttribute : SEEventBaseAttribute

/// Ad type (such as splash, reward video, etc.)
/* Users must pass integer values to the interface, and the integer values correspond to the following:
1: Reward Video
2: Splash
3: Interstitial
4: Full Screen Video
5: Banner
6: Native
7: Native Video
8: Big Banner
9: In-Stream Video
10: Medium Banner
0: Other

If you cannot find the relevant value, please check the integration documentation or contact our technical support.
 */
@property(nonatomic, assign) SolarEngineAdType adType;

/*
 adNetworkPlatform
 Monetization platform

 Monetization platform, the first part is the value to pass, the second part is the platform name
 csj：csj Ads Domestic
 pangle：pangle Ads International
 tencent：Tencent Youlianghui（Tencent Ad Network - TAN）
 baidu：Baidu Baiqingteng
 kuaishou：Kuaishou
 oppo：OPPO
 vivo：vivo
 mi：Xiaomi
 huawei：Huawei
 applovin：Applovin
 sigmob：Sigmob
 mintegral：Mintegral
 oneway：OneWay
 vungle：Vungle
 facebook：Facebook
 admob：AdMob
 unity：UnityAds
 is：IronSource
 adtiming：AdTiming
 klein：Youkeying
 fyber：Fyber
 chartboost：Chartboost
 adcolony：Adcolony

 If you cannot find the relevant value, please check the integration documentation or contact our technical support.
 */
@property(nonatomic, copy, nonnull) NSString *adNetworkPlatform;

/// Ad Network Platform Placement ID
@property(nonatomic, copy, nonnull) NSString *adNetworkPlacementID;

/// mediationPlatform aggregation platform identifier, if no aggregation platform identifier, please set to "custom"
@property(nonatomic, copy, nonnull) NSString *mediationPlatform;

/// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

@interface SEAppAttrEventAttribute : SEEventBaseAttribute

// Ad placement channel ID, needs to match the publishing platform
@property(nonatomic, copy) NSString *adNetwork;

// Ad placement sub-channel
@property(nonatomic, copy) NSString *subChannel;

// Ad placement account ID
@property(nonatomic, copy) NSString *adAccountID;

// Ad placement account name
@property(nonatomic, copy) NSString *adAccountName;

// Ad campaign ID
@property(nonatomic, copy) NSString *adCampaignID;

// Ad campaign name
@property(nonatomic, copy) NSString *adCampaignName;

// Ad unit ID
@property(nonatomic, copy) NSString *adOfferID;

// Ad unit name
@property(nonatomic, copy) NSString *adOfferName;

// Ad creative ID
@property(nonatomic, copy) NSString *adCreativeID;

// Ad creative name
@property(nonatomic, copy) NSString *adCreativeName;

// Attribution platform
@property(nonatomic, copy) NSString *attributionPlatform;

// Custom properties
@property(nonatomic, copy) NSDictionary *customProperties;

@end

@interface SEEventConstants : NSObject

@end

@interface SEDeeplinkInfo : NSObject

// Jump parameters
@property(nonatomic, copy) NSString *sedpLink;
// 7-digit short link
@property(nonatomic, copy) NSString *turlId;
// Link type, link or urlscheme
@property(nonatomic, copy) NSString *from;
// Base URL string to open the app
@property(nonatomic, copy) NSString *baseUrl;
// URL string to open the app
@property(nonatomic, copy) NSString *url;
// Custom parameters
@property(nonatomic, copy) NSDictionary *customParams;

@end

@interface SEDeferredDeeplinkInfo : NSObject

// Jump parameters
@property(nonatomic, copy) NSString *sedpLink;
// 7-digit short link
@property(nonatomic, copy) NSString *turlId;
// URL scheme filled by user when creating deeplink
@property(nonatomic, copy) NSString *sedpUrlscheme;

@end

@interface SEDelayDeeplinkInfo : SEDeferredDeeplinkInfo

// Jump parameters
@property(nonatomic, copy) NSString *sedpLink;
// 7-digit short link
@property(nonatomic, copy) NSString *turlId;
// URL scheme filled by user when creating deeplink
@property(nonatomic, copy) NSString *sedpUrlscheme;

+ (SEDelayDeeplinkInfo *)delayWithDeferred:(SEDeferredDeeplinkInfo *)info;

@end

NS_ASSUME_NONNULL_END
