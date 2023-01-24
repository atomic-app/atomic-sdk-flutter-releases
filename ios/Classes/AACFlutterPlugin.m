//
// AACFlutterPlugin.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACFlutterPlugin.h"
#import "AACFlutterStreamContainer.h"
#import "AACFlutterSingleCardView.h"
#import "AACFlutterSessionDelegate.h"
#import "NSString+FlutterHexData.h"
#import "AACFlutterCardCountObserver.h"
#import "AACValidateArguments.h"

@import AtomicSDK;

static int kAACFlutterCardCountObserverId = 1;

static NSDictionary *kAACFlutterFontWeight = nil;
static NSDictionary *kAACFlutterFontStyle = nil;

@interface AACFlutterPlugin ()

@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) NSMutableDictionary *cardCountObservers;
@property (nonatomic, strong) AACFlutterSessionDelegate *sessionDelegate;
@property (nonatomic) NSTimeInterval authTokenRetryInterval;
@property (nonatomic) NSTimeInterval authTokenExpiryInterval;

@end

@implementation AACFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    AACFlutterStreamContainerFactory *factory = [[AACFlutterStreamContainerFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:factory withId:@"io.atomic.sdk.streamContainer"];
    
    AACFlutterSingleCardViewFactory *scvFactory = [[AACFlutterSingleCardViewFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:scvFactory withId:@"io.atomic.sdk.singleCard"];
    
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"io.atomic.sdk.session" binaryMessenger:registrar.messenger];
    AACFlutterPlugin *plugin = [[AACFlutterPlugin alloc] initWithMethodChannel:channel];
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (instancetype)initWithMethodChannel:(FlutterMethodChannel*)channel {
    self = [super init];
    
    if(self) {
        self.channel = channel;
        self.cardCountObservers = [[NSMutableDictionary alloc] init];
        self.authTokenRetryInterval = 0;
        self.authTokenExpiryInterval = 60;
    }
    
    return self;
}

// Handle method calls for static methods on the SDK.
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if([call.method isEqual:@"setApiBaseUrl"]) {
        AACValidateArguments(call.arguments, @[ NSString.class ], result);
        [self setApiBaseUrl:call.arguments[0]];
        result(@(YES));
    } else if([call.method isEqual:@"initialise"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self initialiseWithEnvironmentId:call.arguments[0] apiKey:call.arguments[1]];
        result(@(YES));
    } else if([call.method isEqual:@"enableDebugMode"]) {
        AACValidateArguments(call.arguments, @[ NSNumber.class ], result);
        NSNumber* numberValue = (NSNumber*)call.arguments[0];
        [self enableDebugMode:numberValue.intValue];
        result(@(YES));
    } else if([call.method isEqual:@"onAuthTokenReceived"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self.sessionDelegate didReceiveAuthenticationToken:call.arguments[0] forIdentifier:call.arguments[1]];
        result(@(YES));
    } else if([call.method isEqual:@"logout"]) {
        AACValidateArguments(call.arguments, @[], result);
        [self logout:result];
    } else if([call.method isEqual:@"registerDeviceForNotifications"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerDeviceForNotifications:call.arguments[0]
                                      result:result];
    } else if([call.method isEqual:@"registerStreamContainersForNotifications"]) {
        NSArray *types = @[ NSArray.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerStreamContainersForNotifications:call.arguments[0]
                                                result:result];
    } else if([call.method isEqual:@"registerStreamContainersForNotificationsEnabled"]) {
        NSArray *types = @[ NSArray.class, NSNumber.class ];
        AACValidateArguments(call.arguments, types, result);
        BOOL enabled = [(NSNumber*)call.arguments[2] boolValue];
        [self registerStreamContainersForNotifications:call.arguments[0]
                                               enabled:enabled
                                                result:result];
    } else if([call.method isEqual:@"deregisterDeviceForNotifications"]) {
        AACValidateArguments(call.arguments, @[], result);
        [self deregisterDeviceForNotifications:result];
    } else if([call.method isEqual:@"notificationFromPushPayload"]) {
        AACValidateArguments(call.arguments, @[ NSDictionary.class ], result);
        [self notificationFromPushPayload:call.arguments[0]
                                   result:result];
    } else if([call.method isEqual:@"observeCardCount"]) {
        NSArray *types = @[ NSString.class, NSNumber.class ];
        AACValidateArguments(call.arguments, types, result);
        [self observeCardCount:call.arguments[0]
             atPollingInterval:call.arguments[1]
                        result:result];
    } else if([call.method isEqual:@"stopObservingCardCount"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self stopObservingCardCount:call.arguments[0]
                              result:result];
    } else if([call.method isEqual:@"trackPushNotificationReceived"]) {
        NSArray *types = @[ NSDictionary.class ];
        AACValidateArguments(call.arguments, types, result);
        [self trackPushNotificationReceived:call.arguments[0]
                                     result:result];
    } else if([call.method isEqual:@"sendEvent"]) {
        NSArray *types = @[ NSDictionary.class ];
        AACValidateArguments(call.arguments, types, result);
        [self sendEvent:call.arguments[0]
                 result:result];
    } else if([call.method isEqual:@"requestCardCount"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self requestCardCountForStreamContainerWithIdentifier:call.arguments[0]
                                                        result:result];
    } else if([call.method isEqual:@"userMetrics"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self userMetricsForStreamContainerWithIdentifier:call.arguments[0]
                                                   result:result];
    } else if([call.method isEqual:@"registerEmbeddedFonts"]) {
        NSArray *types = @[ NSArray.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerEmbeddedFonts:call.arguments[0]];
        result(@(YES));
    } else if([call.method isEqual:@"setApiProtocol"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self setApiProtocol:call.arguments[0]];
        result(@(YES));
    } else if([call.method isEqual:@"setSessionDelegateRetryInterval"]) {
        NSArray *types = @[ NSNumber.class];
        AACValidateArguments(call.arguments, types, result);
        [self setSessionDelegateRetryInterval:call.arguments[0]];
        result(@(YES));
    } else if([call.method isEqual:@"setSessionDelegateExpiryInterval"]) {
        NSArray *types = @[ NSNumber.class];
        AACValidateArguments(call.arguments, types, result);
        [self setSessionDelegateExpiryInterval:call.arguments[0]];
        result(@(YES));
    } else {
        NSString *message = [NSString stringWithFormat:@"Method call (%@) not implemented.", call.method];
        [AACFlutterLogger warn:message];
        result(@(YES));
    }
}

#pragma mark - SDK method implementations

-(void)setSessionDelegateExpiryInterval:(NSNumber *)expiryInterval {
    if(expiryInterval.doubleValue < 0) {
        return;
    }
    self.authTokenExpiryInterval = expiryInterval.doubleValue;
    if(self.sessionDelegate != nil) {
        self.sessionDelegate.expiryIntervalFromFlutter = expiryInterval.doubleValue;
        [AACSession setSessionDelegate:self.sessionDelegate];
    }
}

-(void)setSessionDelegateRetryInterval:(NSNumber *)retryInterval {
    if(retryInterval.doubleValue < 0) {
        return;
    }
    self.authTokenRetryInterval = retryInterval.doubleValue;
    if(self.sessionDelegate != nil) {
        self.sessionDelegate.retryIntervalFromFlutter = retryInterval.doubleValue;
        [AACSession setSessionDelegate:self.sessionDelegate];
    }
}

-(void)setApiProtocol:(NSString *)protocolName {
    if([protocolName isEqualToString:@"http"]) {
        [AACSession setApiProtocol:AACApiProtocolHttp];
    } else if([protocolName isEqualToString:@"webSockets"]){
        [AACSession setApiProtocol:AACApiProtocolWebSockets];
    }
}

-(void)registerEmbeddedFonts:(NSArray*)fontList {
    NSDictionary *dicFontWeight = @{
        @"bold": @(AACFontWeightBold),
        @"regular": @(AACFontWeightRegular)
    };
    NSDictionary *dicFontStyle = @{
        @"italic": @(AACFontStyleItalic),
        @"normal": @(AACFontStyleNormal)
    };
    NSMutableArray<AACEmbeddedFont *> *embeddedFonts = [[NSMutableArray alloc] init];
    for(NSDictionary *fontRaw in fontList) {
        AACFontWeight weight = [dicFontWeight[fontRaw[@"weight"]] intValue];
        AACFontStyle style = [dicFontStyle[fontRaw[@"style"]] intValue];
        AACEmbeddedFont *font = [[AACEmbeddedFont alloc] initWithFamilyName:fontRaw[@"familyName"]
                                                             postscriptName:fontRaw[@"postscriptName"]
                                                                     weight:weight
                                                                      style:style];
        [embeddedFonts addObject:font];
    }
    [AACSession registerEmbeddedFonts:embeddedFonts];
}

-(void)userMetricsForStreamContainerWithIdentifier:(NSString*)containerId
                                            result:(FlutterResult)result {
    [AACSession userMetricsWithCompletionHandler:^(AACUserMetrics *response, NSError *error) {
        if(error == nil) {
            NSInteger totalCards = 0;
            NSInteger unseenCards = 0;
            
            if(containerId.length == 0) {
                totalCards = [response totalCards];
                unseenCards = [response unseenCards];
            } else {
                totalCards = [response totalCardsForStreamContainerWithId:containerId];
                unseenCards = [response unseenCardsForStreamContainerWithId:containerId];
            }
            
            result(@{
                @"totalCards": @(totalCards),
                @"unseenCards": @(unseenCards)
            });
        } else {
            [AACFlutterLogger log:@"Failed to request user metrics. %@", error];
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

-(void)requestCardCountForStreamContainerWithIdentifier:(NSString*)containerId
                                                 result:(FlutterResult)result {
    [AACSession requestCardCountForStreamContainerWithIdentifier:containerId handler:^(NSNumber *cardCount) {
        if(cardCount != nil) {
            result(@([cardCount intValue]));
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"The card count is not available for this stream container (%@).", containerId];
            [AACFlutterLogger log:errMsg];
            FlutterError *flutterError = [FlutterError errorWithCode:@"AACSessionRequestCardCountForStreamContainerErrorDomain (error code 1)" message:errMsg details:nil];
            result(flutterError);
        }
    }];
}

-(void)sendEvent:(NSDictionary*)payload
          result:(FlutterResult)result {
    AACEventPayload *eventPayload = [[AACEventPayload alloc] initWithName:payload[@"name"]];
    eventPayload.lifecycleId = payload[@"lifecycleId"];
    id dicValue = payload[@"detail"];
    if([dicValue isKindOfClass:NSDictionary.class] == YES) {
        eventPayload.detail = (NSDictionary*)dicValue;
    }
    dicValue = payload[@"metadata"];
    if([dicValue isKindOfClass:NSDictionary.class] == YES) {
        eventPayload.metadata = (NSDictionary*)dicValue;
    }
    dicValue = payload[@"notificationDetail"];
    if([dicValue isKindOfClass:NSDictionary.class] == YES) {
        eventPayload.notificationDetail = (NSDictionary*)dicValue;
    }
    
    [AACSession sendEvent:eventPayload withCompletionHandler:^(AACEventResponse *response, NSError *error) {
        if(error == nil) {
            NSMutableArray *processedEvents = [[NSMutableArray alloc] init];
            for(AACProcessedEvent *event in response.processedEvents) {
                [processedEvents addObject:@{
                    @"name":event.name,
                    @"lifecycleId":event.lifecycleId,
                    @"version":@(event.version)
                }];
            }
            result(@{
                @"batchId": response.batchId,
                @"processedEvents": processedEvents
            });
        } else {
            [AACFlutterLogger error:@"Failed to send event payload. %@", error];
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

- (void)setApiBaseUrl:(NSString*)url {
    NSURL *parsedUrl = [NSURL URLWithString:url];
    
    if(parsedUrl) {
        [AACSession setApiBaseUrl:parsedUrl];
    } else {
        [AACFlutterLogger error:@"Failed to set API base URL: `%@` is not a valid URL.", url];
    }
}

- (void)initialiseWithEnvironmentId:(NSString*)envId apiKey:(NSString*)apiKey {
    [AACSession initialiseWithEnvironmentId:envId apiKey:apiKey];
    if(self.sessionDelegate == nil) {
        self.sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
        
        __weak typeof(self) weakSelf = self;
        self.sessionDelegate.authTokenCallback = ^(NSString *identifier) {
          if(weakSelf != nil) {
              [weakSelf.channel invokeMethod:@"authTokenRequested" arguments:@{
                  @"identifier": identifier
              }];
          }
        };
        self.sessionDelegate.retryIntervalFromFlutter = self.authTokenRetryInterval;
        self.sessionDelegate.expiryIntervalFromFlutter = self.authTokenExpiryInterval;
        [AACSession setSessionDelegate:self.sessionDelegate];
      }
}

- (void)enableDebugMode:(NSInteger)level {
    [AACSession enableDebugMode:level];
    [AACFlutterLogger setLoggingEnabled:level > 0];
}

- (FlutterError *)generateFlutterErrorWithError:(NSError *)error {
    NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
    NSError *underlyingError = (NSError*)error.userInfo[NSUnderlyingErrorKey];
    NSString *underlyingErrorDescription;
    if(underlyingError != nil) {
        underlyingErrorDescription = [NSString stringWithFormat:@"Underlying error: %@", underlyingError.localizedDescription];
    }
    return [FlutterError errorWithCode:errorCode message:error.localizedDescription details:underlyingErrorDescription];
}

- (void)logout:(FlutterResult)result {
    [AACSession logout:^(NSError * error) {
        if(error != nil) {
            [AACFlutterLogger error:@"Errors when logging out. %@", error];
            result([self generateFlutterErrorWithError:error]);
        } else {
            result(@(YES));
        }
    }];
}

- (void)trackPushNotificationReceived:(NSDictionary*)payload
                               result:(FlutterResult)result {
    [AACSession trackPushNotificationReceived:payload completionHandler:^(NSError * _Nullable error) {
        if(error == nil) {
            result(@(YES));
        } else {
            [AACFlutterLogger log:@"Failed to track push notification receipt. The push notification payload may not be for an Atomic notification. %@", error];
            result([self generateFlutterErrorWithError:error]);
        }
    }];
}

- (void)registerStreamContainersForNotifications:(NSArray*)containerIds
                                          result:(FlutterResult)result {
    [AACSession registerStreamContainersForPushNotifications:containerIds completionHandler:^(NSError *error) {
        if(error == nil) {
            result(@(YES));
        } else {
            if(containerIds.count > 0) {
                [AACFlutterLogger error:@"Failed to register push notifications for stream containers %@ etc. %@", containerIds[0], error];
            } else {
                [AACFlutterLogger error:@"Failed to register push notifications for stream containers. %@", error];
            }
            result([self generateFlutterErrorWithError:error]);
        }
    }];
}

- (void)registerStreamContainersForNotifications:(NSArray*)containerIds
                                         enabled:(BOOL)notificationsEnabled
                                          result:(FlutterResult)result {
    
    [AACSession registerStreamContainersForPushNotifications:containerIds
                                        notificationsEnabled:notificationsEnabled
                                           completionHandler:^(NSError *error) {
        if(error == nil) {
            result(@(YES));
        } else {
            if(containerIds.count > 0) {
                [AACFlutterLogger error:@"Failed to register push notifications for stream containers %@ etc. %@", containerIds[0], error];
            } else {
                [AACFlutterLogger error:@"Failed to register push notifications for stream containers. %@", error];
            }
            result([self generateFlutterErrorWithError:error]);
        }
    }];
}

- (void)registerDeviceForNotifications:(NSString*)pushToken
                                result:(FlutterResult)result {
    NSData *tokenData = [pushToken aacFlutter_dataFromHexString];
    
    if(tokenData == nil) {
        [AACFlutterLogger error:@"Empty or invalid token provided when registering for push notifications."];
        return;
    }
    
    /// If the Flutter host app requests push notification, the Flutter plugin framework could
    /// call this method before any other initialisation codes being executed. This is not like
    /// in iOS app where registration for notification is manually triggered by calling
    /// [[UIApplication sharedApplication] registerForRemoteNotifications].
    /// Therefore we need a special treatment to handle exceptions from none-initialised session delegate.
    @try {
        [AACSession registerDeviceForNotifications:tokenData completionHandler:^(NSError *error) {
            if(error == nil) {
                result(@(YES));
            } else {
                result([self generateFlutterErrorWithError:error]);
            }
        }];
    } @catch (NSException *exception) {
        if([exception.name isEqualToString:@"NSInternalInconsistencyException"]) {
            [AACFlutterLogger warn:@"Failed to register push notifications for the device because it's called before initialisation."];
            FlutterError *flutterError = [FlutterError errorWithCode:@"Failed to register push notifications for the device."
                                                             message:@"Called before SDK initialisation."
                                                             details:nil];
            result(flutterError);
        } else {
            @throw exception;
        }
    }
}

- (void)deregisterDeviceForNotifications:(FlutterResult)result {
    [AACSession deregisterDeviceForNotificationsWithCompletionHandler:^(NSError *error) {
        if(error == nil) {
            result(@(YES));
        } else {
            [AACFlutterLogger error:@"Failed to deregister device for push notifications. %@", error];
            result([self generateFlutterErrorWithError:error]);
        }
    }];
}

- (void)notificationFromPushPayload:(NSDictionary*)payload result:(FlutterResult)result {
    AACPushNotification *notification = [AACSession notificationFromPushPayload:payload];
    
    if(notification != nil) {
        result(@{
            @"containerId": notification.containerId ?: @"",
            @"cardInstanceId": notification.cardInstanceId ?: @"",
            @"detail": notification.detail ?: @{}
        });
    } else {
        result(nil);
    }
}

- (void)observeCardCount:(NSString*)containerId
       atPollingInterval:(NSNumber*)interval
                  result:(FlutterResult)result {
    AACFlutterCardCountObserver *observer = [[AACFlutterCardCountObserver alloc] init];
    
    NSString *identifier = [NSString stringWithFormat:@"AACFlutterCardCountObserver-%@", @(kAACFlutterCardCountObserverId++)];
    observer.identifier = identifier;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        id<NSObject> token = [AACSession observeCardCountForStreamContainerWithIdentifier:containerId
                                                                                 interval:interval.doubleValue
                                                                                  handler:^(NSNumber *cardCount) {
            if(cardCount != nil) {
                [self.channel invokeMethod:@"cardCountChanged" arguments:@{
                    @"streamContainerId": containerId,
                    @"identifier": identifier,
                    @"cardCount": cardCount
                }];
            }
        }];
        observer.token = token;
        
        self.cardCountObservers[identifier] = observer;
        result(identifier);
    });
}

- (void)stopObservingCardCount:(NSString*)identifier
                        result:(FlutterResult)result {
    AACFlutterCardCountObserver *observer = self.cardCountObservers[identifier];
    
    if(observer.token != nil) {
        [AACSession stopObservingCardCount:observer.token];
        self.cardCountObservers[identifier] = nil;
    }
    
    result(@(YES));
}

@end
