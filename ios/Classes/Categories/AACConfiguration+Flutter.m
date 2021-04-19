//
// AACConfiguration+Flutter.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACConfiguration+Flutter.h"

static NSDictionary *kAACFlutterVotingMapping = nil;
static CGFloat kAACColourScale = 255.0f;

@implementation AACConfiguration (Flutter)

+ (AACConfiguration *)fromFlutterDictionary:(NSDictionary *)dict {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kAACFlutterVotingMapping = @{
            @"none": @(AACCardVotingOptionNone),
            @"both": @(AACCardVotingOptionUseful | AACCardVotingOptionNotUseful),
            @"useful": @(AACCardVotingOptionUseful),
            @"notUseful": @(AACCardVotingOptionNotUseful)
        };
    });
    
    AACConfiguration *config = [[AACConfiguration alloc] init];
    id pollingInterval = dict[@"pollingInterval"];
    id cardVotingOptions = dict[@"cardVotingOptions"];
    id launchColors = dict[@"launchColors"];
   
    if(pollingInterval != nil && [pollingInterval isKindOfClass:NSNumber.class]) {
        config.cardListRefreshInterval = [pollingInterval doubleValue];
    }
    
    if(cardVotingOptions != nil && [cardVotingOptions isKindOfClass:NSString.class]) {
        AACCardVotingOption option = [kAACFlutterVotingMapping[cardVotingOptions] intValue];
        config.cardVotingOptions = option;
    }
    
    if(launchColors != nil && [launchColors isKindOfClass:NSDictionary.class]) {
        config.launchBackgroundColor = [self colourFromInt:launchColors[@"background"]];
        config.launchLoadingIndicatorColor = [self colourFromInt:launchColors[@"loadingIndicator"]];
        config.launchButtonColor = [self colourFromInt:launchColors[@"button"]];
        config.launchTextColor = [self colourFromInt:launchColors[@"text"]];
    }
    
    return config;
}

+ (UIColor*)colourFromInt:(id)object {
    if(object == nil || [object isKindOfClass:NSNumber.class] == NO) {
        return nil;
    }
    
    int value = [object intValue];
    
    int opacity = (0xff000000 & value) >> 24;
    int r = (0x00ff0000 & value) >> 16;
    int g = (0x0000ff00 & value) >> 8;
    int b = (0x000000ff & value) >> 0;
    
    return [UIColor colorWithRed:r/kAACColourScale
                           green:g/kAACColourScale
                            blue:b/kAACColourScale
                           alpha:opacity/kAACColourScale];
}

@end
