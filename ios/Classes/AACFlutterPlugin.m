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
    }
    
    return self;
}

// Handle method calls for static methods on the SDK.
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if([call.method isEqual:@"setApiBaseUrl"]) {
        AACValidateArguments(call.arguments, @[ NSString.class ], result);
        [self setApiBaseUrl:call.arguments[0]];
        result(@(YES));
    }
    
    if([call.method isEqual:@"initialise"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self initialiseWithEnvironmentId:call.arguments[0] apiKey:call.arguments[1]];
        result(@(YES));
    }
    
    if([call.method isEqual:@"setLoggingEnabled"]) {
        AACValidateArguments(call.arguments, @[ NSNumber.class ], result);
        NSNumber* numberValue = (NSNumber*)call.arguments[0];
        [self setLoggingEnabled:numberValue.boolValue];
        result(@(YES));
    }
    
    if([call.method isEqual:@"logout"]) {
        AACValidateArguments(call.arguments, @[], result);
        [self logout];
        result(@(YES));
    }
    
    if([call.method isEqual:@"registerDeviceForNotifications"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerDeviceForNotifications:call.arguments[0]
                         authenticationToken:call.arguments[1]
                                      result:result];
    }
    
    if([call.method isEqual:@"registerStreamContainersForNotifications"]) {
        NSArray *types = @[ NSArray.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerStreamContainersForNotifications:call.arguments[0]
                                                 token:call.arguments[1]
                                                result:result];
    }
    
    if([call.method isEqual:@"registerStreamContainersForNotificationsEnabled"]) {
        NSArray *types = @[ NSString.class, NSString.class, NSNumber.class ];
        AACValidateArguments(call.arguments, types, result);
        BOOL enabled = [(NSNumber*)call.arguments[2] boolValue];
        [self registerStreamContainersForNotifications:call.arguments[0]
                                                 token:call.arguments[1]
                                               enabled:enabled
                                                result:result];
    }
    
    if([call.method isEqual:@"deregisterDeviceForNotifications"]) {
        AACValidateArguments(call.arguments, @[], result);
        [self deregisterDeviceForNotifications:result];
    }
    
    if([call.method isEqual:@"notificationFromPushPayload"]) {
        AACValidateArguments(call.arguments, @[ NSDictionary.class ], result);
        [self notificationFromPushPayload:call.arguments[0]
                                   result:result];
    }
    
    // Card count
    if([call.method isEqual:@"observeCardCount"]) {
        NSArray *types = @[ NSString.class, NSNumber.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self observeCardCount:call.arguments[0]
             atPollingInterval:call.arguments[1]
                 withAuthToken:call.arguments[2]
                        result:result];
    }
    
    if([call.method isEqual:@"stopObservingCardCount"]) {
        NSArray *types = @[ NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self stopObservingCardCount:call.arguments[0]
                              result:result];
    }
    
    if([call.method isEqual:@"trackPushNotificationReceived"]) {
        NSArray *types = @[ NSDictionary.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self trackPushNotificationReceived:call.arguments[0]
                              withAuthToken:call.arguments[1]
                                     result:result];
    }
    
    if([call.method isEqual:@"sendEvent"]) {
        NSArray *types = @[ NSDictionary.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self sendEvent:call.arguments[0]
          withAuthToken:call.arguments[1]
                 result:result];
    }
    
    if([call.method isEqual:@"requestCardCount"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self requestCardCountForStreamContainerWithIdentifier:call.arguments[0]
                                                 withAuthToken:call.arguments[1]
                                                        result:result];
    }
    
    if([call.method isEqual:@"userMetrics"]) {
        NSArray *types = @[ NSString.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self userMetricsForStreamContainerWithIdentifier:call.arguments[0]
                                            withAuthToken:call.arguments[1]
                                                   result:result];
    }
    
    if([call.method isEqual:@"registerEmbeddedFonts"]) {
        NSArray *types = @[ NSArray.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerEmbeddedFonts:call.arguments[0]];
        result(@(YES));
    }
}

#pragma mark - SDK method implementations

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
                                     withAuthToken:(NSString*)authToken
                                            result:(FlutterResult)result {
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    [AACSession userMetricsWithSessionDelegate:sessionDelegate completionHandler:^(AACUserMetrics * _Nullable response, NSError * _Nullable error) {
        if(error == nil) {
            NSInteger totalCards = 0;
            NSInteger unseenCards = 0;
            
            if([containerId isEqualToString:@""]) {
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
                                          withAuthToken:(NSString*)authToken
                                                 result:(FlutterResult)result {
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    [AACSession requestCardCountForStreamContainerWithIdentifier:containerId sessionDelegate:sessionDelegate handler:^(NSNumber * _Nullable cardCount) {
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
   withAuthToken:(NSString*)authToken
          result:(FlutterResult)result {
    AACFlutterSessionDelegate * sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
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
    [AACSession sendEvent:eventPayload withSessionDelegate:sessionDelegate completionHandler:^(AACEventResponse * _Nullable response, NSError * _Nullable error) {
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
            [AACFlutterLogger log:@"Failed to send event payload. %@", error];
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
        [AACFlutterLogger log:@"Failed to set API base URL: `%@` is not a valid URL.", url];
    }
}

- (void)initialiseWithEnvironmentId:(NSString*)envId apiKey:(NSString*)apiKey {
    [AACSession initialiseWithEnvironmentId:envId apiKey:apiKey];
}

- (void)setLoggingEnabled:(BOOL)enabled {
    [AACSession setLoggingEnabled:enabled];
    [AACFlutterLogger setLoggingEnabled:enabled];
}

- (void)logout {
    [AACSession logout];
}

- (void)trackPushNotificationReceived:(NSDictionary*)payload
                        withAuthToken:(NSString*)authToken
                               result:(FlutterResult)result {
    AACFlutterSessionDelegate * sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    [AACSession trackPushNotificationReceived:payload withSessionDelegate:sessionDelegate completionHandler:^(NSError * _Nullable error) {
        if(error == nil) {
            result(@(YES));
        } else {
            [AACFlutterLogger log:@"Failed to track push notification receipt. The push notification payload may not be for an Atomic notification. %@", error];
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

- (void)registerStreamContainersForNotifications:(NSArray*)containerIds
                                           token:(NSString*)authToken
                                          result:(FlutterResult)result {
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    
    [AACSession registerStreamContainersForPushNotifications:containerIds sessionDelegate:sessionDelegate completionHandler:^(NSError * _Nullable error) {
        if(error == nil) {
            result(@(YES));
        } else {
            if(containerIds.count > 0) {
                [AACFlutterLogger log:@"Failed to register push notifications for stream containers %@ etc. %@", containerIds[0], error];
            } else {
                [AACFlutterLogger log:@"Failed to register push notifications for stream containers. %@", error];
            }
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

- (void)registerStreamContainersForNotifications:(NSArray*)containerIds
                                           token:(NSString*)authToken
                                         enabled:(BOOL)notificationsEnabled
                                          result:(FlutterResult)result {
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    
    [AACSession registerStreamContainersForPushNotifications:containerIds
                                             sessionDelegate:sessionDelegate
                                        notificationsEnabled:notificationsEnabled
                                           completionHandler:^(NSError * _Nullable error) {
        if(error == nil) {
            result(@(YES));
        } else {
            if(containerIds.count > 0) {
                [AACFlutterLogger log:@"Failed to register push notifications for stream containers %@ etc. %@", containerIds[0], error];
            } else {
                [AACFlutterLogger log:@"Failed to register push notifications for stream containers. %@", error];
            }
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

- (void)registerDeviceForNotifications:(NSString*)pushToken
                   authenticationToken:(NSString*)authToken
                                result:(FlutterResult)result {
    NSData *tokenData = [pushToken aacFlutter_dataFromHexString];
    
    if(tokenData == nil) {
        [AACFlutterLogger log:@"Empty or invalid token provided when registering for push notifications."];
        return;
    }
    
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    
    [AACSession registerDeviceForNotifications:tokenData withSessionDelegate:sessionDelegate completionHandler:^(NSError * _Nullable error) {
        if(error == nil) {
            result(@(YES));
        } else {
            [AACFlutterLogger log:@"Failed to register push notifications for the device. %@", error];
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
        }
    }];
}

- (void)deregisterDeviceForNotifications:(FlutterResult)result {
    [AACSession deregisterDeviceForNotificationsWithCompletionHandler:^(NSError *error) {
        if(error == nil) {
            result(@(YES));
        } else {
            [AACFlutterLogger log:@"Failed to deregister device for push notifications. %@", error];
            NSString *errorCode = [NSString stringWithFormat:@"%@ (error code %@)", error.domain, @(error.code)];
            FlutterError *flutterError = [FlutterError errorWithCode:errorCode message:error.localizedDescription details:nil];
            result(flutterError);
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
           withAuthToken:(NSString*)authToken
                  result:(FlutterResult)result {
    AACFlutterCardCountObserver *observer = [[AACFlutterCardCountObserver alloc] init];
    
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    observer.sessionDelegate = sessionDelegate;
    
    NSString *identifier = [NSString stringWithFormat:@"AACFlutterCardCountObserver-%@", @(kAACFlutterCardCountObserverId++)];
    observer.identifier = identifier;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        id<NSObject> token = [AACSession observeCardCountForStreamContainerWithIdentifier:containerId
                                                                                 interval:interval.doubleValue
                                                                          sessionDelegate:sessionDelegate
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
