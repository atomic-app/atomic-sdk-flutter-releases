//
// AACFlutterSessionDelegate.h
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AtomicSDK;

/**
 Session delegate that immediately returns the specified token when requested.
 */
@interface AACFlutterSessionDelegate: NSObject <AACSessionDelegate>

@property (nonatomic, copy) NSString *authenticationToken;

@end
