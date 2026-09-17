//
//  ReynardNetworkAccessibility.m
//  Reynard (iOS 12 port)
//
//  Port of ziecho/ZYNetworkAccessibility. Judgment logic is upstream's:
//  reachable -> Accessible; else CT restricted + real link type (WiFi/cellular)
//  -> Restricted, else Unknown (airplane etc).
//  NOTE: upstream's CaptiveNetwork import is dropped (unused in upstream .m;
//  the WiFi check uses en0 via getifaddrs, which needs no permission).
//

#import "ReynardNetworkAccessibility.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCellularData.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

NSString * const ReynardNetworkAccessibilityChangedNotification = @"ReynardNetworkAccessibilityChangedNotification";

typedef NS_ENUM(NSInteger, ReynardNetworkType) {
    ReynardNetworkTypeUnknown ,
    ReynardNetworkTypeOffline ,
    ReynardNetworkTypeWiFi    ,
    ReynardNetworkTypeCellularData ,
};

static void ReynardNetAuthLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"ReynardNetworkAccessibility: %@", msg);
    FILE *f = fopen("/tmp/zyauth.log", "a");
    if (f) {
        fprintf(f, "ReynardNetworkAccessibility: %s\n", [msg UTF8String]);
        fflush(f);
        fclose(f);
    }
}

@interface ReynardNetworkAccessibility(){
    SCNetworkReachabilityRef _reachabilityRef;
    CTCellularData *_cellularData;
    NSMutableArray *_becomeActiveCallbacks;
    ReynardNetworkAccessibleState _previousState;
    UIAlertController *_alertController;
    BOOL _automaticallyAlert;
    ReynardNetworkAccessibleStateNotifier _networkAccessibleStateDidUpdateNotifier;
    BOOL _checkActiveLaterWhenDidBecomeActive;
    BOOL _checkingActiveLater;
}

@end

@interface ReynardNetworkAccessibility()
@end


@implementation ReynardNetworkAccessibility


#pragma mark - Public

+ (void)start {
    ReynardNetAuthLog(@"start");
    [[self sharedInstance] setupNetworkAccessibility];
}

+ (void)stop {
    [[self sharedInstance] cleanNetworkAccessibility];
}

+ (void)setAlertEnable:(BOOL)setAlertEnable {
    ReynardNetAuthLog(@"setAlertEnable=%d", setAlertEnable);
    [self sharedInstance]->_automaticallyAlert = setAlertEnable;
}


+ (void)setStateDidUpdateNotifier:(void (^)(ReynardNetworkAccessibleState))block {
    [[self sharedInstance] monitorNetworkAccessibleStateWithCompletionBlock:block];
}

+ (ReynardNetworkAccessibleState)currentState {
    return [[self sharedInstance] currentState];
}

#pragma mark - Public entity method


+ (ReynardNetworkAccessibility *)sharedInstance {
    static ReynardNetworkAccessibility * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}


- (void)setNetworkAccessibleStateDidUpdateNotifier:(ReynardNetworkAccessibleStateNotifier)networkAccessibleStateDidUpdateNotifier {
    _networkAccessibleStateDidUpdateNotifier = [networkAccessibleStateDidUpdateNotifier copy];
    [self startCheck];
}



- (void)monitorNetworkAccessibleStateWithCompletionBlock:(void (^)(ReynardNetworkAccessibleState))block {
    _networkAccessibleStateDidUpdateNotifier = [block copy];
}

- (ReynardNetworkAccessibleState)currentState {
    return _previousState;
}

#pragma mark - Life cycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    if (self = [super init]) {

    }
    return self;
}

#pragma mark - NSNotification

- (void)setupNetworkAccessibility {

    if (_reachabilityRef || _cellularData) {
        ReynardNetAuthLog(@"已在运行，跳过");
        return;
    }


    if ([UIDevice currentDevice].systemVersion.floatValue < 10.0 || [self isSimulator]) {
        // * iOS 10 以下或者是模拟器不够用检测默认通过
        [self notiWithAccessibleState:ReynardNetworkAccessible];
        return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

    _reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, "223.5.5.5");
    // 上游注释：此句会触发系统弹出权限询问框（待验）
    SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);


    _becomeActiveCallbacks = [NSMutableArray array];

    BOOL firstRun = ({
        static NSString * RUN_FLAG = @"ReynardNetworkAccessibilityRunFlag";
        BOOL value = [[NSUserDefaults standardUserDefaults] boolForKey:RUN_FLAG];
        if (!value) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:RUN_FLAG];
        }
        !value;
    });
    ReynardNetAuthLog(@"firstRun=%d", firstRun);

    dispatch_block_t startNotifier = ^{
        [self startReachabilityNotifier];

        [self startCellularDataNotifier];
    };

    if (firstRun) {
        // 第一次运行系统会弹框，需要延迟一下在判断，否则会拿到不准确的结果
        // 表现为：ReachabilityNotifier 有一定概率拿到的结果是可以访问, CellularDataNotifier 拿到的是拒绝
        // 这里延时 3 秒再检测是因为某些情况下，弹框存在较长的延时。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self waitActive:^{
                startNotifier();
            }];
        });
    } else {
        startNotifier();
    }


}

- (void)cleanNetworkAccessibility {

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _cellularData.cellularDataRestrictionDidUpdateNotifier = nil;
    _cellularData = nil;

    SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    _reachabilityRef = nil;

    [self cancelEnsureActive];
    [self hideNetworkRestrictedAlert];

    [_becomeActiveCallbacks removeAllObjects];
    _becomeActiveCallbacks = nil;

    _previousState = ReynardNetworkChecking;

    _checkActiveLaterWhenDidBecomeActive = NO;
    _checkingActiveLater = NO;

}


- (void)applicationWillResignActive {
    [self hideNetworkRestrictedAlert];

    if (_checkingActiveLater) {
        [self cancelEnsureActive];
        _checkActiveLaterWhenDidBecomeActive = YES;
    }
}

- (void)applicationDidBecomeActive {

    if (_checkActiveLaterWhenDidBecomeActive) {
        [self checkActiveLater];
        _checkActiveLaterWhenDidBecomeActive = NO;
    }
}


#pragma mark - Active Checker

// 如果当前 app 是非可响应状态（一般是启动的时候），则等到 app 激活且保持一秒以上，再回调
// 因为启动完成后，2 秒内可能会再次弹出「是否允许 XXX 使用网络」，此时的 applicationState 是 UIApplicationStateInactive）

- (void)waitActive:(dispatch_block_t)block {
    [_becomeActiveCallbacks addObject:[block copy]];
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
       _checkActiveLaterWhenDidBecomeActive = YES;
    } else {
        [self checkActiveLater];
    }
}

- (void)checkActiveLater {
    _checkingActiveLater = YES;
    [self performSelector:@selector(ensureActive) withObject:nil afterDelay:2 inModes:@[NSRunLoopCommonModes]];
}

- (void)ensureActive {
    _checkingActiveLater = NO;
    for (dispatch_block_t block in _becomeActiveCallbacks) {
        block();
    }
    [_becomeActiveCallbacks removeAllObjects];
}

- (void)cancelEnsureActive {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ensureActive) object:nil];
}


#pragma mark - Reachability

static void ReynardReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    ReynardNetworkAccessibility *networkAccessibility = (__bridge ReynardNetworkAccessibility *)info;
    if (![networkAccessibility isKindOfClass: [ReynardNetworkAccessibility class]]) {
        return;
    }
    ReynardNetAuthLog(@"reachability 回调 flags=0x%x", flags);
    [networkAccessibility startCheck];
}

// 监听用户从 Wi-Fi 切换到 蜂窝数据，或者从蜂窝数据切换到 Wi-Fi，另外当从授权到未授权，或者未授权到授权也会调用该方法
- (void)startReachabilityNotifier {
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReynardReachabilityCallback, &context)) {
        SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}

- (void)startCellularDataNotifier {
    __weak __typeof(self)weakSelf = self;
    self->_cellularData = [[CTCellularData alloc] init];
    self->_cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
        ReynardNetAuthLog(@"CT 回调 state=%ld", (long)state);
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startCheck];
        });
    };
}

- (BOOL)currentReachable {
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(self->_reachabilityRef, &flags)) {
        ReynardNetAuthLog(@"GetFlags flags=0x%x", flags);
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
            return NO;
        } else {
            return YES;
        }
    }
    return NO;
}


#pragma mark - Check Accessibility

- (void)startCheck {

    if ([self currentReachable]) {
        /* 先用 currentReachable 判断，若返回的为 YES 则说明：
         1. 用户选择了 「WLAN 与蜂窝移动网」并处于其中一种网络环境下。
         2. 用户选择了 「WLAN」并处于 WLAN 网络环境下。

         此时是有网络访问权限的，直接返回 Accessible
         **/
        return [self notiWithAccessibleState:ReynardNetworkAccessible];
    }

    CTCellularDataRestrictedState state = _cellularData.restrictedState;
    ReynardNetAuthLog(@"startCheck: 不可达，CT state=%ld", (long)state);

    switch (state) {
        case kCTCellularDataRestricted: {// 系统 API 返回 无蜂窝数据访问权限

            [self getCurrentNetworkType:^(ReynardNetworkType type) {
                /*  若用户是通过蜂窝数据 或 WLAN 上网，走到这里来 说明权限被关闭**/

                if (type == ReynardNetworkTypeCellularData || type == ReynardNetworkTypeWiFi) {
                    [self notiWithAccessibleState:ReynardNetworkRestricted];
                } else {  // 可能开了飞行模式，无法判断
                    [self notiWithAccessibleState:ReynardNetworkUnknown];
                }
            }];

            break;
        }
        case kCTCellularDataNotRestricted: // 系统 API 访问有有蜂窝数据访问权限，那就必定有 Wi-Fi 数据访问权限
            [self notiWithAccessibleState:ReynardNetworkAccessible];
            break;
        case kCTCellularDataRestrictedStateUnknown: {
            // CTCellularData 刚开始初始化的时候，可能会拿到 kCTCellularDataRestrictedStateUnknown 延迟一下再试就好了
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self startCheck];
            });
            break;
        }
        default:
            break;
    };
}


- (void)getCurrentNetworkType:(void(^)(ReynardNetworkType))block {
    if ([self isWiFiEnable]) {
        return block(ReynardNetworkTypeWiFi);
    }
    ReynardNetworkType type = [self getNetworkTypeFromStatusBar];
    if (type == ReynardNetworkTypeWiFi) { // 这时候从状态栏拿到的是 Wi-Fi 说明状态栏没有刷新，延迟一会再获取
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self getCurrentNetworkType:block];
        });
    } else {
        block(type);
    }
}

- (ReynardNetworkType)getNetworkTypeFromStatusBar {
    NSInteger type = 0;
    @try {
        UIView *statusBar = nil;
        if (@available(iOS 13.0, *)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            UIStatusBarManager *statusBarManager = UIApplication.sharedApplication.keyWindow.windowScene.statusBarManager;
            if ([statusBarManager respondsToSelector:@selector(createLocalStatusBar)]) {
                UIView *_localStatusBar = [statusBarManager performSelector:@selector(createLocalStatusBar)];
                if ([_localStatusBar respondsToSelector:@selector(statusBar)]) {
                    statusBar = [_localStatusBar performSelector:@selector(statusBar)];
                }
            }
#pragma clang diagnostic pop

        } else {
            statusBar = [UIApplication.sharedApplication valueForKey:@"statusBar"];
        }
        if (statusBar == nil ){
            return ReynardNetworkTypeUnknown;
        }

        BOOL isModernStatusBar = [statusBar isKindOfClass:NSClassFromString(@"UIStatusBar_Modern")];

        if (isModernStatusBar) { // 在 iPhone X 上 statusBar 属于 UIStatusBar_Modern ，需要特殊处理
            id currentData = [statusBar valueForKeyPath:@"statusBar.currentData"];
            BOOL wifiEnable = [[currentData valueForKeyPath:@"_wifiEntry.isEnabled"] boolValue];

            // 这里不能用 _cellularEntry.isEnabled 来判断，该值即使关闭仍然有是 YES

            BOOL cellularEnable = [[currentData valueForKeyPath:@"_cellularEntry.type"] boolValue];
            return  wifiEnable     ? ReynardNetworkTypeWiFi :
                    cellularEnable ? ReynardNetworkTypeCellularData : ReynardNetworkTypeOffline;
        } else { // 传统的 statusBar
            NSArray *children = [[statusBar valueForKeyPath:@"foregroundView"] subviews];
            for (id child in children) {
                if ([child isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
                    type = [[child valueForKeyPath:@"dataNetworkType"] intValue];
                    // type == 1  => 2G
                    // type == 2  => 3G
                    // type == 3  => 4G
                    // type == 4  => LTE
                    // type == 5  => Wi-Fi
                }
            }
            return type == 0 ? ReynardNetworkTypeOffline :
                   type == 5 ? ReynardNetworkTypeWiFi    : ReynardNetworkTypeCellularData;
        }
    } @catch (NSException *exception) {

    }
    return 0;
}


/**
 判断用户是否连接到 Wi-Fi（en0 有 IPv4 即连着；被拒态下照样可读，不走被禁 socket）
 */
- (BOOL)isWiFiEnable {
    return [self wiFiIPAddress].length > 0;
}

- (NSString *)wiFiIPAddress {
    @try {
        NSString *ipAddress;
        struct ifaddrs *interfaces;
        struct ifaddrs *temp;
        int Status = 0;
        Status = getifaddrs(&interfaces);
        if (Status == 0) {
            temp = interfaces;
            while(temp != NULL) {
                if(temp->ifa_addr->sa_family == AF_INET) {
                    if([[NSString stringWithUTF8String:temp->ifa_name] isEqualToString:@"en0"]) {
                        ipAddress = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp->ifa_addr)->sin_addr)];
                    }
                }
                temp = temp->ifa_next;
            }
        }

        freeifaddrs(interfaces);

        if (ipAddress == nil || ipAddress.length <= 0) {
            return nil;
        }
        return ipAddress;
    }
    @catch (NSException *exception) {
        return nil;
    }
}

- (BOOL)isSimulator {
#if TARGET_OS_SIMULATOR
    BOOL isSimulator = YES;
#else
    BOOL isSimulator = NO;
#endif
    return isSimulator;
}

#pragma mark - Callback

- (void)notiWithAccessibleState:(ReynardNetworkAccessibleState)state {
    ReynardNetAuthLog(@"判定 state=%lu (0=检测中 1=未知 2=可达 3=被拒)", (unsigned long)state);
    if (_automaticallyAlert) {
        if (state == ReynardNetworkRestricted) {
                [self showNetworkRestrictedAlert];
        } else {
            [self hideNetworkRestrictedAlert];
        }
    }

    if (state != _previousState) {
        _previousState = state;

        if (_networkAccessibleStateDidUpdateNotifier) {
            _networkAccessibleStateDidUpdateNotifier(state);
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:ReynardNetworkAccessibilityChangedNotification object:nil];

    }
}


- (void)showNetworkRestrictedAlert {
    if (self.alertController.presentingViewController == nil && ![self.alertController isBeingPresented]) {
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:self.alertController animated:YES completion:nil];
    }
}

- (void)hideNetworkRestrictedAlert {
    [_alertController dismissViewControllerAnimated:YES completion:nil];
}

- (UIAlertController *)alertController {
    if (!_alertController) {

        // 文案按本机实情改写：本 App 的系统设置页没有无线数据开关，不承诺跳设置能开
        _alertController = [UIAlertController alertControllerWithTitle:@"网络连接失败" message:@"检测到本机按 App 关了本应用的网络（且系统设置里没有本应用的无线数据开关，需装机时放行一次）。" preferredStyle:UIAlertControllerStyleAlert];

        [_alertController addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self hideNetworkRestrictedAlert];
        }]];

        [_alertController addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
                [[UIApplication sharedApplication] openURL:settingsURL];
            }
        }]];
    }
    return _alertController;
}



@end
