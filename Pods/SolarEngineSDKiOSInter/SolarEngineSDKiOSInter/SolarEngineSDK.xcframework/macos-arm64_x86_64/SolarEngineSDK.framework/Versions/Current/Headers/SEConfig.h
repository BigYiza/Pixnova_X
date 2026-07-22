//
//  SEConfig.h
//  SolarEngineSDK
//
//  Created by Mobvista on 2023/9/14.
//

#import <Foundation/Foundation.h>
#import <SolarEngineSDK/SEEventConstants.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SERCMergeType) {
    SERCMergeTypeDefault = 0, // Default strategy: merge cached config + default config with server config
    SERCMergeTypeUser = 1,    // On app version update: merge default config with server config (discard cached config)
};

@interface SERemoteConfig : NSObject

/**
  Enable switch for Remote Config SDK; disabled by default
*/
@property(nonatomic, assign) BOOL enable;

/**
 Custom ID properties used to match the custom IDs defined in the admin console rules
*/
@property(nonatomic, strong) NSDictionary *customIDProperties;

/**
 * Custom ID event properties
 */
@property(nonatomic, strong) NSDictionary *customIDEventProperties;

/**
 * Custom ID user properties
 */
@property(nonatomic, strong) NSDictionary *customIDUserProperties;

/**
 SDK configuration merge strategy. By default, server config is merged with local cached config.
 For SERCMergeTypeUser, cached config will be cleared on app version update.
*/
@property(nonatomic, assign) SERCMergeType mergeType;

/// Whether to enable local debug logs (disabled by default if not set)
@property(nonatomic, assign) BOOL logEnabled;

@end

@interface SECustomDomain : NSObject

/// Whether to enable on‑premise (private) deployment (disabled by default if not set)
@property(nonatomic, assign) BOOL enable;

/// HTTP domain for private deployment: event reporting, debug event reporting, attribution, deferred deeplink
@property(nonatomic, strong) NSString *receiverDomain;
/// HTTP domain for private deployment: Remote Config
@property(nonatomic, strong) NSString *ruleDomain;
/// TCP host for private deployment: attribution, debug event reporting
@property(nonatomic, strong) NSString *receiverTcpHost;
/// TCP host for private deployment: Remote Config
@property(nonatomic, strong) NSString *ruleTcpHost;
/// TCP host for private deployment: event reporting
@property(nonatomic, strong) NSString *gatewayTcpHost;

@end

@interface SEConfig : NSObject

/// Whether to enable local debug logs (disabled by default if not set)
@property(nonatomic, assign) BOOL logEnabled;

/// Whether to enable Debug mode. When enabled, data can be viewed in real time in the admin console (disabled by default).
/// Do NOT ship Debug mode to production.
@property(nonatomic, assign) BOOL isDebugModel;

/// Whether to support IPv6 attribution; supported by default. (Mainland China only)
@property(nonatomic, assign) BOOL enableIPV6;

/// Whether to collect and report language. Enabled by default.
@property(nonatomic, assign) BOOL enableLanguage;

/// Whether to collect and report time zone. Enabled by default.
@property(nonatomic, assign) BOOL enableTimeZone;

/// Whether to collect and report screen width/height. Enabled by default.
@property(nonatomic, assign) BOOL enableScreenWH;

/// Whether to collect and report network type. Enabled by default.
@property(nonatomic, assign) BOOL enableNetworkType;

/// Whether to collect and report User-Agent. Enabled by default.
@property(nonatomic, assign) BOOL enableUA;

/// Whether to collect and report locale. Enabled by default.
@property(nonatomic, assign) BOOL enableLocale;

/// Whether to enable attribution, deeplink parsing and deferred deeplink. Enabled by default.
@property(nonatomic, assign) BOOL enableAttribution;

/// Whether to enable analytics features such as Remote Config. Enabled by default.
@property(nonatomic, assign) BOOL enableAnalytics;

#if TARGET_OS_IOS

/// Whether the app is in a GDPR region; by default, no GDPR region restriction is applied
@property(nonatomic, assign) BOOL isGDPRArea;

// Whether to enable COPPA compliance. When enabled, IDFV and IDFA will not be collected. Disabled by default.
@property(nonatomic, assign) BOOL setCoppaEnabled;

// Whether to enable Kids App compliance. When enabled, IDFV and IDFA will not be collected. Disabled by default.
@property(nonatomic, assign) BOOL setKidsAppEnabled;

/// Auto-tracking event collection type. By default, the SDK does not enable auto-tracking.
@property(nonatomic, assign) SEAutoTrackEventType autoTrackEventType;

/// Whether to report data on 2G networks. By default, only 3G/4G/5G/Wi‑Fi report; 2G does not report.
@property(nonatomic, assign) BOOL enable2GReporting;

/// Seconds to wait for ATT authorization before the first event report
@property(nonatomic, assign) int attAuthorizationWaitingInterval;

/// Whether to enable deferred Deeplink; default is NO (disabled)
@property(nonatomic, assign) BOOL enableDeferredDeeplink;

/// Whether to enable deferred Deeplink; default is NO (disabled)
@property(nonatomic, assign) BOOL enableDelayDeeplink DEPRECATED_MSG_ATTRIBUTE("Use enableDeferredDeeplink");

#endif

/// Remote Config settings (not required if Remote Config is not used)
@property(nonatomic, strong) SERemoteConfig *remoteConfig;

/// Private deployment (on‑prem) configuration; not required for SaaS users
@property(nonatomic, strong) SECustomDomain *customDomain;

@end

NS_ASSUME_NONNULL_END
