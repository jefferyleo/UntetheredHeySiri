//
//  AssistantControllerHooks.m
//  UntetheredHeySiri
//
//  Created by Hamza Sood on 24/10/2014.
//  Copyright (c) 2014 Hamza Sood. All rights reserved.
//

@import Preferences;
@import CydiaSubstrate;
@import VoiceTrigger.VTPreferences;

#import "AssistantController.h"
#import "NoFooterGroupSpecifier.h"
#import <notify.h>




//Class to store origonal implementations
@interface _AssistantControllerHooks : PSListController
@end
@implementation _AssistantControllerHooks
@end

@interface AssistantControllerHooks : _AssistantControllerHooks
@end




@implementation AssistantControllerHooks

PSSpecifier *_allowedWhileDisconnectedSpecifier;

- (NSArray *)specifiers {
    if (_specifiers == nil) {
        NSArray *updatedSpecifiers = [super.specifiers arrayByPerformingSpecifierUpdatesUsingBlock:^(PSSpecifierUpdates *updates) {
            PSSpecifier *voiceActivationGroupSpecifier = [updates specifierForID:@"VOICE_ACTIVATION_GROUP"];
            object_setClass(voiceActivationGroupSpecifier, [NoFooterGroupSpecifier class]);
            [voiceActivationGroupSpecifier removePropertyForKey:PSFooterTextGroupKey];
            
            _allowedWhileDisconnectedSpecifier = [[PSSpecifier preferenceSpecifierNamed:@"AllowedWhileDisconnected"
                                                                                 target:self
                                                                                    set:@selector(setVoiceTriggerAllowedWhileDisconnected:specifier:)
                                                                                    get:@selector(voiceTriggerAllowedWhileDisconnected:)
                                                                                 detail:Nil
                                                                                   cell:[PSTableCell cellTypeFromString:@"PSSegmentCell"]
                                                                                   edit:Nil]retain];
            [_allowedWhileDisconnectedSpecifier setValues:@[@NO, @YES] titles:@[@"While Charging", @"Always"]];
            if ([[self voiceTrigger:nil]boolValue])
                [updates appendSpecifier:_allowedWhileDisconnectedSpecifier toGroupWithID:@"VOICE_ACTIVATION_GROUP"];
        }];
        [_specifiers release];
        _specifiers = [updatedSpecifiers retain];
    }
    return _specifiers;
}

#pragma mark -
#pragma mark Added Methods

NSNumber *VoiceTriggerAllowedWhileDisconnected(AssistantControllerHooks *self, SEL _cmd, PSSpecifier *specifier) {
    return @([[VTPreferences sharedPreferences]voiceTriggerEnabledWhenChargerDisconnected]);
}

void SetVoiceTriggerAllowedWhileDisconnected(AssistantControllerHooks *self, SEL _cmd, NSNumber *allowedWhileDisconnected, PSSpecifier *specifier) {
    [[VTPreferences sharedPreferences]setVoiceTriggerEnabledWhenChargerDisconnected:allowedWhileDisconnected.boolValue];
    notify_post("kVTPreferencesVoiceTriggerEnabledDidChangeDarwinNotification");
}

#pragma mark -

- (void)setVoiceTrigger:(NSNumber *)voiceTrigger forSpecifier:(PSSpecifier *)specifier {
    [super setVoiceTrigger:voiceTrigger forSpecifier:specifier];
    if (voiceTrigger.boolValue)
        [self insertSpecifier:_allowedWhileDisconnectedSpecifier afterSpecifierID:@"VOICE_ACTIVATION" animated:YES];
    else
        [self removeSpecifier:_allowedWhileDisconnectedSpecifier animated:YES];
}

- (void)dealloc {
    [_allowedWhileDisconnectedSpecifier release];
    [super dealloc];
}

@end




char *bundleLoadedObserver = "Where's AssistantController?!";

void AssistantBundleLoadedNotificationFired(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (objc_getClass("AssistantController") == Nil)
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class $AssistantController = objc_getClass("AssistantController");
        MSHookClassPair($AssistantController, [AssistantControllerHooks class], [_AssistantControllerHooks class]);
        class_addMethod($AssistantController, @selector(voiceTriggerAllowedWhileDisconnected:), (IMP)VoiceTriggerAllowedWhileDisconnected, "@@:@");
        class_addMethod($AssistantController, @selector(setVoiceTriggerAllowedWhileDisconnected:specifier:), (IMP)SetVoiceTriggerAllowedWhileDisconnected, "v@:@@");
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(),
                                           bundleLoadedObserver,
                                           (CFStringRef)NSBundleDidLoadNotification,
                                           NULL);
    });
}

__attribute__((constructor)) static void AssistantControllerHooksInit() {
    @autoreleasepool {
        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(),
                                        bundleLoadedObserver,
                                        AssistantBundleLoadedNotificationFired,
                                        (CFStringRef)NSBundleDidLoadNotification,
                                        [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/Assistant.bundle"],
                                        CFNotificationSuspensionBehaviorCoalesce);
    }
}