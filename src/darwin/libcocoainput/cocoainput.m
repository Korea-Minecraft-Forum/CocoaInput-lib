//
//  cocoainput.m
//  libcocoainput
//
//  Created by Axer on 2019/03/23.
//  Copyright © 2019年 Axer. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "cocoainput.h"
#import "DataManager.h"

void replaceInstanceMethod(Class cls, SEL sel, SEL renamedSel, Class dataCls) {
    Method addMethod = class_getInstanceMethod(cls, sel);
    IMP addImp = method_getImplementation(addMethod);
    const char* addEncoding = method_getTypeEncoding(addMethod);
    BOOL addResult = class_addMethod(cls, renamedSel, addImp, addEncoding);
    if (!addResult) {
        CIDebug([NSString stringWithFormat:@"AddMethod Failed:\"%@\"", NSStringFromSelector(renamedSel)]);
    }

    Method replaceMethod = class_getInstanceMethod(dataCls, sel);
    IMP replaceImp = method_getImplementation(replaceMethod);
    const char* replaceEncoding = method_getTypeEncoding(replaceMethod);
    class_replaceMethod(cls, sel, replaceImp, replaceEncoding);
}

void initialize(LogFunction log,LogFunction error,LogFunction debug){
    initLogPointer(log, error, debug);
    CILog([NSString stringWithFormat:@"Libcocoainput was built on %s %s.", __DATE__, __TIME__]);
    CILog(@"CocoaInput is being initialized.Now running thread for modify GLFWview .");
    NSThread *thread=[[NSThread alloc]initWithTarget:[DataManager sharedManager] selector:@selector(modifyGLFWView) object:nil];
    [thread start];
}

void addInstance(
    const char* uuid,
    void (*insertText_p)(const char*, const int, const int),
    void (*setMarkedText_p)(const char*, const int, const int, const int, const int),
    void (*firstRectForCharacterRange_p)(const float*)
) {
    CIDebug([NSString stringWithFormat:@"New textfield %s has registered.", uuid]);
    MinecraftView* mc = [[MinecraftView alloc] init];
    mc.insertText = insertText_p;
    mc.setMarkedText = setMarkedText_p;
    mc.firstRectForCharacterRange = firstRectForCharacterRange_p;
    [[[DataManager sharedManager] dic]
     setObject:mc
     forKey:[[NSString alloc] initWithCString:uuid
                                     encoding:NSUTF8StringEncoding]];
}

void removeInstance(const char* uuid) {
    CIDebug([NSString stringWithFormat:@"Textfield %s has been removed.", uuid]);
    [[[DataManager sharedManager] dic]
     removeObjectForKey:[[NSString alloc]
                         initWithCString:uuid
                         encoding:NSUTF8StringEncoding]];
}

void refreshInstance(void) {
    CIDebug(@"All textfields has been removed.");
    [[NSTextInputContext currentInputContext] discardMarkedText];
    [DataManager sharedManager].activeView = nil;
    [DataManager sharedManager].dic = [NSMutableDictionary dictionary];
}

void discardMarkedText(const char* uuid) {
    CIDebug(@"Active marked text has been discarded.");
}

void setIfReceiveEvent(const char* uuid, int yn) {
    CIDebug([NSString stringWithFormat:@"Textfield %s's flag has changed to %d.",
             uuid, yn]);
    if (yn == 1) {
        [DataManager sharedManager].activeView = [[[DataManager sharedManager] dic]
                                                  objectForKey:[[NSString alloc] initWithCString:uuid
                                                                                        encoding:NSUTF8StringEncoding]];
    } else {
        if ([DataManager sharedManager].activeView != nil &&
            [[[[DataManager sharedManager] dic]
              objectForKey:[[NSString alloc]
                            initWithCString:uuid
                            encoding:NSUTF8StringEncoding]]
             isEqual:[DataManager sharedManager].activeView])
            [DataManager sharedManager].activeView = nil;
    }
}

float invertYCoordinate(float y) {
    CIDebug(@"InvertYCoordinate function used");
    return [[NSScreen mainScreen] visibleFrame].size.height +
    [[NSScreen mainScreen] visibleFrame].origin.y - y;
}
