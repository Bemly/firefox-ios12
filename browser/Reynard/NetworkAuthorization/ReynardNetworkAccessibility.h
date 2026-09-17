//
//  ReynardNetworkAccessibility.h
//  Reynard (iOS 12 port)
//
//  Port of ziecho/ZYNetworkAccessibility (detection + guidance layer).
//  100% public APIs: SCNetworkReachability + CTCellularData + en0 IP +
//  status-bar network type. No private API, no App Store risk.
//  Adaptations vs upstream:
//    - Alert copy is honest about THIS app: our Settings page has no
//      wireless-data row, so the message doesn't promise one.
//    - Every state transition logs to /tmp/zyauth.log (fflush per line).
//

#import <Foundation/Foundation.h>

extern NSString * const ReynardNetworkAccessibilityChangedNotification;

typedef NS_ENUM(NSUInteger, ReynardNetworkAccessibleState) {
    ReynardNetworkChecking  = 0,
    ReynardNetworkUnknown     ,
    ReynardNetworkAccessible  ,
    ReynardNetworkRestricted  ,
};

typedef void (^ReynardNetworkAccessibleStateNotifier)(ReynardNetworkAccessibleState state);

@interface ReynardNetworkAccessibility : NSObject

/// 开启检测（主线程调用；内部挂 runloop + 通知）
+ (void)start;

/// 停止检测
+ (void)stop;

/// 当判为 Restricted 时自动弹提示框
+ (void)setAlertEnable:(BOOL)setAlertEnable;

/// block 方式监听权限变化
+ (void)setStateDidUpdateNotifier:(void (^)(ReynardNetworkAccessibleState))block;

/// 最近一次检测结果
+ (ReynardNetworkAccessibleState)currentState;

@end
