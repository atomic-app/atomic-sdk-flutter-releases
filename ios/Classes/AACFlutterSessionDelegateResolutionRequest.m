//
//  AACFlutterSessionDelegateResolutionRequest.m
//  atomic_sdk_flutter
//
//  Created by Eric on 15/12/22.
//

#import "AACFlutterSessionDelegateResolutionRequest.h"

@implementation AACFlutterSessionDelegateResolutionRequest

- (instancetype)init {
  self = [super init];
  
  if(self) {
    _identifier = [[NSUUID UUID] UUIDString];
  }
  
  return self;
}

@end
