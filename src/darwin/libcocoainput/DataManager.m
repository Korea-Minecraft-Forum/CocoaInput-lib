//
//  DataManager.m
//  libcocoainput
//
//  Created by Axer on 2019/03/23.
//  Copyright © 2019年 Axer. All rights reserved.
//

#import "DataManager.h"
#import "cocoainput.h"
#import "Logger.h"

#define SPLIT_NSRANGE(x) (int)(x.location), (int)(x.length)

static DataManager* instance = nil;

@implementation DataManager

@synthesize hasPreeditText;
@synthesize isSentedInsertText;
@synthesize isBeforeActionSetMarkedText;

+ (instancetype)sharedManager {
    if (!instance) {
        instance = [[DataManager alloc] init];
    }
    return instance;
}

- (id)init {
    CIDebug(@"Textfield table has been initialized.");
    self = [super init];
    self.hasPreeditText=NO;
    self.dic = [NSMutableDictionary dictionary];
    self.activeView = nil;
    return self;
}

- (void) modifyGLFWView {
    NSView *view;
    while(1) {
        view = [[NSApp keyWindow] contentView];
        if ([[view className]isEqualToString:@"GLFWContentView"] == YES) {
            break;
        }
    }

    [[DataManager sharedManager] setGlfwView:view];

    Class viewClass = [view class];
    Class dataClass = [[DataManager sharedManager] class];
    replaceInstanceMethod(viewClass, @selector(keyDown:), @selector(org_keyDown:), dataClass);
    replaceInstanceMethod(viewClass, @selector(hasMarkedText), @selector(org_hasMarkedText), dataClass);
    replaceInstanceMethod(viewClass, @selector(markedRange), @selector(org_markedRange), dataClass);
    replaceInstanceMethod(viewClass, @selector(interpretKeyEvents:), @selector(org_interpretKeyEvents:), dataClass);
    replaceInstanceMethod(viewClass, @selector(insertText:replacementRange:), @selector(org_insertText:replacementRange:), dataClass);
    replaceInstanceMethod(viewClass, @selector(firstRectForCharacterRange:actualRange:), @selector(org_firstRectForCharacterRange:actualRange:), dataClass);
    replaceInstanceMethod(viewClass, @selector(setMarkedText:selectedRange:replacementRange:), @selector(org_setMarkedText:selectedRange:replacementRange:), dataClass);
    replaceInstanceMethod(viewClass, @selector(unmarkText), @selector(org_unmarkText), dataClass);

    if (@available(macOS 14.0, *)) {
        NSTextInsertionIndicator *indicator = [[NSTextInsertionIndicator alloc] init];
        indicator.frame = NSMakeRect(0, 0, 0, 0);
        indicator.displayMode = NSTextInsertionIndicatorDisplayModeHidden;
        [view addSubview: indicator];
        CIDebug(@"Initialize Sonoma Invisible Indiciator");
    }

    CIDebug([NSString stringWithFormat:@"SetView:\"%@\"", [view.class description]]);
    CILog(@"Complete to modify GLFWView");
}

- (void)keyDown:(NSEvent*)theEvent {//GLFWContentView改変用
    //見づらすぎて改修しづらい
    if ([DataManager sharedManager].activeView != nil) {
        CIDebug(@"New keyEvent came and sent to textfield.");
        [self org_interpretKeyEvents:@[ theEvent ]];
    }

    /*
    CIDebug([NSString stringWithFormat:@"keydown %d %d %d\n",
       [DataManager sharedManager].hasPreeditText,
       [DataManager sharedManager].isSentedInsertText,
       [DataManager sharedManager].isBeforeActionSetMarkedText
    ]);
    */

    if (
        [DataManager sharedManager].hasPreeditText == NO &&
        [DataManager sharedManager].isSentedInsertText == NO &&
        [DataManager sharedManager].isBeforeActionSetMarkedText == NO)
    {
        CIDebug(@"New keyEvent came and sent to original keyDown.");
        [self org_keyDown:theEvent];
    }
    [DataManager sharedManager].isSentedInsertText = NO;
    [DataManager sharedManager].isBeforeActionSetMarkedText = NO;
}

- (void)interpretKeyEvents: (NSArray*)eventArray { // GLFWContentView改変用
}

- (void)unmarkText {
    [DataManager sharedManager].isBeforeActionSetMarkedText = YES;
    [DataManager sharedManager].hasPreeditText = NO;
    [self org_unmarkText];
}

//確定文字列　（漢字変換を通さなかったものもここに入る）
- (void)insertText:(id)input replacementRange:(NSRange)replacementRange {
    if (![DataManager sharedManager].hasPreeditText) {
        [DataManager sharedManager].isSentedInsertText = NO;
        [self org_insertText:input replacementRange:replacementRange];
        return;
    }
    [DataManager sharedManager].hasPreeditText = NO;
    [DataManager sharedManager].isSentedInsertText = YES;
    /*
    const char *sentString;
    if ([input isKindOfClass:[NSAttributedString class]]) {
        sentString = [[input string] cStringUsingEncoding:NSUTF8StringEncoding];
    } else {
        sentString = [input cStringUsingEncoding:NSUTF8StringEncoding];
    }
    */

    if (@available(macOS 14.0, *)) {
        if ([[DataManager sharedManager] activeView] == nil) {
            CIDebug(@"insertText ignored by Sonoma's Tooltip");
        } else {
            [[DataManager sharedManager] activeView].insertText("", 0, 0);
            CIDebug([NSString stringWithFormat:@"MarkedText was determined:\"%@\"",input]);
        }
    } else {
        [[DataManager sharedManager] activeView].insertText("", 0, 0);
        CIDebug([NSString stringWithFormat:@"MarkedText was determined:\"%@\"",input]);
    }
    [self org_insertText:input replacementRange:replacementRange];//GLFWのオリジナルメソッドはCharEventを発行するので利用する
}

//漢字変換途中経過
- (void)setMarkedText:(id)input
        selectedRange:(NSRange)selectedRange
     replacementRange:(NSRange)replacementRange {
    [DataManager sharedManager].hasPreeditText = YES;
    const char* sentString;
    if ([input isKindOfClass:[NSAttributedString class]]) {
        sentString = [[input string] cStringUsingEncoding:NSUTF8StringEncoding];
    } else {
        sentString = [input cStringUsingEncoding:NSUTF8StringEncoding];
    }

    if (@available(macOS 14.0, *)) {
        if ([[DataManager sharedManager] activeView] == nil) {
            CIDebug(@"setMarkedText ignored by Sonoma's Tooltip");
        } else {
            CIDebug([NSString stringWithFormat:@"MarkedText changed:\"%@\"", [input description]]);
            [[DataManager sharedManager] activeView].setMarkedText(sentString, SPLIT_NSRANGE(selectedRange), SPLIT_NSRANGE(replacementRange));
        }
    } else {
        CIDebug([NSString stringWithFormat:@"MarkedText changed:\"%@\"", [input description]]);
        [[DataManager sharedManager] activeView].setMarkedText(sentString, SPLIT_NSRANGE(selectedRange), SPLIT_NSRANGE(replacementRange));
    }
    [self org_setMarkedText:input selectedRange:selectedRange replacementRange:replacementRange];
}

- (NSRect)firstRectForCharacterRange:(NSRange)aRange
                         actualRange:(NSRangePointer)actualRange {
    // Check for Sonoma IME tooltip
    if (@available(macOS 14.0, *)) {
        if ([[DataManager sharedManager] activeView] == nil) {
            return NSMakeRect(0, 0, 0, 0);
        }
    }

    // Original behavior
    CIDebug(@"Called to determine where to draw.");
    if ([DataManager sharedManager].hasPreeditText == NO) {
        return [self org_firstRectForCharacterRange:aRange actualRange:actualRange];
    }

    float *rect = malloc(4 * sizeof(float));
    [[DataManager sharedManager] activeView].firstRectForCharacterRange(rect);
    CIDebug([NSString stringWithFormat:@"Java Rect: \"%@\"", [NSString stringWithFormat:@"%.1f %.1f %.1f %.1f", rect[0], rect[1], rect[2], rect[3]]]);
    return NSMakeRect(rect[0], [[DataManager sharedManager] glfwView].window.screen.frame.size.height - rect[1], rect[2], rect[3]);
}

- (BOOL)hasMarkedText {
    return NO;
}

- (NSRange)selectedRange {
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)markedRange {
    // Check for Sonoma IME tooltip
    if (@available(macOS 14.0, *)) {
        if ([[DataManager sharedManager] activeView] == nil) {
            return NSMakeRange(NSNotFound, 0);
        }
    }

    // Original behavior
    [[DataManager sharedManager] activeView].insertText("", 0, 0);
    [self unmarkText];
    return NSMakeRange(NSNotFound, 0);
}

- (NSArray*)validAttributesForMarkedText {
    return nil;
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)aRange
                                               actualRange:
(NSRangePointer)actualRange {
    return nil;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)aPoint {
    return 0;
}

- (void)doCommandBySelector:(nonnull SEL)selector {
}


// 警告消しのためのダミーメソッド
- (NSRange)org_markedRange{return NSMakeRange(NSNotFound, 0);}
- (BOOL)org_hasMarkedText{return YES;};
- (void)org_keyDown:(NSEvent*)theEvent{}
- (void)org_unmarkText{}
- (void)org_interpretKeyEvents:(NSArray*)eventArray{}
- (NSRect)org_firstRectForCharacterRange:(NSRange)aRange
                             actualRange:(NSRangePointer)actualRange{ return NSMakeRect(0,0,0,0); }
- (void)org_insertText:(id)aString replacementRange:(NSRange)replacementRange{}
- (void)org_setMarkedText:(id)aString
            selectedRange:(NSRange)selectedRange
         replacementRange:(NSRange)replacementRange {}


@end
