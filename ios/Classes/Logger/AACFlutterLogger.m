//
// AACFlutterLogger.m
// Atomic SDK - Flutter
// Copyright © 2021 Atomic.io Limited. All rights reserved.
//

#import "AACFlutterLogger.h"
@import os.log;

@interface AACFlutterLogger ()

@property (nonatomic) BOOL loggingEnabled;

@end

@implementation AACFlutterLogger

+ (AACFlutterLogger*)sharedLogger {
    static dispatch_once_t onceToken;
    static AACFlutterLogger *sharedLogger;
    dispatch_once(&onceToken, ^{
        sharedLogger = [[AACFlutterLogger alloc] init];
    });
    return sharedLogger;
}

+ (void)setLoggingEnabled:(BOOL)enabled {
    [self sharedLogger].loggingEnabled = enabled;
}

+ (void)log:(NSString*)format, ... {
    if([self sharedLogger].loggingEnabled == NO) {
        return;
    }
    
    va_list args;
    va_start(args, format);
    
    if(@available(iOS 10, *)) {
        // Use the new unified logging API.
        os_log(OS_LOG_DEFAULT, "%{public}s", [[[NSString alloc] initWithFormat:format arguments:args] cStringUsingEncoding:NSUTF8StringEncoding]);
    } else {
        // Fallback to NSLog.
        NSLogv(format, args);
    }
    
    va_end(args);
}

@end
