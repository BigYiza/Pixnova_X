//
//  SERemoteConfigManager.h
//  SERemoteConfigManager
//
//  Created by Mobvista on 2022/11/30.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/**

 Initialization API example
 #import <SolarEngineSDK/SolarEngineSDK.h>

 SEConfig *config = [[SEConfig alloc] init];
 SERemoteConfig *remoteConfig = [[SERemoteConfig alloc] init];
  remoteConfig.enable = YES; // Enable Remote Config
 config.remoteConfig = remoteConfig;
 [[SolarEngineSDK sharedInstance] startWithAppKey:your_appKey userId:your_userId_SolarEngine config:config];


 After initialization, the SDK will request server configuration once. It will then poll every 30 minutes (by default) to fetch the configuration again.

 */
@interface SERemoteConfigManager : NSObject

+ (SERemoteConfigManager *)sharedInstance;

/**
 * Set default configuration. If the server configuration does not match, the default will be used as a fallback.
 *
 * @param defaultConfig Default configuration. Each parameter is a dictionary with the following format:
  [
   {
         @"name" : @"k1", // Name of the config item, corresponds to the key parameter of fastFetchRemoteConfig
         @"type" : @1, // Type of the config item: 1 string, 2 integer, 3 boolean, 4 json
         @"value" : @"v1", // Value of the config item
   }
  ]
 */
- (void)setDefaultConfig:(NSArray *)defaultConfig;

/**
 * Set custom event properties. The backend will use these properties for matching when requesting configuration.
 *
 * @param properties Custom event properties, corresponding to the properties configured on the admin page
 */
- (void)setRemoteConfigEventProperties:(NSDictionary *)properties;

/**
 * Set custom user properties. The backend will use these properties for matching when requesting configuration.
 *
 * @param properties Custom user properties, corresponding to the properties configured on the admin page
 */
- (void)setRemoteConfigUserProperties:(NSDictionary *)properties;

/**
 * Synchronously fetch a parameter configuration.
 * Priority: cache first; if not found, use default config; if still not found, return nil.
 *
 * @param key  Parameter key configured on the admin page; returns the corresponding value if matched
 */
- (id _Nullable)fastFetchRemoteConfig:(NSString *)key;

/**
 * Synchronously fetch all parameter configurations.
 * Includes both default and cached configurations.
 */
- (NSDictionary *_Nullable)fastFetchRemoteConfig;

/**
 * Asynchronously fetch a parameter configuration.
 * The server configuration will be requested and merged with local cache; query from cache first, then default config; return nil if not found.
 *
 * @param key  Parameter key configured on the admin page; returns the corresponding value if matched
 */
- (void)asyncFetchRemoteConfig:(NSString *)key
             completionHandler:(void (^)(id _Nullable data))completionHandler;

/**
 * Asynchronously fetch all parameter configurations.
 * The server configuration will be requested and merged with local cache; query from cache first, then default config; return nil if not found.
 *
 */
- (void)asyncFetchRemoteConfigWithCompletionHandler:(void (^)(NSDictionary *dict))responseHandle;

- (void)setDebug:(BOOL)isDebug DEPRECATED_MSG_ATTRIBUTE();

@end

NS_ASSUME_NONNULL_END
