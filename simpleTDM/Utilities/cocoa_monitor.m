#include "cocoa_monitor.h"
#include <Foundation/Foundation.h>

NSString* getScreenName(CGDirectDisplayID displayID) {
    NSString *screenName = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSDictionary *deviceInfo = (__bridge NSDictionary *)IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID), kIODisplayOnlyPreferredName);
#pragma clang diagnostic pop
    NSDictionary *localizedNames = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
    
    if ([localizedNames count] > 0) {
        screenName = [localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]];
    }
    
    return screenName;
}

void enterTargetDisplayMode(void) {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    
    CGEventRef f2d = CGEventCreateKeyboardEvent(src, 0x90, true);
    CGEventRef f2u = CGEventCreateKeyboardEvent(src, 0x90, false);
    
    CGEventSetFlags(f2d, kCGEventFlagMaskSecondaryFn | kCGEventFlagMaskCommand);
    CGEventSetFlags(f2u, kCGEventFlagMaskSecondaryFn | kCGEventFlagMaskCommand);
    
    CGEventTapLocation loc = kCGHIDEventTap;
    CGEventPost(loc, f2d);
    CGEventPost(loc, f2u);
    
    CFRelease(f2d);
    CFRelease(f2u);
    CFRelease(src);
}
