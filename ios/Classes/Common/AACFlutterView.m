//
// AACFlutterView.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACFlutterView.h"
#import "AACConfiguration+Flutter.h"

@implementation AACFlutterView

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    
    if(self) {
        NSString *channelName = [NSString stringWithFormat:@"%@/%@", self.viewType, @(viewId)];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        
        AACConfiguration *configuration = [[AACConfiguration alloc] init];
        NSString *containerId = nil;
        
        if([args isKindOfClass:NSDictionary.class]) {
            NSDictionary *dict = args;
            configuration = [AACConfiguration fromFlutterDictionary:dict[@"configuration"] ?: @{}];
            containerId = args[@"containerId"];
        }
        
        [self createViewWithFrame:frame containerId:containerId configuration:configuration];
    }
    
    return self;
}

- (void)createViewWithFrame:(CGRect)frame
                containerId:(NSString *)containerId
              configuration:(AACConfiguration *)configuration {
    // Overridden by subclasses.
}

- (UIView *)view {
    // Overridden by subclasses.
    return nil;
}

- (UIViewController*)rootViewController {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

- (void)dealloc {
    _channel = nil;
}

#pragma mark - AACSessionDelegate
- (void)cardSessionDidRequestAuthenticationTokenWithHandler:(AACSessionAuthenticationTokenHandler)handler {
    [self.channel invokeMethod:@"requestAuthenticationToken" arguments:nil result:^(id result) {
        if([result isKindOfClass:NSString.class]) {
            handler(result);
        } else {
            handler(nil);
        }
    }];
}

@end
