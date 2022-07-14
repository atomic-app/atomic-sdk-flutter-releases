//
// AACFlutterView.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACFlutterView.h"
#import "AACConfiguration+Flutter.h"
#import "AACValidateArguments.h"

NSString *_Nonnull const kAACErrorCodeUnsupportedChannelCommand = @"01";

@implementation AACFlutterView

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    
    if(self) {
        __weak typeof(self) weakSelf = self;
        NSString *channelName = [NSString stringWithFormat:@"%@/%@", self.viewType, @(viewId)];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        [_channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            [weakSelf methodCallHandler:call result:result];
        }];
        AACConfiguration *configuration = [[AACConfiguration alloc] init];
        NSString *containerId = nil;
        
        if([args isKindOfClass:NSDictionary.class]) {
            NSDictionary *dict = args;
            configuration = [AACConfiguration fromFlutterDictionary:dict[@"configuration"] ?: @{}];
            configuration.actionDelegate = self;
            configuration.cardEventDelegate = self;
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

- (void)methodCallHandler:(FlutterMethodCall*) call
                   result:(FlutterResult) result {
    if([call.method isEqual:@"applyFilter"]) {
        AACValidateArguments(call.arguments, @[ NSDictionary.class ], result);
        dispatch_async(dispatch_get_main_queue(), ^{
            // Must run on the main thread as this is a UI method.
            NSString *filterId = call.arguments[0][@"byCardInstanceId"];
            AACCardFilter *filter = [AACCardListFilter filterByCardInstanceId:filterId];
            [self applyFilter:filter];
        });
        result(@(YES));
        return;
    }
    
    if([call.method isEqual:@"refresh"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refresh];
        });
        result(@(YES));
        return;
    }
    
    if([call.method isEqual:@"updateVariables"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateVariables];
        });
        result(@(YES));
        return;
    }
    
    NSString *errorMessage = [NSString stringWithFormat:@"Unsupported command: %@", call.method];
    FlutterError *flutterError = [FlutterError errorWithCode:kAACErrorCodeUnsupportedChannelCommand
                                                     message:errorMessage
                                                     details:@"Failed to process channel command"];
    result(flutterError);
}

-(void)refresh {
    // Does nothing by default.
}

- (void)applyFilter:(AACCardFilter*)filter {
  // Does nothing by default.
}

- (void)updateVariables {
    // Does nothing by default.
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

- (void)cardSessionDidRequestRuntimeVariables:(NSArray<AACCardInstance *> *)cardsToResolve completionHandler:(AACSessionRuntimeVariablesHandler)completionHandler {
    if(cardsToResolve.count == 0) { return; }
    NSMutableArray *cardsToResolveRaw = [[NSMutableArray alloc] init];
    for(AACCardInstance *card in cardsToResolve) {
        NSMutableArray *variables = [[NSMutableArray alloc] init];
        for(AACCardRuntimeVariable *variable in card.runtimeVariables) {
            [variables addObject:@{
                            @"name": variable.name,
                            @"defaultValue": variable.defaultValue
            }];
        }
        [cardsToResolveRaw addObject:@{
                    @"eventName": card.eventName,
                    @"lifecycleId": card.lifecycleId,
                    @"runtimeVariables": variables
        }];
    }
    [self.channel invokeMethod:@"requestRuntimeVariables"
                     arguments: @{ @"cardsToResolve": cardsToResolveRaw }
                        result:^(id  _Nullable result) {
        if(result != nil && [result isKindOfClass:NSArray.class]) {
            for(NSDictionary *cardRaw in result) {
                NSString *lifeCycleId = cardRaw[@"lifecycleId"];
                NSArray *runtimeVariablesRaw = cardRaw[@"runtimeVariables"];
                NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                    AACCardInstance *ob = evaluatedObject;
                    return [ob.lifecycleId isEqualToString:lifeCycleId];
                }];
                NSArray<AACCardInstance *> *matchedCards = [cardsToResolve filteredArrayUsingPredicate:predicate];
                for(AACCardInstance *card in matchedCards) {
                    for(NSDictionary *variableRaw in runtimeVariablesRaw) {
                        [card resolveRuntimeVariableWithName:variableRaw[@"name"] value:variableRaw[@"runtimeValue"]];
                    }
                }
            }
            completionHandler(cardsToResolve);
        }
    }];
}

#pragma mark - AACStreamContainerActionDelegate
- (void)streamContainerDidTapLinkButton:(AACStreamContainerViewController *)streamContainer withAction:(AACCardCustomAction *)action {
    [self.channel invokeMethod:@"didTapLinkButton" arguments:@{
        @"cardInstanceId": action.cardInstanceId,
        @"containerId": action.containerId,
        @"actionPayload": action.actionPayload
    }];
}

- (void)streamContainerDidTapSubmitButton:(AACStreamContainerViewController *)streamContainer withAction:(AACCardCustomAction *)action {
    [self.channel invokeMethod:@"didTapSubmitButton" arguments:@{
        @"cardInstanceId": action.cardInstanceId,
        @"containerId": action.containerId,
        @"actionPayload": action.actionPayload
    }];
}

#pragma mark - AACCardEventDelegate
- (void)streamContainer:(AACStreamContainerViewController *)streamContainerVc didTriggerCardEvent:(AACCardEvent *)event {
    
    NSString *kind;
    switch (event.kind) {
        case AACCardEventKindSubmitted:
            kind = @"cardSubmitted";
            break;
        case AACCardEventKindDismissed:
            kind = @"cardDismissed";
            break;
        case AACCardEventKindSnoozed:
            kind = @"cardSnoozed";
            break;
        case AACCardEventKindVotedUseful:
            kind = @"cardVotedUseful";
            break;
        case AACCardEventKindVotedNotUseful:
            kind = @"cardVotedNotUseful";
            break;
        case AACCardEventKindSubmitFailed:
            kind = @"cardSubmitFailed";
            break;
        case AACCardEventKindDismissFailed:
            kind = @"cardDismissFailed";
            break;
        case AACCardEventKindSnoozeFailed:
            kind = @"cardSnoozeFailed";
            break;
    }
    [self.channel invokeMethod:@"didTriggerCardEvent" arguments:@{
        @"cardEvent": @{@"kind": kind}
    }];
}
@end
