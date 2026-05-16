// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Test harness for the Objective-C BetterKhmer port.

#import <Foundation/Foundation.h>
#import "BetterKhmer.h"

static NSArray<NSString *> *readLines(NSString *path) {
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
    if (content == nil) {
        fprintf(stderr, "cannot read %s: %s\n",
                path.UTF8String, err.localizedDescription.UTF8String);
        exit(1);
    }
    // Split on newline; mirror File.ReadAllLines (drop a trailing empty line
    // produced by a final newline).
    NSMutableArray<NSString *> *lines =
        [[content componentsSeparatedByString:@"\n"] mutableCopy];
    if (lines.count > 0 && [lines.lastObject length] == 0) {
        [lines removeLastObject];
    }
    // Strip a trailing \r if files use CRLF.
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *s = lines[i];
        if (s.length > 0 && [s characterAtIndex:s.length - 1] == '\r') {
            lines[i] = [s substringToIndex:s.length - 1];
        }
    }
    return lines;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *fixturesDir = argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"../../fixtures";

        NSString *got = [BetterKhmer normalize:@"ខ្មែរ"];
        if (![got isEqualToString:@"ខ្មែរ"]) {
            fprintf(stderr, "basic FAILED: got %s\n", got.UTF8String);
            return 1;
        }
        printf("basic: ok\n");

        NSArray<NSString *> *inputs =
            readLines([fixturesDir stringByAppendingPathComponent:@"input.txt"]);
        NSArray<NSString *> *expected =
            readLines([fixturesDir stringByAppendingPathComponent:@"expected.txt"]);

        if (inputs.count != expected.count) {
            fprintf(stderr, "length mismatch\n");
            return 1;
        }

        int failures = 0;
        for (NSUInteger i = 0; i < inputs.count; i++) {
            NSString *result = [BetterKhmer normalize:inputs[i]];
            if (![result isEqualToString:expected[i]]) {
                failures++;
                if (failures <= 10) {
                    fprintf(stderr, "[%lu] got %s, want %s\n",
                            (unsigned long)i, result.UTF8String,
                            expected[i].UTF8String);
                }
            }
        }

        if (failures > 0) {
            fprintf(stderr, "%d/%lu fixture failures\n",
                    failures, (unsigned long)inputs.count);
            return 1;
        }
        printf("fixtures: %lu ok\n", (unsigned long)inputs.count);
    }
    return 0;
}
