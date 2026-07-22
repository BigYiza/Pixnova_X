//
//  SolarEngineSDK.h
//  SolarEngineSDK
//  hash:33972dd
//  Created by MVP on 2022/1/20.
//

#import <Foundation/Foundation.h>
#import <SolarEngineSDK/SEEventConstants.h>
#import <Webkit/WebKit.h>
#import <SolarEngineSDK/SEConfig.h>

#define SESDKVersion @"1.3.2"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SEAttributionCallback)(int code, NSDictionary *_Nullable attributionData);
typedef void (^SECompleteCallback)(int code);
typedef void (^SEDeeplinkCallback)(int code, SEDeeplinkInfo *_Nullable deeplinkInfo);
typedef void (^SEDeferredDeeplinkCallback)(SEDeferredDeeplinkInfo *_Nullable deeplinkInfo);

typedef void (^SEFailCallback)(NSError *_Nullable error);

#if TARGET_OS_IOS
@class UIView, UIViewController;
#endif

@interface SolarEngineSDK : NSObject

/// SolarEngineSDK singleton instance
+ (nonnull instancetype)sharedInstance;

/// Pre-initialize the SDK
/// @param appKey Application appKey. Please contact the business team to obtain it. Must not be empty.
- (void)preInitWithAppKey:(nonnull NSString *)appKey;

/// Initialize the SDK
/// @param appKey Application appKey. Please contact the business team to obtain it. Must not be empty.
/// @param config Configuration information
- (void)startWithAppKey:(nonnull NSString *)appKey config:(SEConfig *)config;

/// Set preset event properties
/// @param eventType Event type
/// @param properties Event properties
- (void)setPresetEvent:(SEPresetEventType)eventType withProperties:(NSDictionary *)properties;

/*
 Code description:
 0: Initialization succeeded

 Non-zero indicates initialization failed, as follows:
 101: Initialization failed because pre-initialization was not called
 102: Initialization failed because appKey is invalid
 */
/// Set the SDK initialization callback (success or failure)
- (void)setInitCompletedCallback:(SECompleteCallback)callback;

/// Get SDK preset properties
- (NSDictionary *)getPresetProperties;

#pragma event

/// Track a custom event
/// @param eventName Event name. Supports letters (case-sensitive), Chinese characters, digits, and underscores; cannot start with an underscore; length must not exceed 40.
/// @param customProperties Event properties. Keys must not start with an underscore (_).
- (void)track:(NSString *)eventName withProperties:(NSDictionary *_Nullable)customProperties;

/// Track a custom event
/// @param eventName Event name. Supports letters (case-sensitive), Chinese characters, digits, and underscores; cannot start with an underscore; length must not exceed 40.
/// @param customProperties Custom event properties. Keys must not start with an underscore (_).
/// @param preProperties Preset event properties. Some specific preset properties may start with an underscore (_).
- (void)track:(NSString *)eventName withCustomProperties:(NSDictionary *_Nullable)customProperties withPresetProperties:(NSDictionary *_Nullable)preProperties;

/// Track a custom event
/// @param attribute SECustomEventAttribute instance
- (void)trackCustomEvent:(SECustomEventAttribute *)attribute;

/// Track an in-app purchase (IAP) event
/// @param attribute SEIAPEventAttribute instance
- (void)trackIAPWithAttributes:(SEIAPEventAttribute *)attribute;

/// Track a monetization ad impression event
/// @param attribute SEAdImpressionEventAttribute instance
- (void)trackAdImpressionWithAttributes:(SEAdImpressionEventAttribute *)attribute;

/// Track a monetization ad click event
/// @param attribute SEAdClickEventAttribute instance
- (void)trackAdClickWithAttributes:(SEAdClickEventAttribute *)attribute;

/// Track an attribution event
/// @param attribute SEAppAttrEventAttribute instance
- (void)trackAppAttrWithAttributes:(SEAppAttrEventAttribute *)attribute;

/// Track a registration event
/// @param attribute SERegisterEventAttribute instance
- (void)trackRegisterWithAttributes:(SERegisterEventAttribute *)attribute;

/// Track a login event
/// @param attribute SELoginEventAttribute instance
- (void)trackLoginWithAttributes:(SELoginEventAttribute *)attribute;

/// Track an order event
/// @param attribute SEOrderEventAttribute instance
- (void)trackOrderWithAttributes:(SEOrderEventAttribute *)attribute;

/// Track a first-time event
/// @param attribute Pass a subclass of SEEventBaseAttribute, i.e., a specific EventAttribute
- (void)trackFirstEvent:(SEEventBaseAttribute *)attribute;

/// Start a duration event (used together with -eventFinish:properties:)
/// @param eventName Event name. Supports letters (case-sensitive), Chinese characters, digits, and underscores; cannot start with an underscore; length must not exceed 40.
- (void)eventStart:(NSString *)eventName;

/// End and track a duration event (used together with -eventStart:)
/// @param eventName Event name. Supports letters (case-sensitive), Chinese characters, digits, and underscores; cannot start with an underscore; length must not exceed 40.
/// @param properties Custom properties
- (void)eventFinish:(NSString *)eventName properties:(NSDictionary *_Nullable)properties;

/// End and track a duration event (used together with -eventStart:)
/// @param eventName Event name. Supports letters (case-sensitive), Chinese characters, digits, and underscores; cannot start with an underscore; length must not exceed 40.
/// @param properties Custom properties
/// @param customEventAlias Custom event alias.
- (void)eventFinish:(NSString *)eventName properties:(NSDictionary *_Nullable)properties customEventAlias:(NSString *_Nullable)customEventAlias;

/// Flush events immediately
- (void)reportEventImmediately;

/// Get SDK version
- (NSString *)getSDKVersion;

#if TARGET_OS_IOS

/// Whether to enable GDPR region restriction (disabled by default if not set)
/// @param isGDPRArea YES to enable, NO to disable (when enabled, the SDK will not obtain IDFA/IDFV)
- (void)setGDPRArea:(BOOL)isGDPRArea;

/// Set preset event properties
/// @param webView WKWebView from the system callback
/// @param request navigationAction.request from the system callback
- (BOOL)showUpWebView:(WKWebView *)webView withRequest:(NSURLRequest *)request API_UNAVAILABLE(macos);

/// Track deeplink-open success. Note: If appDeeplinkOpenURL is called, do not call this API to avoid duplicate events.
/// @param customProperties Event properties. Keys must not start with an underscore (_).
- (void)trackAppReEngagement:(NSDictionary *_Nullable)customProperties;

/*
 Code description:
 0: Successfully obtained attribution result; see attributionData

 Non-zero indicates failure to obtain attribution result, as follows:
 100: _appKey is invalid
 101: _distinct_id is invalid
 102: _distinct_id_type is invalid
 1001: Network error; SDK failed to connect to the server
 1002: Exceeded 10 requests in the current launch without obtaining attribution result
 1003: Less than 5 minutes since last polling for attribution; please try again after 5 minutes
 1004: The user has not obtained attribution for over 15 days; no further requests will be made during this installation
 */
/// Set the callback to obtain attribution results. Set this before initializing the SDK.
/// Invoked when an attribution result is available or when retrieval fails. error.code as described above.
- (void)setAttributionCallback:(SEAttributionCallback)callback API_UNAVAILABLE(macos);

/// Get attribution data
/// Returns nil if there is no attribution result
- (NSDictionary *_Nullable)getAttributionData API_UNAVAILABLE(macos);

/// SolarEngine wrapper for the system API requestTrackingAuthorizationWithCompletionHandler
/// @param completion Callback user authorization status: 0: Not Determined; 1: Restricted; 2: Denied; 3: Authorized; 999: system error
- (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(NSUInteger status))completion API_UNAVAILABLE(macos);

/// Track app view screen event
/// @param viewController View controller
/// @param properties Custom properties
- (void)trackAppViewScreen:(UIViewController *)viewController withProperties:(NSDictionary *_Nullable)properties API_UNAVAILABLE(macos);

/// Track element click event
/// @param view UI element (view/control)
/// @param properties Custom properties
- (void)trackAppClick:(UIView *)view withProperties:(NSDictionary *_Nullable)properties API_UNAVAILABLE(macos);

/// Set auto-tracking type. Auto-tracking is disabled by default.
/// @param eventType Enum values:
/// SEAutoTrackEventTypeNone: SDK does not auto-collect events
/// SEAutoTrackEventTypeAppClick: SDK auto-tracks control clicks
/// SEAutoTrackEventTypeAppViewScreen: SDK auto-tracks page views
/// SEAutoTrackEventTypeAppClick | SEAutoTrackEventTypeAppViewScreen: SDK tracks both control clicks and page views
- (void)setAutoTrackEventType:(SEAutoTrackEventType)eventType API_UNAVAILABLE(macos);

/// Ignore auto-tracking for certain control classes
/// @param classList Classes to ignore, e.g., @[[UIButton class]]
- (void)ignoreAutoTrackAppClickClassList:(NSArray<Class> *)classList API_UNAVAILABLE(macos);

#pragma Deeplink
// When the app is opened via Deeplink (Universal Link or URL Scheme), pass the URL to the SDK
// @param url The URL from the system callback
- (void)appDeeplinkOpenURL:(NSURL *)url API_UNAVAILABLE(macos);

// Set the callback for parameters when the app is opened via Deeplink
// Callback codes: 0 success; 1 URL invalid or empty; 2 URL parameter parse error
- (void)setDeepLinkCallback:(SEDeeplinkCallback)callback API_UNAVAILABLE(macos);

#pragma Deeplink
// Set deferred deeplink callback. Call this before SDK initialization. Only when SEConfig.enableDeferredDeeplink is set to YES will the SDK request deferred deeplink and trigger this callback.
// Fail codes:
// 1101: SDK internal error; 1102: Failed to connect to server; 1103: Connection to server timed out; 1104: Server error; 1105: Server returned SDK-side data; 1106: Deeplink match failed, server returned empty
- (void)setDeferredDeepLinkCallbackWithSuccess:(SEDeferredDeeplinkCallback)success fail:(SEFailCallback)fail API_UNAVAILABLE(macos);

#endif

#pragma Visitor ID

/// Set visitor ID
/// @param visitorId Visitor ID
- (void)setVisitorID:(nonnull NSString *)visitorId;

/// Get visitor ID
- (nullable NSString *)visitorID;

#pragma Account ID

/// Log in and set account ID
/// @param accountId Account ID
- (void)loginWithAccountID:(nonnull NSString *)accountId;

/// Account ID
- (NSString *_Nullable)accountID;

/// Log out and clear account ID
- (void)logout;

/// Get distinctId
- (NSString *)getDistinctId;

#pragma Set super event properties

/// Set super properties
/// @param properties Custom properties
- (void)setSuperProperties:(NSDictionary *)properties;

/// Unset a specific super property
/// @param key Super property key
- (void)unsetSuperProperty:(NSString *)key;

/// Clear all super properties
- (void)clearSuperProperties;

#pragma Set user properties

/// Initialize user properties. If a property already exists, its value will not be modified; otherwise it will be created.
/// @param properties Custom properties
- (void)userInit:(NSDictionary *)properties;

/// Update user properties. Existing property values will be overwritten; if not present, they will be created.
/// @param properties Custom properties
- (void)userUpdate:(NSDictionary *)properties;

/// Increment user properties
/// @param properties Custom properties (only numeric keys will be incremented)
- (void)userAdd:(NSDictionary *)properties;

/// Reset user properties. Clear the specified properties.
/// @param keys Array of property keys
- (void)userUnset:(NSArray<NSString *> *)keys;

/// Append user properties
/// @param properties Custom properties
- (void)userAppend:(NSDictionary *)properties;

/// Delete user
/// @param deleteType Type of deletion
/// SEUserDeleteTypeByAccountId: Delete user by AccountId
/// SEUserDeleteTypeByVisitorId: Delete user by VisitorId
- (void)userDelete:(SEUserDeleteType)deleteType;

#if TARGET_OS_IOS

#pragma SKAN
/// SKAN API wrapper
/// Reference: https://developer.apple.com/documentation/storekit/skadnetworkcoarseconversionvalue?language=objc
/// Wrapper for SKAdNetwork's updatePostbackConversionValue:completionHandler:
/*
 * @param conversionValue Conversion value, must be between 0 - 63
 * @param completion Completion handler; pass nil if not needed
 */
- (void)updatePostbackConversionValue:(NSInteger)conversionValue
                    completionHandler:(void (^)(NSError *error))completion API_UNAVAILABLE(macos);

/// Wrapper for SKAdNetwork's updatePostbackConversionValue:coarseValue:completionHandler:
/*
 * @param fineValue Conversion value, must be between 0 - 63
 * @param coarseValue SKAdNetworkCoarseConversionValue value, a coarse-grained conversion value. If the app's install volume does not meet the privacy threshold, coarse conversion values will be used.
 * @param completion Completion handler; pass nil if not needed
 */
- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                    completionHandler:(void (^)(NSError *error))completion API_UNAVAILABLE(macos);

/// Wrapper for SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler:
/*
 * @param fineValue Conversion value, must be between 0 - 63
 * @param coarseValue SKAdNetworkCoarseConversionValue value, a coarse-grained conversion value. If the app's install volume does not meet the privacy threshold, coarse conversion values will be used.
 * @param lockWindow Whether to send the callback before the conversion window ends. YES tells the system to send the callback without waiting for the conversion window to end. Default is NO.
 * @param completion Completion handler; pass nil if not needed
 */
- (void)updatePostbackConversionValue:(NSInteger)fineValue
                          coarseValue:(NSString *)coarseValue
                           lockWindow:(BOOL)lockWindow
                    completionHandler:(void (^)(NSError *error))completion API_UNAVAILABLE(macos);

#endif

typedef void (^SEDelayDeeplinkCallback)(SEDelayDeeplinkInfo *_Nullable deeplinkInfo) DEPRECATED_MSG_ATTRIBUTE("Use SEDeferredDeeplinkCallback");
- (void)startWithAppKey:(nonnull NSString *)appKey userId:(nonnull NSString *)userId config:(SEConfig *)config DEPRECATED_MSG_ATTRIBUTE("Use startWithAppKey:config:");
- (void)setDelayDeeplinkDeepLinkCallbackWithSuccess:(SEDelayDeeplinkCallback)success fail:(SEFailCallback)fail API_UNAVAILABLE(macos)DEPRECATED_MSG_ATTRIBUTE("Use setDeferredDeepLinkCallbackWithSuccess:fail:");

@end

#if TARGET_OS_IOS
@interface UIView (SolarEngine)

/// Custom properties that will be reported along with auto-tracked control click events
@property(nonatomic, copy) NSDictionary *se_customProperties API_UNAVAILABLE(macos);

@end

@interface UIViewController (SolarEngine)

/// Whether to ignore auto-tracking on the current page. If enabled, all control click auto-tracking on this page will also be ignored.
@property(nonatomic, assign) BOOL se_ignoreAutoTrack API_UNAVAILABLE(macos);

/// Custom properties that will be reported along with auto-tracked page view events
@property(nonatomic, copy) NSDictionary *se_customProperties API_UNAVAILABLE(macos);

@end

@protocol SEScreenAutoTracker <NSObject>

@optional

- (NSString *_Nullable)getScreenUrl API_UNAVAILABLE(macos);

@end
#endif

NS_ASSUME_NONNULL_END
