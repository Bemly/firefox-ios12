//
//  ReynardCellularAuthFix.m
//  Reynard (iOS 12 port)
//
//  Full port of Zuikyo/ZIKCellularAuthorization (MIT).
//  See header for the adaptation notes. Original flow preserved exactly:
//    1. _CTServerConnectionSetCellularUsagePolicy nudge (spoof com.apple.Preferences)
//    2. FTNetworkSupport -dataActiveAndReachable force-prompt
//    3. CTCellularData monitor -> requestFinish on notRestricted
//

#import "ReynardCellularAuthFix.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <CoreTelephony/CTCellularData.h>

static NSString *const ReynardCellularAuthFixedKey = @"ReynardCellularAuthFixed";
static void *ReynardCoreTelephonyHandle;
static void *ReynardFTServicesHandle;
static CTCellularData *ReynardCellularDataHandle;

static void ReynardAuthLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"ReynardCellularAuthFix: %@", msg);
    // /tmp 可写（platform-application + no-sandbox），每行 fflush，见 AGENTS.md
    FILE *f = fopen("/tmp/zikfix.log", "a");
    if (f) {
        fprintf(f, "ReynardCellularAuthFix: %s\n", [msg UTF8String]);
        fflush(f);
        fclose(f);
    }
}

@implementation ReynardCellularAuthFix

+ (void)requestCellularAuthorization {
    ReynardAuthLog(@"launch pid=%d bundle=%@", getpid(), [NSBundle mainBundle].bundleIdentifier);
    NSAssert([ReynardCellularAuthAppBundleIdentifier isEqualToString:[NSBundle mainBundle].bundleIdentifier],
             @"ReynardCellularAuthAppBundleIdentifier 和 bundle id 不一致，请手动配置");
    NSAssert(!ReynardCoreTelephonyHandle && !ReynardFTServicesHandle && !ReynardCellularDataHandle, @"不要重复调用");

    if ([self appFixed]) {
        ReynardAuthLog(@"此 app 已经执行过修复");
        return;
    }
    if (![self deviceNeedFix]) {
        ReynardAuthLog(@"设备不是 iPhone / 非 iOS 12 / 非国行 / 无蜂窝功能，不需要修复");
        return;
    }

    ReynardCoreTelephonyHandle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);    if (ReynardCoreTelephonyHandle) {
        // since iOS 7
        CFTypeRef (*connectionCreateOnTargetQueue)(CFAllocatorRef, NSString *, dispatch_queue_t, void*) =
            dlsym(ReynardCoreTelephonyHandle, "_CTServerConnectionCreateOnTargetQueue");
        // since iOS 7
        int (*changeCellularPolicy)(CFTypeRef, NSString *, NSDictionary *) =
            dlsym(ReynardCoreTelephonyHandle, "_CTServerConnectionSetCellularUsagePolicy");
        if (!connectionCreateOnTargetQueue || !changeCellularPolicy) {
            ReynardAuthLog(@"dlsym _CTServerConnection* 失败");
            return;
        }

        CFTypeRef connection = connectionCreateOnTargetQueue(kCFAllocatorDefault, @"com.apple.Preferences",
                                                             dispatch_get_main_queue(), NULL);

        /* 此方法无法直接修改 app 的蜂窝权限，目的是让系统更新一次蜂窝权限数据。
         传入的 bundle id 必须用字面量语法创建（ZIK 实测：动态字符串不触发，原因未知）。 */
        int rc = changeCellularPolicy(connection, ReynardCellularAuthAppBundleIdentifier,
                                      @{@"kCTCellularUsagePolicyDataAllowed": @YES});
        ReynardAuthLog(@"SetCellularUsagePolicy 已调用 rc=%d", rc);
    } else {
        ReynardAuthLog(@"dlopen CoreTelephony 失败");
    }

    /* Soulghost 根治（iOS 13.5b3 以前有效）：设置 App 自己的写入器，直接把本包
     policy 写成允许。需 com.apple.CommCenter.fine-grained ent（已签）。
     真机实测：1,1→2,2 当场生效，无需杀守护/重启，随后即通。
     类在本进程预加载即有（preloaded），无需 dlopen。 */
    Class policyCacheClass = NSClassFromString(@"PSAppDataUsagePolicyCache");
    if (policyCacheClass && [(id)policyCacheClass respondsToSelector:NSSelectorFromString(@"sharedInstance")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id policyCache = [policyCacheClass performSelector:NSSelectorFromString(@"sharedInstance")];
#pragma clang diagnostic pop
        SEL setterSEL = NSSelectorFromString(@"setUsagePoliciesForBundle:cellular:wifi:");
        if (policyCache && [policyCache respondsToSelector:setterSEL]) {
            void (*setter)(id, SEL, NSString *, BOOL, BOOL) =
                (void (*)(id, SEL, NSString *, BOOL, BOOL))objc_msgSend;
            setter(policyCache, setterSEL, ReynardCellularAuthAppBundleIdentifier, YES, YES);
            ReynardAuthLog(@"PSAppDataUsagePolicyCache 自写 policy 已调用（bundle=%@）",
                           ReynardCellularAuthAppBundleIdentifier);
        } else {
            ReynardAuthLog(@"PSAppDataUsagePolicyCache 无写入 selector，跳过自修");
        }
    } else {
        ReynardAuthLog(@"PSAppDataUsagePolicyCache 类不可用，跳过自修");
    }

    ReynardFTServicesHandle = dlopen("/System/Library/PrivateFrameworks/FTServices.framework/FTServices", RTLD_LAZY);
    if (!ReynardFTServicesHandle) {
        ReynardAuthLog(@"dlopen FTServices 失败");
        [self requestFinish];
        return;
    }
    // since iOS 5
    Class NetworkSupport = NSClassFromString(@"FTNetworkSupport");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
    if (![(id)NetworkSupport respondsToSelector:sharedInstanceSelector]) {
        [self requestFinish];
        ReynardAuthLog(@"FTNetworkSupport 无 sharedInstance，请求授权失败");
        return;
    }
    id networkSupport = [NetworkSupport performSelector:sharedInstanceSelector];

    // since iOS 6
    SEL requestAuthSelector = NSSelectorFromString(@"dataActiveAndReachable");
    if (![networkSupport respondsToSelector:requestAuthSelector]) {
        [self requestFinish];
        ReynardAuthLog(@"FTNetworkSupport 无 dataActiveAndReachable，请求授权失败");
        return;
    }
    /* 第一次请求会弹"允许xxx使用数据？"；之前已请求过则不弹。
     仍可能不弹，需配合上面的 SetCellularUsagePolicy（ZIK 原话）。 */
    BOOL reachable = (BOOL)[networkSupport performSelector:requestAuthSelector];
    ReynardAuthLog(@"dataActiveAndReachable 已调用返回 %d（注意：此方法内有异步操作）", reachable);
#pragma clang diagnostic pop

    ReynardCellularDataHandle = [[CTCellularData alloc] init];
    ReynardAuthLog(@"初始 restrictedState=%ld", (long)ReynardCellularDataHandle.restrictedState);
    ReynardCellularDataHandle.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
        ReynardAuthLog(@"cellularDataRestrictionDidUpdateNotifier state=%ld", (long)state);
        if (state == kCTCellularDataNotRestricted) {
            [self requestFinish];
        }
    };

    [self setAppFixed:YES];
}

+ (void)requestFinish {
    if (ReynardCoreTelephonyHandle) {
        dlclose(ReynardCoreTelephonyHandle);
        ReynardCoreTelephonyHandle = NULL;
    }
    if (ReynardFTServicesHandle) {
        dlclose(ReynardFTServicesHandle);
        ReynardFTServicesHandle = NULL;
    }
    ReynardCellularDataHandle.cellularDataRestrictionDidUpdateNotifier = nil;
    ReynardCellularDataHandle = nil;
    ReynardAuthLog(@"requestFinish，handles 已释放");
}

+ (BOOL)deviceNeedFix {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) {
        ReynardAuthLog(@"设备不是 iPhone，无需修复");
        return NO;
    }
    float systemVersion = [UIDevice currentDevice].systemVersion.floatValue;
    if (systemVersion < 12.0 || systemVersion >= 13.0) {
        ReynardAuthLog(@"系统版本 %f 不是 iOS 12，无需修复", systemVersion);
        return NO;
    }
    void *AAHandle = dlopen("/System/Library/PrivateFrameworks/AppleAccount.framework/AppleAccount", RTLD_LAZY);
    if (!AAHandle) {
        ReynardAuthLog(@"dlopen AppleAccount 失败");
        return NO;
    }
    // since iOS 5
    Class deviceInfo = NSClassFromString(@"AADeviceInfo");
    if (!deviceInfo) {
        dlclose(AAHandle);
        return NO;
    }
    id device = [[deviceInfo alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // since iOS 6
    SEL regionSelector = NSSelectorFromString(@"regionCode");
    if (![device respondsToSelector:regionSelector]) {
        dlclose(AAHandle);
        return NO;
    }
    NSString *code = [device performSelector:regionSelector];
    // since iOS 8
    SEL hasCellularSelector = NSSelectorFromString(@"hasCellularCapability");
    BOOL hasCellular = NO;
    if ([device respondsToSelector:hasCellularSelector]) {
        hasCellular = (BOOL)[device performSelector:hasCellularSelector];
    }
#pragma clang diagnostic pop

    dlclose(AAHandle);
    ReynardAuthLog(@"regionCode=%@ hasCellular=%d", code, hasCellular);
    if ([code isEqualToString:@"CH"] && hasCellular) {
        return YES;
    }
    return NO;
}

+ (BOOL)isDeviceChineseLanguage {
    NSString *localeLanguageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    BOOL zh = [localeLanguageCode isEqualToString:@"zh"];
    ReynardAuthLog(@"localeLanguageCode=%@ isChinese=%d", localeLanguageCode, zh);
    return zh;
}

+ (BOOL)appFixed {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSNumber *fixed = [userDefault objectForKey:ReynardCellularAuthFixedKey];
    return fixed.boolValue;
}

+ (void)setAppFixed:(BOOL)fixed {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setObject:@(fixed) forKey:ReynardCellularAuthFixedKey];
    [userDefault synchronize];
}

@end
