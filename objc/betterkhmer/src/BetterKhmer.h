// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Objective-C — BetterKhmer package. Regex-free.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BetterKhmer : NSObject

/// Returns the Khmer-normalized form of txt (lang defaults to "km").
+ (NSString *)normalize:(NSString *)txt;

/// Returns the Khmer-normalized form of txt for the given lang ("km" or "xhm").
+ (NSString *)normalize:(NSString *)txt lang:(NSString *)lang;

@end

NS_ASSUME_NONNULL_END
