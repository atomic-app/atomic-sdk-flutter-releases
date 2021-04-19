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
#import "AACFlutterLogger.h"
#import "AACFlutterCardCountObserver.h"

@import AtomicSDK;

static int kAACFlutterCardCountObserverId = 1;

static BOOL AACValidateArgumentsImpl(id arguments, NSArray<Class>* types) {
    if([arguments isKindOfClass:NSArray.class] == NO) {
        [AACFlutterLogger log:@"Argument validation failed: expected NSArray but received %@.", arguments];
        return NO;
    }
    
    NSArray *args = (NSArray*)arguments;
    
    // Check we have the right number of arguments.
    if(args.count != types.count) {
        [AACFlutterLogger log:@"Argument validation failed: count mismatch. Expected %@ arguments but received %@.", @(types.count), @(args.count)];
        return NO;
    }
    
    // Check each argument is of the correct type.
    for(int i = 0; i < args.count; i++) {
        if([args[i] isKindOfClass:types[i]] == NO) {
            [AACFlutterLogger log:@"Argument validation failed: argument at index %@ was not of type %@, got %@ instead.", @(i), NSStringFromClass(types[i]), args[i]];
            return NO;
        }
    }
    
    return YES;
};

#define AACValidateArguments(args, types, result) if(AACValidateArgumentsImpl(args, types) == NO) { result(@(NO)); return; }

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
                         authenticationToken:call.arguments[1]];
        result(@(YES));
    }
    
    if([call.method isEqual:@"registerStreamContainersForNotifications"]) {
        NSArray *types = @[ NSArray.class, NSString.class ];
        AACValidateArguments(call.arguments, types, result);
        [self registerStreamContainersForNotifications:call.arguments[0]
                                                 token:call.arguments[1]];
        result(@(YES));
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
}

#pragma mark - SDK method implementations
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

- (void)registerStreamContainersForNotifications:(NSArray*)containerIds
                                           token:(NSString*)authToken {
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    
    [AACSession registerStreamContainersForPushNotifications:containerIds
                                             sessionDelegate:sessionDelegate];
}

- (void)registerDeviceForNotifications:(NSString*)pushToken
                   authenticationToken:(NSString*)authToken {
    NSData *tokenData = [pushToken aacFlutter_dataFromHexString];
    
    if(tokenData == nil) {
        [AACFlutterLogger log:@"Empty or invalid token provided when registering for push notifications."];
        return;
    }
    
    AACFlutterSessionDelegate *sessionDelegate = [[AACFlutterSessionDelegate alloc] init];
    sessionDelegate.authenticationToken = authToken;
    
    [AACSession registerDeviceForNotifications:tokenData
                           withSessionDelegate:sessionDelegate];
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
