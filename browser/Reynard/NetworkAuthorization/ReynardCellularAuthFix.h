//
//  ReynardCellularAuthFix.h
//  Reynard (iOS 12 port)
//
//  Full port of Zuikyo/ZIKCellularAuthorization (MIT) for the iOS 12
//  "first launch never shows the wireless-data prompt" problem.
//  Adaptations vs upstream:
//    - No string obfuscation: jailbreak sideload, no App Store review.
//    - Gate is iOS 12 (not iOS 10) + iPhone + CH region + cellular capability.
//    - Every step logs to /tmp/zikfix.log (fflush per line) for on-device verification.
//    - AppBundleIdentifier literal must match the built bundle id (ZIK's
//      literal-NSString requirement for _CTServerConnectionSetCellularUsagePolicy).
//

#import <Foundation/Foundation.h>

/// app 的 bundle id，必须用字面量语法赋值，且必须与本次构建的 bundle id 一致
/// （传 [NSBundle mainBundle].bundleIdentifier 这类动态字符串不会触发系统更新，原因未知 —— ZIK 实测结论）
static NSString *const ReynardCellularAuthAppBundleIdentifier = @"reynard.bemly.moe.zik1";

@interface ReynardCellularAuthFix : NSObject

/**
 在 app 启动时调用（iOS 12 走 main.swift 的 didFinishLaunching 观察者）。
 1. 之前已请求过权限/权限已确定 → 此方法没有效果（系统不重弹是 iOS 铁律）
 2. 非 iPhone / 非 iOS 12 / 非国行 / 无蜂窝功能 → 此方法没有效果
 3. 修复只执行一次（NSUserDefaults 标记；换 bundle id 即新域，自动重置）
 */
+ (void)requestCellularAuthorization;

/// 设备是否是中文语言（ZIK Demo 只对中文设备执行修复；本机是中文，直接过）
+ (BOOL)isDeviceChineseLanguage;

/// 设备是否需要修复（iPhone + iOS 12 + 国行 + 蜂窝功能）
+ (BOOL)deviceNeedFix;

/// app 是否已执行过修复
+ (BOOL)appFixed;

@end
