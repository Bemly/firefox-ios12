//
//  JITEnabler.m
//  Reynard
//
//  Created by Minh Ton on 11/3/26.
//

#import "JITEnabler.h"
#import "JITErrors.h"
#import "JITSupport.h"
#import "JITUtils.h"
#import "Utils.h"
#include <sys/stat.h>
#include <errno.h>

@interface JITEnabler ()

@property(nonatomic, assign) DeviceProvider *sharedProvider;
@property(nonatomic, strong) dispatch_queue_t providerQueue;
@property(nonatomic, assign) BOOL didEnsureDDIMounted;
@property(nonatomic, copy) NSString *jitHelper;

- (DeviceProvider *)getProvider:(NSError **)error;
- (void)resolveJITHelper;

@end

@implementation JITEnabler

+ (JITEnabler *)shared {
    static JITEnabler *sharedEnabler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEnabler = [[self alloc] init];
    });
    return sharedEnabler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sharedProvider = NULL;
        _providerQueue = dispatch_queue_create("com.minh-ton.Reynard.JITEnabler.ProviderQueue", DISPATCH_QUEUE_SERIAL);
        _didEnsureDDIMounted = NO;
        [self resolveJITHelper];
    }
    return self;
}

- (void)resolveJITHelper {
    NSBundle *bundle = NSBundle.mainBundle;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSArray<NSString *> *helperNames = @[@"ts_ptrace_jit", @"jb_ptrace_jit"];
    NSString *helperName = helperNames.firstObject;
    NSString *helperPath = [bundle.bundlePath stringByAppendingPathComponent:helperName];
    
    for (NSString *candidateName in helperNames) {
        NSString *bundleCandidate = [bundle.bundlePath stringByAppendingPathComponent:candidateName];
        if ([fileManager fileExistsAtPath:bundleCandidate]) {
            helperName = candidateName;
            helperPath = bundleCandidate;
            break;
        }
        
        NSString *resourceCandidate = [bundle.resourcePath stringByAppendingPathComponent:candidateName];
        if ([fileManager fileExistsAtPath:resourceCandidate]) {
            helperName = candidateName;
            helperPath = resourceCandidate;
            break;
        }
        
        NSURL *auxURL = [bundle URLForAuxiliaryExecutable:candidateName];
        if (auxURL.path.length > 0 && [fileManager fileExistsAtPath:auxURL.path]) {
            helperName = candidateName;
            helperPath = auxURL.path;
            break;
        }
    }
    
    self.jitHelper = helperPath;
}

- (BOOL)enableJITForPID:(int32_t)pid hasTXMSupport:(BOOL)hasTXMSupport error:(NSError **)error {
    // TrollStore or jailbroken devices
    if (getEntitlementValue(@"com.apple.private.security.no-sandbox")) {
        NSString *jitHelper = self.jitHelper;
        NSString *helperName = jitHelper.lastPathComponent;
        NSFileManager *fileManager = NSFileManager.defaultManager;
        
        int result = spawnRoot(jitHelper, @[[NSString stringWithFormat:@"%d", pid]]);
        logger([NSString stringWithFormat:@"%@ result %d", helperName, result]);
        
        if (result != 0 && result != EACCES && result != ENOENT && result != ENOEXEC && result != 126 && result != 127) {
            // keep existing behavior for non-permission failures
        } else if (result == EACCES || result == ENOENT || result == ENOEXEC || result == 126 || result == 127) {
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:helperName];
            NSError *copyError = nil;
            [fileManager removeItemAtPath:tempPath error:nil];
            if ([fileManager copyItemAtPath:jitHelper toPath:tempPath error:&copyError]) {
                chmod(tempPath.UTF8String, 0755);
                if ([fileManager isExecutableFileAtPath:tempPath]) {
                    logger([NSString stringWithFormat:@"Retrying %@ from temp path %@", helperName, tempPath]);
                    result = spawnRoot(tempPath, @[[NSString stringWithFormat:@"%d", pid]]);
                }
            } else {
                logger([NSString stringWithFormat:@"Failed to copy %@ to temp path: %@", helperName, copyError.localizedDescription ?: @"unknown"]);
            }
        }
        if (result >= 128) {
            if (error) *error = MakeError(TSPtraceHelperTerminated);
            return NO;
        }
        
        if (result != 0) {
            if (error) *error = MakeError(TSPtraceHelperAttachFailed);
            return NO;
        }
        
        return YES;
    }
    
    if (@available(iOS 17.4, *)) {
        // For iOS 17.4 and later
        // Thanks StikDebug!
        // https://github.com/StephenDev0/StikDebug
        
        DeviceProvider *provider = [self getProvider:error];
        if (!provider) return NO;
        
        DebugSession session = {0};
        IdeviceFfiError *ffiError = NULL;
        
        if (!connectDebugSession(provider, &session, @"10.7.0.1", error)) return NO;
        
        ProcessControlHandle *processControl = NULL;
        ffiError = process_control_new(session.remoteServer, &processControl);
        if (ffiError) {
            if (error) *error = MakeError(ProcessControlCreateFailed);
            idevice_error_free(ffiError);
            freeDebugSession(&session);
            return NO;
        }
        
        ffiError = process_control_disable_memory_limit(processControl, (uint64_t)pid);
        process_control_free(processControl);
        if (ffiError) {
            logger([NSString stringWithFormat:@"disable_memory_limit failed for pid %d: %s", pid, ffiError->message ?: "unknown error"]);
            idevice_error_free(ffiError);
        }
        
        NSError *commandError = nil;
        NSString *noAckResponse = nil;
        if (!configureNoAckMode(session.debugProxy, &noAckResponse, &commandError)) {
            if (error) *error = commandError ?: MakeError(NoAckConfigureFailed);
            freeDebugSession(&session);
            return NO;
        }
        
        logger([NSString stringWithFormat:@"QStartNoAckMode result for pid %d: %@", pid, noAckResponse ?: @"<no response>"]);
        
        NSString *attachCommand = [NSString stringWithFormat:@"vAttach;%X", pid];
        NSString *attachResponse = nil;
        if (!sendDebugCommand(session.debugProxy, attachCommand, &attachResponse, &commandError)) {
            if (error) *error = commandError ?: MakeError(AttachDebugProxyFailed);
            freeDebugSession(&session);
            return NO;
        }
        
        logger([NSString stringWithFormat:@"Attach response for pid %d: %@", pid, attachResponse.length > 0 ? @"<stop packet>" : @"<no response>"]);
        
        if (hasTXMSupport) {
            registerJITEndpointForPID(pid, @"10.7.0.1", 49152);
            
            DebugSession *persistentSession = malloc(sizeof(*persistentSession));
            if (!persistentSession) {
                freeDebugSession(&session);
                if (error) *error = MakeError(SessionAllocationFailed);
                return NO;
            }
            
            *persistentSession = session;
            session.adapter = NULL;
            session.handshake = NULL;
            session.remoteServer = NULL;
            session.debugProxy = NULL;
            
            // TXM iOS 26+ workaround
            dispatch_async(debugServiceQueue(), ^{
                runDebugService(pid, persistentSession);
            });
            
            logger([NSString stringWithFormat:@"Debug session started for pid %d", pid]);
        } else {
            // detach immediately
            detachDebuggerSession(session.debugProxy, pid);
            freeDebugSession(&session);
        }
        
        return YES;
    }
    
    return NO;
}

- (void)detachAllJITSessions {
    resetJITEndpointMonitor();
    dispatch_sync(debugSessionStateQueue(), ^{
        NSMutableSet<NSNumber *> *active = activeDebugSessionPIDs();
        NSMutableSet<NSNumber *> *detachRequested = detachRequestedDebugSessionPIDs();
        [detachRequested unionSet:active];
    });
}

- (DeviceProvider *)getProvider:(NSError **)error {
    __block DeviceProvider *provider = NULL;
    __block NSError *providerError = nil;
    
    dispatch_sync(self.providerQueue, ^{
        if (!self.sharedProvider) {
            self.sharedProvider = createDeviceProvider(pairingFilePath(), @"10.7.0.1", &providerError);
            self.didEnsureDDIMounted = NO;
        }
        
        if (self.sharedProvider && !self.didEnsureDDIMounted) {
            if (!ensureDDIMounted(self.sharedProvider, &providerError)) {
                provider = NULL;
                return;
            }
            self.didEnsureDDIMounted = YES;
        }
        
        provider = self.sharedProvider;
    });
    
    if (!provider && error) *error = providerError;
    return provider;
}

- (void)dealloc {
    resetJITEndpointMonitor();
    if (_sharedProvider) {
        freeDeviceProvider(_sharedProvider);
        _sharedProvider = NULL;
    }
}

@end
