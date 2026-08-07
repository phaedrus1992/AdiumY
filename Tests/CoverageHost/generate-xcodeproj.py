#!/usr/bin/env python3
"""Generate CoverageHost.xcodeproj — XCTest host + test bundle for AIUtilities.framework coverage.

Creates two targets:
  1. CoverageHost     — minimal Cocoa app serving as the test host
  2. CoverageHostTests — XCTest bundle injected into CoverageHost

Both are in a standalone project so we don't touch AIUtilities.xcodeproj.
"""

import uuid
import plistlib
import os

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
XCODE_PROJ = os.path.join(PROJECT_DIR, "CoverageHost.xcodeproj")
SCHEME_DIR = os.path.join(XCODE_PROJ, "xcshareddata", "xcschemes")
AIUTILITIES_PATH = "../../build/DerivedData/Build/Products/Debug"


def uid(key: str) -> str:
    # Deterministic: the same key always yields the same 24-hex-char ID, so
    # regenerating the project does not churn every UUID.
    return uuid.uuid5(uuid.NAMESPACE_URL, "coveragehost:" + key).hex.upper()[:24]


H = {}  # ids
for k in [
    "rootObject", "mainGroup", "productsGroup", "sourcesGroup",
    "frameworksGroup", "projectConfigList", "projectDebugConfig",
    "projectReleaseConfig",

    # CoverageHost app target
    "hostTarget", "hostTargetConfigList", "hostDebugConfig", "hostReleaseConfig",
    "hostProductRef", "hostMainFileRef", "hostMainBuildFile", "hostInfoPlistRef",
    "hostFrameworksPhase", "hostSourcesPhase", "hostCopyFrameworksPhase",
    "hostAiutilitiesCopyBuildFile",

    # CoverageHostTests test target
    "testTarget", "testTargetConfigList", "testDebugConfig", "testReleaseConfig",
    "testProductRef", "testFileRef", "testBuildFile", "testInfoPlistRef",
    "testSourcesPhase", "testFrameworksPhase", "testTargetDep",

    # CoverageHostTests extra sources (PBT util, AIXtraBundleIdentifier, migration)
    "pbtUtilFileRef", "pbtUtilHeaderRef", "pbtUtilBuildFile",
    "xtraIdentFileRef", "xtraIdentHeaderRef", "xtraIdentBuildFile",
    "xtraIdentTestFileRef", "xtraIdentTestBuildFile",
    "migrFileRef", "migrHeaderRef", "migrBuildFile",
    "migrTestFileRef", "migrTestBuildFile",
    "ctxMenuFileRef", "ctxMenuHeaderRef", "ctxMenuBuildFile",
    "ctxMenuTestFileRef", "ctxMenuTestBuildFile",
    "sanitizerFileRef", "sanitizerHeaderRef", "sanitizerBuildFile",
    "sanitizerTestFileRef", "sanitizerTestBuildFile",
    "dlValidFileRef", "dlValidHeaderRef", "dlValidBuildFile",
    "dlValidTestFileRef", "dlValidTestBuildFile",
    "iconPluginFileRef", "iconPluginHeaderRef", "iconPluginBuildFile",
    "iconPluginTestFileRef", "iconPluginTestBuildFile",
    "errHandlerPluginFileRef", "errHandlerPluginBuildFile",
    "errHandlerPluginTestFileRef", "errHandlerPluginTestBuildFile",
    "itunesPluginFileRef", "itunesPluginBuildFile",
    "itunesPluginTestFileRef", "itunesPluginTestBuildFile",
    "appearancePluginFileRef", "appearancePluginBuildFile",
    "appearancePluginTestFileRef", "appearancePluginTestBuildFile",
    "advPrefsPluginFileRef", "advPrefsPluginBuildFile",
    "advPrefsPluginTestFileRef", "advPrefsPluginTestBuildFile",
    "esAccountEventsPluginFileRef", "esAccountEventsPluginBuildFile",
    "esAccountEventsPluginTestFileRef", "esAccountEventsPluginTestBuildFile",
    "dcPluginFileRef", "dcPluginBuildFile",
    "dcPluginTestFileRef", "dcPluginTestBuildFile",
    "lastSeenPluginFileRef", "lastSeenPluginHeaderRef", "lastSeenPluginBuildFile",
    "lastSeenPluginTestFileRef", "lastSeenPluginTestBuildFile",
    "sortCtrlFileRef", "sortCtrlHeaderRef", "sortCtrlBuildFile",
    "sortCtrlTestFileRef", "sortCtrlTestBuildFile",
    "ezvIncomingFileRef", "ezvIncomingHeaderRef", "ezvIncomingBuildFile",
    "ezvTransferFileRef", "ezvTransferHeaderRef", "ezvTransferBuildFile",
    "ezvTestFileRef", "ezvTestBuildFile",

    # Plugin-uninstall teardown plugins + tests (#212-#215)
    "chatConsolPluginFileRef", "chatConsolPluginBuildFile",
    "newMsgPluginFileRef", "newMsgPluginBuildFile",
    "joinChatPluginFileRef", "joinChatPluginBuildFile",
    "invitePluginFileRef", "invitePluginBuildFile",
    "statusPrefsPluginFileRef", "statusPrefsPluginBuildFile",
    "stateMenuPluginFileRef", "stateMenuPluginBuildFile",
    "idlePluginFileRef", "idlePluginBuildFile",
    "visibilityPluginFileRef", "visibilityPluginBuildFile",
    "menuPluginTestFileRef", "menuPluginTestBuildFile",
    "stateMenuPluginTestFileRef", "stateMenuPluginTestBuildFile",
    "idlePluginTestFileRef", "idlePluginTestBuildFile",
    "visibilityPluginTestFileRef", "visibilityPluginTestBuildFile",

    # Plugin-uninstall teardown batch 3 (#218-#222): contact-alert plugins + per-plugin tests
    "eventSoundsPluginFileRef", "eventSoundsPluginBuildFile",
    "dockBehaviorPluginFileRef", "dockBehaviorPluginBuildFile",
    "announcerPluginFileRef", "announcerPluginBuildFile",
    "applescriptAlertPluginFileRef", "applescriptAlertPluginBuildFile",
    "smclsbPluginFileRef", "smclsbPluginBuildFile",
    "nehPluginFileRef", "nehPluginBuildFile",
    "doNothingPluginFileRef", "doNothingPluginBuildFile",
    "openMsgWindowPluginFileRef", "openMsgWindowPluginBuildFile",
    "sendMessagePluginFileRef", "sendMessagePluginBuildFile",
    "dockNameOverlayPluginFileRef", "dockNameOverlayPluginBuildFile",
    "contactAlertsUnregisterTestFileRef", "contactAlertsUnregisterTestBuildFile",

    # Plugin-uninstall teardown batch 3 (#218/#221/#222): per-plugin TU + test
    "accountMenuAccessPluginFileRef", "accountMenuAccessPluginBuildFile",
    "xtrasManagerPluginFileRef", "xtrasManagerPluginBuildFile",
    "emoticonMenuPluginFileRef", "emoticonMenuPluginBuildFile",
    "accountMenuAccessUninstallTestFileRef", "accountMenuAccessUninstallTestBuildFile",
    "xtrasManagerUninstallTestFileRef", "xtrasManagerUninstallTestBuildFile",
    "emoticonMenuUninstallTestFileRef", "emoticonMenuUninstallTestBuildFile",

    # Plugin-uninstall teardown batch 4 (#230/#231): nudge/buzz + preference-pane plugins + consolidated test
    "nudgeBuzzPluginFileRef", "nudgeBuzzPluginBuildFile",
    "esGeneralPrefsPluginFileRef", "esGeneralPrefsPluginBuildFile",
    "mentionEventPluginFileRef", "mentionEventPluginBuildFile",
    "urlHandlerPluginFileRef", "urlHandlerPluginBuildFile",
    "accountListPrefsPluginFileRef", "accountListPrefsPluginBuildFile",
    "globalEventsPrefsPluginFileRef", "globalEventsPrefsPluginBuildFile",
    "variantTeardownTestFileRef", "variantTeardownTestBuildFile",

    # Frameworks
    "xctestFwkRef", "xctestFwkBuildFile",
    "aiutilitiesFwkRef", "aiutilitiesFwkBuildFile",
    "cocoaFwkRef", "cocoaFwkBuildFile",
    "userNotificationsFwkRef", "userNotificationsFwkBuildFile",
]:
    H[k] = uid(k)


objects = {
    # ── PBXProject ──────────────────────────────────────────────
    H["rootObject"]: {
        "isa": "PBXProject",
        "buildConfigurationList": H["projectConfigList"],
        "compatibilityVersion": "Xcode 14.0",
        "mainGroup": H["mainGroup"],
        "productRefGroup": H["productsGroup"],
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [H["hostTarget"], H["testTarget"]],
        "developmentRegion": "en",
        "hasScannedForEncodings": True,
        "knownRegions": ["en", "Base"],
    },

    # ── Groups ──────────────────────────────────────────────────
    H["mainGroup"]: {
        "isa": "PBXGroup",
        "children": [H["sourcesGroup"], H["frameworksGroup"], H["productsGroup"]],
        "sourceTree": "<group>",
    },
    H["sourcesGroup"]: {
        "isa": "PBXGroup",
        "children": [H["hostMainFileRef"], H["hostInfoPlistRef"],
                     H["testFileRef"], H["testInfoPlistRef"],
                     H["pbtUtilFileRef"], H["pbtUtilHeaderRef"],
                     H["xtraIdentFileRef"], H["xtraIdentHeaderRef"],
                     H["xtraIdentTestFileRef"],
                     H["migrFileRef"], H["migrHeaderRef"],
                     H["migrTestFileRef"],
                     H["ctxMenuFileRef"], H["ctxMenuHeaderRef"],
                     H["ctxMenuTestFileRef"],
                     H["sanitizerFileRef"], H["sanitizerHeaderRef"],
                     H["sanitizerTestFileRef"],
                     H["dlValidFileRef"], H["dlValidHeaderRef"],
                     H["dlValidTestFileRef"],
                     H["iconPluginFileRef"], H["iconPluginHeaderRef"],
                     H["iconPluginTestFileRef"],
                     H["errHandlerPluginFileRef"],
                     H["errHandlerPluginTestFileRef"],
                     H["itunesPluginFileRef"],
                     H["itunesPluginTestFileRef"],
                     H["appearancePluginFileRef"],
                     H["appearancePluginTestFileRef"],
                     H["advPrefsPluginFileRef"], H["advPrefsPluginTestFileRef"],
                     H["esAccountEventsPluginFileRef"], H["esAccountEventsPluginTestFileRef"],
                     H["dcPluginFileRef"], H["dcPluginTestFileRef"],
                     H["ezvIncomingFileRef"], H["ezvIncomingHeaderRef"],
                     H["ezvTransferFileRef"], H["ezvTransferHeaderRef"],
                     H["ezvTestFileRef"],
                     H["eventSoundsPluginFileRef"], H["dockBehaviorPluginFileRef"],
                     H["announcerPluginFileRef"], H["applescriptAlertPluginFileRef"],
                     H["smclsbPluginFileRef"], H["nehPluginFileRef"],
                     H["doNothingPluginFileRef"], H["openMsgWindowPluginFileRef"],
                     H["sendMessagePluginFileRef"], H["dockNameOverlayPluginFileRef"],
                     H["contactAlertsUnregisterTestFileRef"],
                     H["accountMenuAccessPluginFileRef"], H["xtrasManagerPluginFileRef"],
                     H["emoticonMenuPluginFileRef"],
                     H["accountMenuAccessUninstallTestFileRef"],
                     H["xtrasManagerUninstallTestFileRef"],
                     H["emoticonMenuUninstallTestFileRef"],
                     H["nudgeBuzzPluginFileRef"], H["esGeneralPrefsPluginFileRef"],
                     H["mentionEventPluginFileRef"], H["urlHandlerPluginFileRef"],
                     H["accountListPrefsPluginFileRef"], H["globalEventsPrefsPluginFileRef"],
                     H["variantTeardownTestFileRef"]],
        "name": "Sources",
        "sourceTree": "<group>",
    },
    H["frameworksGroup"]: {
        "isa": "PBXGroup",
        "children": [H["xctestFwkRef"], H["userNotificationsFwkRef"]],
        "name": "Frameworks",
        "sourceTree": "<group>",
    },
    H["productsGroup"]: {
        "isa": "PBXGroup",
        "children": [H["hostProductRef"], H["testProductRef"]],
        "name": "Products",
        "sourceTree": "<group>",
    },

    # ── File References ─────────────────────────────────────────
    H["hostMainFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "main.m",
        "sourceTree": "<group>",
    },
    H["hostInfoPlistRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": "CoverageHost-Info.plist",
        "sourceTree": "<group>",
    },
    H["hostProductRef"]: {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.application",
        "includeInIndex": False,
        "path": "CoverageHost.app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    },

    H["testFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "CoverageHostTest.m",
        "sourceTree": "<group>",
    },
    H["testInfoPlistRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": "CoverageHostTests-Info.plist",
        "sourceTree": "<group>",
    },
    H["testProductRef"]: {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.cfbundle",
        "includeInIndex": False,
        "path": "CoverageHostTests.xctest",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    },

    # Property-testing utilities + the pure functions under test, pulled in from
    # the repo tree via group-relative paths (group = project dir).
    H["pbtUtilFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/AIPropertyTestUtilities.m",
        "sourceTree": "<group>",
    },
    H["pbtUtilHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../UnitTests/AIPropertyTestUtilities.h",
        "sourceTree": "<group>",
    },
    H["xtraIdentFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Frameworks/AIUtilities/Source/AIXtraBundleIdentifier.m",
        "sourceTree": "<group>",
    },
    H["xtraIdentHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Frameworks/AIUtilities/Source/AIXtraBundleIdentifier.h",
        "sourceTree": "<group>",
    },
    H["xtraIdentTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/AIXtraBundleIdentifierTest.m",
        "sourceTree": "<group>",
    },
    H["migrFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/WebKit Message View/AIWebkitMessageStylePreferenceMigration.m",
        "sourceTree": "<group>",
    },
    H["migrHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/WebKit Message View/AIWebkitMessageStylePreferenceMigration.h",
        "sourceTree": "<group>",
    },
    H["migrTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/MessageStylePreferenceMigrationTest.m",
        "sourceTree": "<group>",
    },
    H["ctxMenuFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/WebKit Message View/AIWebKitMessageViewWKContextMenu.m",
        "sourceTree": "<group>",
    },
    H["ctxMenuHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/WebKit Message View/AIWebKitMessageViewWKContextMenu.h",
        "sourceTree": "<group>",
    },
    H["ctxMenuTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestPropertyBasedAIWebKitMessageViewWKContextMenu.m",
        "sourceTree": "<group>",
    },
    H["sanitizerFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Frameworks/Adium/Source/AIHTMLPasteSanitizer.m",
        "sourceTree": "<group>",
    },
    H["sanitizerHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Frameworks/Adium/Source/AIHTMLPasteSanitizer.h",
        "sourceTree": "<group>",
    },
    H["sanitizerTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestPropertyBasedAIHTMLPasteSanitizer.m",
        "sourceTree": "<group>",
    },
    H["dlValidFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Frameworks/Adium/Source/AIHTTPDownloadValidation.m",
        "sourceTree": "<group>",
    },
    H["dlValidHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Frameworks/Adium/Source/AIHTTPDownloadValidation.h",
        "sourceTree": "<group>",
    },
    H["dlValidTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIHTTPDownloadValidation.m",
        "sourceTree": "<group>",
    },
    H["iconPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESUserIconHandlingPlugin.m",
        "sourceTree": "<group>",
    },
    H["iconPluginHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Source/ESUserIconHandlingPlugin.h",
        "sourceTree": "<group>",
    },
    H["iconPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestESUserIconHandlingPluginObserverRemoval.m",
        "sourceTree": "<group>",
    },
    H["errHandlerPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Error Message Handler/ErrorMessageHandlerPlugin.m",
        "sourceTree": "<group>",
    },
    H["errHandlerPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestErrorMessageHandlerPluginObserverRemoval.m",
        "sourceTree": "<group>",
    },
    H["itunesPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESiTunesPlugin.m",
        "sourceTree": "<group>",
    },
    H["itunesPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestESiTunesPluginObserverRemoval.m",
        "sourceTree": "<group>",
    },
    H["appearancePluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIAppearancePreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["appearancePluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIAppearancePreferencesPluginObserverRemoval.m",
        "sourceTree": "<group>",
    },
    # Plugin-uninstall teardown batch 4 (#230/#231/#232): per-plugin TU + test.
    H["advPrefsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIAdvancedPreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["advPrefsPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIAdvancedPreferencesPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["esAccountEventsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESAccountEvents.m",
        "sourceTree": "<group>",
    },
    H["esAccountEventsPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestESAccountEventsUnregister.m",
        "sourceTree": "<group>",
    },
    H["dcPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/DCMessageContextDisplayPlugin.m",
        "sourceTree": "<group>",
    },
    H["dcPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestDCMessageContextDisplayPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["sortCtrlFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Frameworks/Adium/Source/AISortController.m",
        "sourceTree": "<group>",
    },
    H["sortCtrlHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Frameworks/Adium/Source/AISortController.h",
        "sourceTree": "<group>",
    },
    H["sortCtrlTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAISortControllerUnregister.m",
        "sourceTree": "<group>",
    },
    H["lastSeenPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/CBContactLastSeenPlugin.m",
        "sourceTree": "<group>",
    },
    H["lastSeenPluginHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Source/CBContactLastSeenPlugin.h",
        "sourceTree": "<group>",
    },
    H["lastSeenPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestCBContactLastSeenPluginObserverRemoval.m",
        "sourceTree": "<group>",
    },
    H["ezvIncomingFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvIncomingFileTransfer.m",
        "sourceTree": "<group>",
    },
    H["ezvIncomingHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvIncomingFileTransfer.h",
        "sourceTree": "<group>",
    },
    H["ezvTransferFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvFileTransfer.m",
        "sourceTree": "<group>",
    },
    H["ezvTransferHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvFileTransfer.h",
        "sourceTree": "<group>",
    },
    H["ezvTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestEKEzvIncomingFileTransferDepthCap.m",
        "sourceTree": "<group>",
    },

    # Plugin-uninstall teardown plugins (#212-#215). DCInviteToChatPlugin lives in its plugin
    # bundle directory; the other seven under Source/.
    H["chatConsolPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIChatConsolidationPlugin.m",
        "sourceTree": "<group>",
    },
    H["newMsgPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AINewMessagePanelPlugin.m",
        "sourceTree": "<group>",
    },
    H["joinChatPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/DCJoinChatPanelPlugin.m",
        "sourceTree": "<group>",
    },
    H["invitePluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Invite to Chat Plugin/DCInviteToChatPlugin.m",
        "sourceTree": "<group>",
    },
    H["statusPrefsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESStatusPreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["stateMenuPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIStateMenuPlugin.m",
        "sourceTree": "<group>",
    },
    H["idlePluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIContactIdlePlugin.m",
        "sourceTree": "<group>",
    },
    H["visibilityPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIContactVisibilityControlPlugin.m",
        "sourceTree": "<group>",
    },
    H["menuPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestMenuPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["stateMenuPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIStateMenuPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["idlePluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIContactIdlePluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["visibilityPluginTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIContactVisibilityControlPluginUninstall.m",
        "sourceTree": "<group>",
    },

    # Plugin-uninstall teardown batch 3 (#218-#222): contact-alert plugin TUs + their unregister test.
    # The ten plugins share unregisterActionID: (or the NSNotificationCenter/action-table path) that
    # #219 added; the batch-2 state-menu/etc. tests above cover the other #212-#215 plugins.
    H["eventSoundsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIEventSoundsPlugin.m",
        "sourceTree": "<group>",
    },
    H["dockBehaviorPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIDockBehaviorPlugin.m",
        "sourceTree": "<group>",
    },
    H["announcerPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESAnnouncerPlugin.m",
        "sourceTree": "<group>",
    },
    H["applescriptAlertPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESApplescriptContactAlertPlugin.m",
        "sourceTree": "<group>",
    },
    H["smclsbPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/SMContactListShowBehaviorPlugin.m",
        "sourceTree": "<group>",
    },
    H["nehPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/NEHUserNotificationPlugin.m",
        "sourceTree": "<group>",
    },
    H["doNothingPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Do Nothing Contact Alert/AIDoNothingContactAlertPlugin.m",
        "sourceTree": "<group>",
    },
    H["openMsgWindowPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Open Message Window Contact Alert/ESOpenMessageWindowContactAlertPlugin.m",
        "sourceTree": "<group>",
    },
    H["sendMessagePluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Send Message Contact Alert/ESSendMessageContactAlertPlugin.m",
        "sourceTree": "<group>",
    },
    H["dockNameOverlayPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Dock Icon Badging/AIDockNameOverlay.m",
        "sourceTree": "<group>",
    },
    H["contactAlertsUnregisterTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestContactAlertPluginsUnregister.m",
        "sourceTree": "<group>",
    },

    # Plugin-uninstall teardown batch 3 (#218/#221/#222): per-plugin TU + test.
    H["accountMenuAccessPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIAccountMenuAccessPlugin.m",
        "sourceTree": "<group>",
    },
    H["xtrasManagerPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIXtrasManager.m",
        "sourceTree": "<group>",
    },
    H["emoticonMenuPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/BGEmoticonMenuPlugin.m",
        "sourceTree": "<group>",
    },
    H["accountMenuAccessUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAccountMenuAccessPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["xtrasManagerUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestXtrasManagerUninstall.m",
        "sourceTree": "<group>",
    },
    H["emoticonMenuUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestEmoticonMenuPluginUninstall.m",
        "sourceTree": "<group>",
    },

    # Plugin-uninstall teardown batch 4 (#230/#231): plugin TUs + consolidated variant test.
    H["nudgeBuzzPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Nudge and Buzz Handler/AINudgeBuzzHandlerPlugin.m",
        "sourceTree": "<group>",
    },
    H["esGeneralPrefsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/General Preferences/ESGeneralPreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["mentionEventPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIMentionEventPlugin.m",
        "sourceTree": "<group>",
    },
    H["urlHandlerPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIURLHandlerPlugin.m",
        "sourceTree": "<group>",
    },
    H["accountListPrefsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIAccountListPreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["globalEventsPrefsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/ESGlobalEventsPreferencesPlugin.m",
        "sourceTree": "<group>",
    },
    H["variantTeardownTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestPluginTeardownVariantUninstall.m",
        "sourceTree": "<group>",
    },

    H["xctestFwkRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "wrapper.framework",
        "name": "XCTest.framework",
        "path": "/Library/Frameworks/XCTest.framework",
        "sourceTree": "<absolute>",
    },

    # AIUtilities.framework — referenced relative to project so
    # FRAMEWORK_SEARCH_PATHS can find it.
    H["aiutilitiesFwkRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "wrapper.framework",
        "name": "AIUtilities.framework",
        "path": AIUTILITIES_PATH + "/AIUtilities.framework",
        "sourceTree": "SOURCE_ROOT",
    },

    H["cocoaFwkRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "wrapper.framework",
        "name": "Cocoa.framework",
        "path": "/System/Library/Frameworks/Cocoa.framework",
        "sourceTree": "<absolute>",
    },

    # UserNotifications.framework — NEHUserNotificationPlugin.m sends to UNUserNotificationCenter
    # and UNNotificationAction (class sends), which need the framework linked into the test bundle.
    H["userNotificationsFwkRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "wrapper.framework",
        "name": "UserNotifications.framework",
        "path": "/System/Library/Frameworks/UserNotifications.framework",
        "sourceTree": "<absolute>",
    },

    # ── Build Phases: Host ───────────────────────────────────────
    H["hostSourcesPhase"]: {
        "isa": "PBXSourcesBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["hostMainBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },
    H["hostFrameworksPhase"]: {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["cocoaFwkBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },
    H["hostCopyFrameworksPhase"]: {
        "isa": "PBXCopyFilesBuildPhase",
        "buildActionMask": 2147483647,
        "dstPath": "",
        "dstSubfolderSpec": 10,
        "files": [H["hostAiutilitiesCopyBuildFile"]],
        "name": "Copy Frameworks",
        "runOnlyForDeploymentPostprocessing": False,
    },

    # ── Build Phases: Test ───────────────────────────────────────
    H["testSourcesPhase"]: {
        "isa": "PBXSourcesBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["testBuildFile"], H["pbtUtilBuildFile"],
                  H["xtraIdentTestBuildFile"], H["xtraIdentBuildFile"],
                  H["migrTestBuildFile"], H["migrBuildFile"],
                  H["ctxMenuBuildFile"], H["ctxMenuTestBuildFile"],
                  H["sanitizerBuildFile"], H["sanitizerTestBuildFile"],
                  H["dlValidBuildFile"], H["dlValidTestBuildFile"],
                  H["iconPluginBuildFile"], H["iconPluginTestBuildFile"],
                  H["errHandlerPluginBuildFile"], H["errHandlerPluginTestBuildFile"],
                  H["itunesPluginBuildFile"], H["itunesPluginTestBuildFile"],
                  H["appearancePluginBuildFile"], H["appearancePluginTestBuildFile"],
                  H["advPrefsPluginBuildFile"], H["advPrefsPluginTestBuildFile"],
                  H["esAccountEventsPluginBuildFile"], H["esAccountEventsPluginTestBuildFile"],
                  H["dcPluginBuildFile"], H["dcPluginTestBuildFile"],
                  H["sortCtrlBuildFile"], H["sortCtrlTestBuildFile"],
                  H["lastSeenPluginBuildFile"], H["lastSeenPluginTestBuildFile"],
                  H["ezvIncomingBuildFile"], H["ezvTransferBuildFile"],
                  H["ezvTestBuildFile"],
                  H["chatConsolPluginBuildFile"], H["newMsgPluginBuildFile"],
                  H["joinChatPluginBuildFile"], H["invitePluginBuildFile"],
                  H["statusPrefsPluginBuildFile"], H["stateMenuPluginBuildFile"],
                  H["idlePluginBuildFile"], H["visibilityPluginBuildFile"],
                  H["menuPluginTestBuildFile"], H["stateMenuPluginTestBuildFile"],
                  H["idlePluginTestBuildFile"], H["visibilityPluginTestBuildFile"],
                  H["eventSoundsPluginBuildFile"], H["dockBehaviorPluginBuildFile"],
                  H["announcerPluginBuildFile"], H["applescriptAlertPluginBuildFile"],
                  H["smclsbPluginBuildFile"], H["nehPluginBuildFile"],
                  H["doNothingPluginBuildFile"], H["openMsgWindowPluginBuildFile"],
                  H["sendMessagePluginBuildFile"], H["dockNameOverlayPluginBuildFile"],
                  H["contactAlertsUnregisterTestBuildFile"],
                  H["accountMenuAccessPluginBuildFile"], H["xtrasManagerPluginBuildFile"],
                  H["emoticonMenuPluginBuildFile"],
                  H["accountMenuAccessUninstallTestBuildFile"],
                  H["xtrasManagerUninstallTestBuildFile"],
                  H["emoticonMenuUninstallTestBuildFile"],
                  H["nudgeBuzzPluginBuildFile"], H["esGeneralPrefsPluginBuildFile"],
                  H["mentionEventPluginBuildFile"], H["urlHandlerPluginBuildFile"],
                  H["accountListPrefsPluginBuildFile"], H["globalEventsPrefsPluginBuildFile"],
                  H["variantTeardownTestBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },
    H["testFrameworksPhase"]: {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["xctestFwkBuildFile"], H["aiutilitiesFwkBuildFile"],
                  H["cocoaFwkBuildFile"], H["userNotificationsFwkBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },

    # ── Build Files ─────────────────────────────────────────────
    H["hostMainBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["hostMainFileRef"]},
    H["testBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["testFileRef"]},
    H["xctestFwkBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["xctestFwkRef"]},
    H["aiutilitiesFwkBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["aiutilitiesFwkRef"]},
    H["cocoaFwkBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["cocoaFwkRef"]},

    H["pbtUtilBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["pbtUtilFileRef"]},
    H["xtraIdentBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["xtraIdentFileRef"]},
    H["xtraIdentTestBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["xtraIdentTestFileRef"]},
    H["migrBuildFile"]:           {"isa": "PBXBuildFile", "fileRef": H["migrFileRef"]},
    H["migrTestBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["migrTestFileRef"]},
    H["ctxMenuBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["ctxMenuFileRef"]},
    H["ctxMenuTestBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["ctxMenuTestFileRef"]},
    H["sanitizerBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["sanitizerFileRef"]},
    H["sanitizerTestBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["sanitizerTestFileRef"]},
    H["dlValidBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["dlValidFileRef"]},
    H["dlValidTestBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["dlValidTestFileRef"]},
    H["iconPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["iconPluginFileRef"]},
    H["iconPluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["iconPluginTestFileRef"]},
    H["errHandlerPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["errHandlerPluginFileRef"]},
    H["errHandlerPluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["errHandlerPluginTestFileRef"]},
    H["itunesPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["itunesPluginFileRef"]},
    H["itunesPluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["itunesPluginTestFileRef"]},
    H["appearancePluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["appearancePluginFileRef"]},
    H["appearancePluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["appearancePluginTestFileRef"]},
    H["advPrefsPluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["advPrefsPluginFileRef"]},
    H["advPrefsPluginTestBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["advPrefsPluginTestFileRef"]},
    H["esAccountEventsPluginBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["esAccountEventsPluginFileRef"]},
    H["esAccountEventsPluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["esAccountEventsPluginTestFileRef"]},
    H["dcPluginBuildFile"]:               {"isa": "PBXBuildFile", "fileRef": H["dcPluginFileRef"]},
    H["dcPluginTestBuildFile"]:           {"isa": "PBXBuildFile", "fileRef": H["dcPluginTestFileRef"]},
    H["sortCtrlBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["sortCtrlFileRef"]},
    H["sortCtrlTestBuildFile"]:   {"isa": "PBXBuildFile", "fileRef": H["sortCtrlTestFileRef"]},
    H["lastSeenPluginBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["lastSeenPluginFileRef"]},
    H["lastSeenPluginTestBuildFile"]:   {"isa": "PBXBuildFile", "fileRef": H["lastSeenPluginTestFileRef"]},
    H["ezvIncomingBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["ezvIncomingFileRef"]},
    H["ezvTransferBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["ezvTransferFileRef"]},
    H["ezvTestBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["ezvTestFileRef"]},
    H["chatConsolPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["chatConsolPluginFileRef"]},
    H["newMsgPluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["newMsgPluginFileRef"]},
    H["joinChatPluginBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["joinChatPluginFileRef"]},
    H["invitePluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["invitePluginFileRef"]},
    H["statusPrefsPluginBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["statusPrefsPluginFileRef"]},
    H["stateMenuPluginBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["stateMenuPluginFileRef"]},
    H["idlePluginBuildFile"]:           {"isa": "PBXBuildFile", "fileRef": H["idlePluginFileRef"]},
    H["visibilityPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["visibilityPluginFileRef"]},
    H["menuPluginTestBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["menuPluginTestFileRef"]},
    H["stateMenuPluginTestBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["stateMenuPluginTestFileRef"]},
    H["idlePluginTestBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["idlePluginTestFileRef"]},
    H["visibilityPluginTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["visibilityPluginTestFileRef"]},
    H["eventSoundsPluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["eventSoundsPluginFileRef"]},
    H["dockBehaviorPluginBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["dockBehaviorPluginFileRef"]},
    H["announcerPluginBuildFile"]:           {"isa": "PBXBuildFile", "fileRef": H["announcerPluginFileRef"]},
    H["applescriptAlertPluginBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["applescriptAlertPluginFileRef"]},
    H["smclsbPluginBuildFile"]:              {"isa": "PBXBuildFile", "fileRef": H["smclsbPluginFileRef"]},
    H["nehPluginBuildFile"]:                 {"isa": "PBXBuildFile", "fileRef": H["nehPluginFileRef"]},
    H["doNothingPluginBuildFile"]:           {"isa": "PBXBuildFile", "fileRef": H["doNothingPluginFileRef"]},
    H["openMsgWindowPluginBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["openMsgWindowPluginFileRef"]},
    H["sendMessagePluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["sendMessagePluginFileRef"]},
    H["dockNameOverlayPluginBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["dockNameOverlayPluginFileRef"]},
    H["contactAlertsUnregisterTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["contactAlertsUnregisterTestFileRef"]},
    H["accountMenuAccessPluginBuildFile"]:   {"isa": "PBXBuildFile", "fileRef": H["accountMenuAccessPluginFileRef"]},
    H["xtrasManagerPluginBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["xtrasManagerPluginFileRef"]},
    H["emoticonMenuPluginBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["emoticonMenuPluginFileRef"]},
    H["accountMenuAccessUninstallTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["accountMenuAccessUninstallTestFileRef"]},
    H["xtrasManagerUninstallTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["xtrasManagerUninstallTestFileRef"]},
    H["emoticonMenuUninstallTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["emoticonMenuUninstallTestFileRef"]},
    H["nudgeBuzzPluginBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["nudgeBuzzPluginFileRef"]},
    H["esGeneralPrefsPluginBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["esGeneralPrefsPluginFileRef"]},
    H["mentionEventPluginBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["mentionEventPluginFileRef"]},
    H["urlHandlerPluginBuildFile"]:        {"isa": "PBXBuildFile", "fileRef": H["urlHandlerPluginFileRef"]},
    H["accountListPrefsPluginBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["accountListPrefsPluginFileRef"]},
    H["globalEventsPrefsPluginBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["globalEventsPrefsPluginFileRef"]},
    H["variantTeardownTestBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["variantTeardownTestFileRef"]},
    H["userNotificationsFwkBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["userNotificationsFwkRef"]},

    # ── Target Dependency ───────────────────────────────────────
    H["testTargetDep"]: {
        "isa": "PBXTargetDependency",
        "target": H["hostTarget"],
    },

    # ── CoverageHost Target ─────────────────────────────────────
    H["hostTarget"]: {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": H["hostTargetConfigList"],
        "buildPhases": [H["hostSourcesPhase"], H["hostFrameworksPhase"]],
        "buildRules": [],
        "dependencies": [],
        "name": "CoverageHost",
        "productName": "CoverageHost",
        "productReference": H["hostProductRef"],
        "productType": "com.apple.product-type.application",
    },

    # ── CoverageHostTests Target ─────────────────────────────────
    H["testTarget"]: {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": H["testTargetConfigList"],
        "buildPhases": [H["testSourcesPhase"], H["testFrameworksPhase"]],
        "buildRules": [],
        "dependencies": [H["testTargetDep"]],
        "name": "CoverageHostTests",
        "productName": "CoverageHostTests",
        "productReference": H["testProductRef"],
        "productType": "com.apple.product-type.bundle.unit-test",
    },

    # ── Build Configurations: Project ────────────────────────────
    H["projectDebugConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "ALWAYS_SEARCH_USER_PATHS": False,
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "COPY_PHASE_STRIP": False,
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_STRICT_OBJC_MSGSEND": True,
            "ENABLE_TESTABILITY": True,
            "GCC_NO_COMMON_BLOCKS": True,
            "GCC_OPTIMIZATION_LEVEL": "0",
            "MACOSX_DEPLOYMENT_TARGET": "11.0",
            "ONLY_ACTIVE_ARCH": True,
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
        },
        "name": "Debug",
    },
    H["projectReleaseConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "ALWAYS_SEARCH_USER_PATHS": False,
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "COPY_PHASE_STRIP": True,
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "ENABLE_STRICT_OBJC_MSGSEND": True,
            "ENABLE_TESTABILITY": True,
            "GCC_NO_COMMON_BLOCKS": True,
            "GCC_OPTIMIZATION_LEVEL": "s",
            "MACOSX_DEPLOYMENT_TARGET": "11.0",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
        },
        "name": "Release",
    },

    # ── Build Configurations: CoverageHost (app host) ────────────
    H["hostDebugConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "CODE_SIGNING_ALLOWED": False,
            "COMBINE_HIDPI_IMAGES": True,
            "FRAMEWORK_SEARCH_PATHS": (
                "$(inherited)",
                "$(SRCROOT)/../../build/DerivedData/Build/Products/Debug",
            ),
            "INFOPLIST_FILE": "CoverageHost-Info.plist",
            "LD_RUNPATH_SEARCH_PATHS": (
                "@executable_path/../Frameworks",
                "$(FRAMEWORK_SEARCH_PATHS)",
            ),
            "PRODUCT_BUNDLE_IDENTIFIER": "com.github.phaedrus1992.adiumy.CoverageHost",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
        },
        "name": "Debug",
    },
    H["hostReleaseConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "CODE_SIGNING_ALLOWED": False,
            "COMBINE_HIDPI_IMAGES": True,
            "FRAMEWORK_SEARCH_PATHS": (
                "$(inherited)",
                "$(SRCROOT)/../../build/DerivedData/Build/Products/Debug",
            ),
            "INFOPLIST_FILE": "CoverageHost-Info.plist",
            "LD_RUNPATH_SEARCH_PATHS": (
                "@executable_path/../Frameworks",
                "$(FRAMEWORK_SEARCH_PATHS)",
            ),
            "PRODUCT_BUNDLE_IDENTIFIER": "com.github.phaedrus1992.adiumy.CoverageHost",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
        },
        "name": "Release",
    },

    # ── Build Configurations: CoverageHostTests ──────────────────
    H["testDebugConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "CODE_SIGNING_ALLOWED": False,
            "COMBINE_HIDPI_IMAGES": True,
            "FRAMEWORK_SEARCH_PATHS": (
                "$(inherited)",
                "$(SRCROOT)/../../build/DerivedData/Build/Products/Debug",
            ),
            "HEADER_SEARCH_PATHS": (
                "$(inherited)",
                # Resolve <AdiumY/...> via Tests/CoverageHost/AdiumY symlinks (CI builds no AdiumY.framework).
                "$(SRCROOT)",
                "$(SRCROOT)/../../Source",
                "$(SRCROOT)/../../UnitTests",
                '"$(SRCROOT)/../../Plugins/WebKit Message View"',
                '"$(SRCROOT)/../../Plugins/Error Message Handler"',
                '"$(SRCROOT)/../../Plugins/Invite to Chat Plugin"',
                '"$(SRCROOT)/../../Plugins/Dual Window Interface"',
                "$(SRCROOT)/../../Frameworks/Adium/Source",
                "$(SRCROOT)/../../Plugins/Bonjour/libezv/Classes",
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Other Sources"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Private Classes"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Simple HTTP Server"',
                '"$(SRCROOT)/../../Plugins/Do Nothing Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Open Message Window Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Send Message Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Dock Icon Badging"',
                "$(SRCROOT)/LMX",
            ),
            # Real Adium headers rely on Adium.pch for Cocoa/Foundation; restore that
            # invariant for the harness (clang-format orders <AdiumY/...> before <Cocoa/...>).
            "GCC_PREFIX_HEADER": "CoverageHostTests.pch",
            "INFOPLIST_FILE": "CoverageHostTests-Info.plist",
            "INSTALL_PATH": "$(LOCAL_LIBRARY_DIR)/Bundles",
            "LD_RUNPATH_SEARCH_PATHS": (
                "@loader_path/../Frameworks",
                "$(FRAMEWORK_SEARCH_PATHS)",
            ),
            "PRODUCT_BUNDLE_IDENTIFIER": "com.github.phaedrus1992.adiumy.CoverageHostTests",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/CoverageHost.app/Contents/MacOS/CoverageHost",
            "WRAPPER_EXTENSION": "xctest",
        },
        "name": "Debug",
    },
    H["testReleaseConfig"]: {
        "isa": "XCBuildConfiguration",
        "buildSettings": {
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_ENABLE_OBJC_WEAK": True,
            "CODE_SIGNING_ALLOWED": False,
            "COMBINE_HIDPI_IMAGES": True,
            "FRAMEWORK_SEARCH_PATHS": (
                "$(inherited)",
                "$(SRCROOT)/../../build/DerivedData/Build/Products/Debug",
            ),
            "HEADER_SEARCH_PATHS": (
                "$(inherited)",
                # Resolve <AdiumY/...> via Tests/CoverageHost/AdiumY symlinks (CI builds no AdiumY.framework).
                "$(SRCROOT)",
                "$(SRCROOT)/../../Source",
                "$(SRCROOT)/../../UnitTests",
                '"$(SRCROOT)/../../Plugins/WebKit Message View"',
                '"$(SRCROOT)/../../Plugins/Error Message Handler"',
                '"$(SRCROOT)/../../Plugins/Invite to Chat Plugin"',
                '"$(SRCROOT)/../../Plugins/Dual Window Interface"',
                "$(SRCROOT)/../../Frameworks/Adium/Source",
                "$(SRCROOT)/../../Plugins/Bonjour/libezv/Classes",
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Other Sources"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Private Classes"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Simple HTTP Server"',
                '"$(SRCROOT)/../../Plugins/Do Nothing Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Open Message Window Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Send Message Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Dock Icon Badging"',
                "$(SRCROOT)/LMX",
            ),
            # Real Adium headers rely on Adium.pch for Cocoa/Foundation; restore that
            # invariant for the harness (clang-format orders <AdiumY/...> before <Cocoa/...>).
            "GCC_PREFIX_HEADER": "CoverageHostTests.pch",
            "INFOPLIST_FILE": "CoverageHostTests-Info.plist",
            "INSTALL_PATH": "$(LOCAL_LIBRARY_DIR)/Bundles",
            "LD_RUNPATH_SEARCH_PATHS": (
                "@loader_path/../Frameworks",
                "$(FRAMEWORK_SEARCH_PATHS)",
            ),
            "PRODUCT_BUNDLE_IDENTIFIER": "com.github.phaedrus1992.adiumy.CoverageHostTests",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "macosx",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/CoverageHost.app/Contents/MacOS/CoverageHost",
            "WRAPPER_EXTENSION": "xctest",
        },
        "name": "Release",
    },

    # ── Configuration Lists ──────────────────────────────────────
    H["projectConfigList"]: {
        "isa": "XCConfigurationList",
        "buildConfigurations": [H["projectDebugConfig"], H["projectReleaseConfig"]],
        "defaultConfigurationIsVisible": False,
        "defaultConfigurationName": "Debug",
    },
    H["hostTargetConfigList"]: {
        "isa": "XCConfigurationList",
        "buildConfigurations": [H["hostDebugConfig"], H["hostReleaseConfig"]],
        "defaultConfigurationIsVisible": False,
        "defaultConfigurationName": "Debug",
    },
    H["testTargetConfigList"]: {
        "isa": "XCConfigurationList",
        "buildConfigurations": [H["testDebugConfig"], H["testReleaseConfig"]],
        "defaultConfigurationIsVisible": False,
        "defaultConfigurationName": "Debug",
    },
}


# ── Write pbxproj ────────────────────────────────────────────────────
proj = {
    "archiveVersion": "1",
    "classes": {},
    "objectVersion": "56",
    "objects": objects,
    "rootObject": H["rootObject"],
}


def convert_bool_to_string(obj):
    """Recursively convert boolean values in buildSettings to YES/NO strings.
    Xcode requires string values for build settings, not plist booleans."""
    if isinstance(obj, dict):
        if "isa" in obj and "buildSettings" in obj:
            bs = obj["buildSettings"]
            for k in bs:
                if isinstance(bs[k], bool):
                    bs[k] = "YES" if bs[k] else "NO"
        return {k: convert_bool_to_string(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_bool_to_string(v) for v in obj]
    return obj


proj = convert_bool_to_string(proj)

pbxproj_path = os.path.join(XCODE_PROJ, "project.pbxproj")
print(f"Generating {pbxproj_path} …")
os.makedirs(XCODE_PROJ, exist_ok=True)
with open(pbxproj_path, "wb") as f:
    plistlib.dump(proj, f, sort_keys=False)


# ── Write scheme ──────────────────────────────────────────────────────
scheme_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      codeCoverageEnabled = "YES"
      onlyGenerateCoverageForSpecifiedTargets = "NO">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{H["testTarget"]}"
               BuildableName = "CoverageHostTests.xctest"
               BlueprintName = "CoverageHostTests"
               ReferencedContainer = "container:CoverageHost.xcodeproj"/>
         </TestableReference>
      </Testables>
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{H["hostTarget"]}"
            BuildableName = "CoverageHost.app"
            BlueprintName = "CoverageHost"
            ReferencedContainer = "container:CoverageHost.xcodeproj"/>
      </MacroExpansion>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "NO">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{H["hostTarget"]}"
            BuildableName = "CoverageHost.app"
            BlueprintName = "CoverageHost"
            ReferencedContainer = "container:CoverageHost.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{H["hostTarget"]}"
            BuildableName = "CoverageHost.app"
            BlueprintName = "CoverageHost"
            ReferencedContainer = "container:CoverageHost.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>'''

os.makedirs(SCHEME_DIR, exist_ok=True)
with open(os.path.join(SCHEME_DIR, "CoverageHost.xcscheme"), "w") as f:
    f.write(scheme_xml)


# ── Source files, Info.plists and scheme are committed alongside the
# generator — the xcodeproj is the only dynamic output. Source writers
# were removed after initial scaffold to prevent accidental overwrites
# of committed files.

print("\nDone! Generated CoverageHost.xcodeproj:")
print("  Target: CoverageHost (macOS app — test host)")
print("  Target: CoverageHostTests (XCTest bundle)")
print("  Scheme: CoverageHost (Test action with code coverage)")
print()
print("Next steps:")
print("  1. Build AIUtilities: xcodebuild -project Frameworks/AIUtilities/AIUtilities.xcodeproj -configuration Debug -derivedDataPath build/DerivedData")
print("  2. Run tests:         xcodebuild test -project Tests/CoverageHost/CoverageHost.xcodeproj -scheme CoverageHost -configuration Debug -derivedDataPath build/DerivedData -enableCodeCoverage YES")
