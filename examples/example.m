#import <Foundation/Foundation.h>
#import "BetterKhmer.h"

int main(void) {
    @autoreleasepool {
        NSString *text = @"ខ្មែរ";
        NSString *result = [BetterKhmer normalize:text];
        printf("%s\n", result.UTF8String);
    }
    return 0;
}
