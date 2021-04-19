//
// AACFlutterLogger.h
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AACFlutterLogger: NSObject

/**
 Sets whether debug logging should be enabled within the Flutter wrapper. This can be useful in debug
 builds when integrating the wrapper. Defaults to `NO`. Turning this on or off takes immediate effect.
 
 @param enabled Whether logging should be enabled within the Flutter wrapper.
 */
+ (void)setLoggingEnabled:(BOOL)enabled;

/**
 Sends a log message to the system log, if logging is enabled using the above method.
 */
+ (void)log:(NSString*)format, ...;

@end
