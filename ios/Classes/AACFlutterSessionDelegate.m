//
// AACFlutterSessionDelegate.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACFlutterSessionDelegate.h"

@implementation AACFlutterSessionDelegate

- (void)cardSessionDidRequestAuthenticationTokenWithHandler:(AACSessionAuthenticationTokenHandler)handler {
    handler(self.authenticationToken);
}

@end
