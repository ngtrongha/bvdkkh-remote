// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remoter
// Author: Nguyễn Trọng Hà

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// Stub for legacy darwin network references in rust dependencies absent on iOS SDK
__attribute__((visibility("default"))) __attribute__((weak))
const CFStringRef kSCNetworkInterfaceTypeIrDA = CFSTR("IrDA");
