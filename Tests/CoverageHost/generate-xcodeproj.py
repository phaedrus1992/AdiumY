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
REPO_ROOT = os.path.dirname(os.path.dirname(PROJECT_DIR))


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
    "ezvXmlNodeFileRef", "ezvXmlNodeHeaderRef", "ezvXmlNodeBuildFile",
    "ezvXmlNodeTestFileRef", "ezvXmlNodeTestBuildFile",
    "ezvFolderCleanupTestFileRef", "ezvFolderCleanupTestBuildFile",
    "ezvXmlPropsTestFileRef", "ezvXmlPropsTestBuildFile",
    "ezvOutgoingFileRef", "ezvOutgoingHeaderRef", "ezvOutgoingBuildFile",
    "ezvOutgoingDepthCapTestFileRef", "ezvOutgoingDepthCapTestBuildFile",
    "ezvOutgoingUTF8TestFileRef", "ezvOutgoingUTF8TestBuildFile",
    "httpserverStubFileRef", "httpserverStubBuildFile",

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

    # Plugin-uninstall teardown batch 5 (#235-#237): status-events/dual-window/bonjour + AdiumServices registry
    "contactStatusEventsPluginFileRef", "contactStatusEventsPluginBuildFile",
    "contactStatusEventsUninstallTestFileRef", "contactStatusEventsUninstallTestBuildFile",
    "dualWindowPluginFileRef", "dualWindowPluginBuildFile",
    "dualWindowUninstallTestFileRef", "dualWindowUninstallTestBuildFile",
    "bonjourPluginFileRef", "bonjourPluginBuildFile",
    "bonjourUninstallTestFileRef", "bonjourUninstallTestBuildFile",
    "adiumServicesFileRef", "adiumServicesBuildFile",
    "adiumServicesUnregisterTestFileRef", "adiumServicesUnregisterTestBuildFile",

    # Plugin-uninstall teardown batch 6 (#240-#242): AIService/AIStatusController + Purple Service + SCLView plugins
    "aiServiceFileRef", "aiServiceBuildFile",
    "aiServiceUnregisterTestFileRef", "aiServiceUnregisterTestBuildFile",
    "aiStatusControllerFileRef", "aiStatusControllerBuildFile",
    "purpleServicePluginFileRef", "purpleServicePluginBuildFile",
    "purpleServiceUninstallTestFileRef", "purpleServiceUninstallTestBuildFile",
    "sclViewPluginFileRef", "sclViewPluginBuildFile",
    "sclViewUninstallTestFileRef", "sclViewUninstallTestBuildFile",

    # Frameworks
    "xctestFwkRef", "xctestFwkBuildFile",
    "aiutilitiesFwkRef", "aiutilitiesFwkBuildFile",
    "cocoaFwkRef", "cocoaFwkBuildFile",
    "userNotificationsFwkRef", "userNotificationsFwkBuildFile",
    "uniformTypeIdentifiersFwkRef", "uniformTypeIdentifiersFwkBuildFile",
]:
    H[k] = uid(k)


# ── SHIM_MANIFEST ─────────────────────────────────────────────────────
# Canonical inventory of the shim header dirs that stand in for AdiumY.framework
# (CI builds no framework; <AdiumY/...> resolves via Tests/CoverageHost/AdiumY etc.).
#
# Each entry is "<ns>/<header>" -> one of:
#   ("symlink", "<repo-relative real header>") — the shim file must be a symlink
#        resolving to that real header (checked-in, so it tracks upstream exactly)
#   ("stub", None)                             — a committed shadow stub (regular file);
#        the real header is too heavy to pull into the harness
#
# The generator hard-fails on every run if any entry is missing/wrong, if a shim dir
# contains an unlisted file, or if a wired TU imports a <ns/header> not listed here.
SHIM_NAMESPACES = ("AdiumY", "AdiumYLibpurple", "libpurple")
SHIM_MANIFEST = {
    # AdiumY ── symlink -> real header
    "AdiumY/AIAbstractAccount.h": ("symlink", "Frameworks/Adium/Source/AIAbstractAccount.h"),
    "AdiumY/AIAbstractListController.h": ("symlink", "Frameworks/Adium/Source/AIAbstractListController.h"),
    "AdiumY/AIAbstractListObjectMenu.h": ("symlink", "Frameworks/Adium/Source/AIAbstractListObjectMenu.h"),
    "AdiumY/AIAccount.h": ("symlink", "Frameworks/Adium/Source/AIAccount.h"),
    "AdiumY/AIAccountControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIAccountControllerProtocol.h"),
    "AdiumY/AIAccountMenu.h": ("symlink", "Frameworks/Adium/Source/AIAccountMenu.h"),
    "AdiumY/AIAccountViewController.h": ("symlink", "Frameworks/Adium/Source/AIAccountViewController.h"),
    "AdiumY/AIAdiumProtocol.h": ("symlink", "Frameworks/Adium/Source/AIAdiumProtocol.h"),
    "AdiumY/AIAdvancedPreferencePane.h": ("symlink", "Frameworks/Adium/Source/AIAdvancedPreferencePane.h"),
    "AdiumY/AIChat.h": ("symlink", "Frameworks/Adium/Source/AIChat.h"),
    "AdiumY/AIChatControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIChatControllerProtocol.h"),
    "AdiumY/AIContactControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIContactControllerProtocol.h"),
    "AdiumY/AIContactList.h": ("symlink", "Frameworks/Adium/Source/AIContactList.h"),
    "AdiumY/AIContactMenu.h": ("symlink", "Frameworks/Adium/Source/AIContactMenu.h"),
    "AdiumY/AIContactObserverManager.h": ("symlink", "Frameworks/Adium/Source/AIContactObserverManager.h"),
    "AdiumY/AIContentContext.h": ("symlink", "Frameworks/Adium/Source/AIContentContext.h"),
    "AdiumY/AIContentControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIContentControllerProtocol.h"),
    "AdiumY/AIContentEvent.h": ("symlink", "Frameworks/Adium/Source/AIContentEvent.h"),
    "AdiumY/AIContentNotification.h": ("symlink", "Frameworks/Adium/Source/AIContentNotification.h"),
    "AdiumY/AIContentObject.h": ("symlink", "Frameworks/Adium/Source/AIContentObject.h"),
    "AdiumY/AIContentStatus.h": ("symlink", "Frameworks/Adium/Source/AIContentStatus.h"),
    "AdiumY/AIContentTyping.h": ("symlink", "Frameworks/Adium/Source/AIContentTyping.h"),
    "AdiumY/AIControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIControllerProtocol.h"),
    "AdiumY/AIDockControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIDockControllerProtocol.h"),
    "AdiumY/AIEditStateWindowController.h": ("symlink", "Frameworks/Adium/Source/AIEditStateWindowController.h"),
    "AdiumY/AIHTMLDecoder.h": ("symlink", "Frameworks/Adium/Source/AIHTMLDecoder.h"),
    "AdiumY/AIHTTPDownloadValidation.h": ("symlink", "Frameworks/Adium/Source/AIHTTPDownloadValidation.h"),
    "AdiumY/AIInterfaceControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIInterfaceControllerProtocol.h"),
    "AdiumY/AIListContact.h": ("symlink", "Frameworks/Adium/Source/AIListContact.h"),
    "AdiumY/AIListGroup.h": ("symlink", "Frameworks/Adium/Source/AIListGroup.h"),
    "AdiumY/AIListObject.h": ("symlink", "Frameworks/Adium/Source/AIListObject.h"),
    "AdiumY/AIListOutlineView+Drawing.h": ("symlink", "Frameworks/Adium/Source/AIListOutlineView+Drawing.h"),
    "AdiumY/AIMenuControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIMenuControllerProtocol.h"),
    "AdiumY/AIMessageEntryTextView.h": ("symlink", "Frameworks/Adium/Source/AIMessageEntryTextView.h"),
    "AdiumY/AIMetaContact.h": ("symlink", "Frameworks/Adium/Source/AIMetaContact.h"),
    "AdiumY/AIModularPane.h": ("symlink", "Frameworks/Adium/Source/AIModularPane.h"),
    "AdiumY/AIPasswordPromptController.h": ("symlink", "Source/AIPasswordPromptController.h"),
    "AdiumY/AIPlugin.h": ("symlink", "Frameworks/Adium/Source/AIPlugin.h"),
    "AdiumY/AIPreferenceControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIPreferenceControllerProtocol.h"),
    "AdiumY/AIPreferencePane.h": ("symlink", "Frameworks/Adium/Source/AIPreferencePane.h"),
    "AdiumY/AISCLViewPlugin.h": ("symlink", "Source/AISCLViewPlugin.h"),
    "AdiumY/AIService.h": ("symlink", "Frameworks/Adium/Source/AIService.h"),
    "AdiumY/AIServiceIcons.h": ("symlink", "Frameworks/Adium/Source/AIServiceIcons.h"),
    "AdiumY/AISharedAdium.h": ("symlink", "Frameworks/Adium/Source/AISharedAdium.h"),
    "AdiumY/AISocialNetworkingStatusMenu.h": ("symlink", "Frameworks/Adium/Source/AISocialNetworkingStatusMenu.h"),
    "AdiumY/AISortController.h": ("symlink", "Frameworks/Adium/Source/AISortController.h"),
    "AdiumY/AISoundSet.h": ("symlink", "Frameworks/Adium/Source/AISoundSet.h"),
    "AdiumY/AIStatus.h": ("symlink", "Frameworks/Adium/Source/AIStatus.h"),
    "AdiumY/AIStatusController.h": ("symlink", "Source/AIStatusController.h"),
    "AdiumY/AIStatusControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIStatusControllerProtocol.h"),
    "AdiumY/AIStatusDefines.h": ("symlink", "Frameworks/Adium/Source/AIStatusDefines.h"),
    "AdiumY/AIStatusIcons.h": ("symlink", "Frameworks/Adium/Source/AIStatusIcons.h"),
    "AdiumY/AIStatusItem.h": ("symlink", "Frameworks/Adium/Source/AIStatusItem.h"),
    "AdiumY/AIStatusMenu.h": ("symlink", "Frameworks/Adium/Source/AIStatusMenu.h"),
    "AdiumY/AIToolbarControllerProtocol.h": ("symlink", "Frameworks/Adium/Source/AIToolbarControllerProtocol.h"),
    "AdiumY/AIWindowController.h": ("symlink", "Frameworks/Adium/Source/AIWindowController.h"),
    "AdiumY/AIXMLElement.h": ("symlink", "Frameworks/Adium/Source/AIXMLElement.h"),
    "AdiumY/AIXtraInfo.h": ("symlink", "Frameworks/Adium/Source/AIXtraInfo.h"),
    "AdiumY/ESDebugAILog.h": ("symlink", "Frameworks/Adium/Source/ESDebugAILog.h"),
    "AdiumY/ESObjectWithProperties.h": ("symlink", "Frameworks/Adium/Source/ESObjectWithProperties.h"),
    "AdiumY/ESUserIconHandlingPlugin.h": ("symlink", "Source/ESUserIconHandlingPlugin.h"),
    "AdiumY/SS_PreferencePaneProtocol.h": ("symlink", "Frameworks/Adium/Source/SS_PreferencePaneProtocol.h"),

    # AdiumY ── shadow stub (regular file)
    "AdiumY/AIActionDetailsPane.h": ("stub", None),
    "AdiumY/AIApplescriptabilityControllerProtocol.h": ("stub", None),
    "AdiumY/AIContactAlertsControllerProtocol.h": ("stub", None),
    "AdiumY/AIContentMessage.h": ("stub", None),
    "AdiumY/AIEmoticon.h": ("stub", None),
    "AdiumY/AIEmoticonControllerProtocol.h": ("stub", None),
    "AdiumY/AIListOutlineView.h": ("stub", None),
    "AdiumY/AIPathUtilities.h": ("stub", None),
    "AdiumY/AISoundControllerProtocol.h": ("stub", None),
    "AdiumY/ESFileTransfer.h": ("stub", None),
    "AdiumY/KNShelfSplitView.h": ("stub", None),

    # AdiumYLibpurple
    "AdiumYLibpurple/CBPurpleAccount.h": ("stub", None),
    "AdiumYLibpurple/PurpleCommon.h": ("stub", None),
    "AdiumYLibpurple/SLPurpleCocoaAdapter.h": ("symlink", "Plugins/Purple Service/SLPurpleCocoaAdapter.h"),

    # libpurple
    "libpurple/libpurple.h": ("stub", None),
}


def _validate_shim_manifest(repo_root):
    """Every SHIM_MANIFEST entry must exist on disk with the declared kind, and every shim dir
    file must be listed. Hard error (SystemExit) on any drift — the generator refuses to emit
    a project built against a shim tree that no longer matches the manifest."""
    errors = []
    for ns_hdr, (kind, target) in sorted(SHIM_MANIFEST.items()):
        p = os.path.join(PROJECT_DIR, *ns_hdr.split("/"))
        if not os.path.lexists(p):
            errors.append(f"missing {ns_hdr} (declared {kind})")
            continue
        if kind == "symlink":
            if not os.path.islink(p):
                errors.append(f"{ns_hdr} should be a symlink -> {target}, but is a "
                              f"{'regular file' if os.path.isfile(p) else 'other'}")
            else:
                resolved = os.path.relpath(os.path.realpath(p), repo_root)
                if resolved != target:
                    errors.append(f"{ns_hdr} resolves to {resolved}, expected {target}")
        else:  # stub
            if os.path.islink(p):
                errors.append(f"{ns_hdr} should be a regular file (stub), but is a symlink")
    # Reverse drift: a file present in a shim dir but not in the manifest.
    for ns in SHIM_NAMESPACES:
        d = os.path.join(PROJECT_DIR, ns)
        if not os.path.isdir(d):
            errors.append(f"shim namespace dir missing: {ns}")
            continue
        for name in os.listdir(d):
            if f"{ns}/{name}" not in SHIM_MANIFEST:
                errors.append(f"unlisted shim file present: {ns}/{name}")
    if errors:
        raise SystemExit("SHIM_MANIFEST VIOLATION:\n  " + "\n  ".join(sorted(errors)))


def _validate_wired_imports(repo_root):
    """Every <ns/header> angle import made by a wired repo TU must be listed in SHIM_MANIFEST.
    A wired TU importing an unlisted shim header means the shim dir drifted — hard error."""
    import re
    angle = re.compile(r"#import\s*<([^>/]+)/([^>]+)>")
    errors = []
    for ref in objects.values():
        if ref.get("isa") != "PBXFileReference":
            continue
        if ref.get("lastKnownFileType") != "sourcecode.c.objc":
            continue
        path = ref.get("path", "")
        if not path.startswith("../../"):
            continue  # in-project files (main.m, CoverageHostTest.m) aren't repo TUs
        rel = path[len("../../"):]
        src = os.path.join(repo_root, rel)
        if not os.path.isfile(src):
            continue  # a missing source is a build error, not a manifest concern
        with open(src, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for m in angle.finditer(text):
            ns, hdr = m.group(1), m.group(2)
            if ns in SHIM_NAMESPACES and f"{ns}/{hdr}" not in SHIM_MANIFEST:
                errors.append(f"{rel} imports <{ns}/{hdr}> not in SHIM_MANIFEST")
    if errors:
        raise SystemExit("SHIM_MANIFEST VIOLATION (unlisted wired import):\n  "
                         + "\n  ".join(sorted(set(errors))))


# Validate the shim tree up front (independent of the project model) so a drifted
# shim dir fails the run before any codegen.
_validate_shim_manifest(REPO_ROOT)

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
                     H["ezvXmlNodeFileRef"], H["ezvXmlNodeHeaderRef"],
                     H["ezvXmlNodeTestFileRef"], H["ezvFolderCleanupTestFileRef"],
                     H["ezvXmlPropsTestFileRef"],
                     H["ezvOutgoingFileRef"], H["ezvOutgoingHeaderRef"],
                     H["ezvOutgoingDepthCapTestFileRef"],
                     H["ezvOutgoingUTF8TestFileRef"],
                     H["httpserverStubFileRef"],
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
                     H["variantTeardownTestFileRef"],
                     H["contactStatusEventsPluginFileRef"],
                     H["contactStatusEventsUninstallTestFileRef"],
                     H["dualWindowPluginFileRef"],
                     H["dualWindowUninstallTestFileRef"],
                     H["bonjourPluginFileRef"],
                     H["bonjourUninstallTestFileRef"],
                     H["adiumServicesFileRef"],
                     H["adiumServicesUnregisterTestFileRef"],
                     H["aiServiceFileRef"],
                     H["aiServiceUnregisterTestFileRef"],
                     H["aiStatusControllerFileRef"],
                     H["purpleServicePluginFileRef"],
                     H["purpleServiceUninstallTestFileRef"],
                     H["sclViewPluginFileRef"],
                     H["sclViewUninstallTestFileRef"]],
        "name": "Sources",
        "sourceTree": "<group>",
    },
    H["frameworksGroup"]: {
        "isa": "PBXGroup",
        "children": [H["xctestFwkRef"], H["userNotificationsFwkRef"], H["uniformTypeIdentifiersFwkRef"]],
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
    H["ezvXmlNodeFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Bonjour/libezv/Private Classes/AWEzvXMLNode.m",
        "sourceTree": "<group>",
    },
    H["ezvXmlNodeHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/Bonjour/libezv/Private Classes/AWEzvXMLNode.h",
        "sourceTree": "<group>",
    },
    H["ezvXmlNodeTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAWEzvXMLNodeSerializationDepth.m",
        "sourceTree": "<group>",
    },
    H["ezvFolderCleanupTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestEKEzvIncomingFileTransferFolderCleanup.m",
        "sourceTree": "<group>",
    },
    H["ezvXmlPropsTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAWEzvXMLNodeSerializationProperties.m",
        "sourceTree": "<group>",
    },
    H["ezvOutgoingFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvOutgoingFileTransfer.m",
        "sourceTree": "<group>",
    },
    H["ezvOutgoingHeaderRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.h",
        "path": "../../Plugins/Bonjour/libezv/Classes/EKEzvOutgoingFileTransfer.h",
        "sourceTree": "<group>",
    },
    H["ezvOutgoingDepthCapTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestEKEzvOutgoingFileTransferDepthCap.m",
        "sourceTree": "<group>",
    },
    H["ezvOutgoingUTF8TestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestEKEzvOutgoingFileTransferUTF8Length.m",
        "sourceTree": "<group>",
    },
    H["httpserverStubFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/HTTPServerStub.m",
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
    H["contactStatusEventsPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIContactStatusEventsPlugin.m",
        "sourceTree": "<group>",
    },
    H["contactStatusEventsUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIContactStatusEventsPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["dualWindowPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Dual Window Interface/AIDualWindowInterfacePlugin.m",
        "sourceTree": "<group>",
    },
    H["dualWindowUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIDualWindowInterfacePluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["bonjourPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Bonjour/AWBonjourPlugin.m",
        "sourceTree": "<group>",
    },
    H["bonjourUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAWBonjourPluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["adiumServicesFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AdiumServices.m",
        "sourceTree": "<group>",
    },
    H["adiumServicesUnregisterTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAdiumServicesUnregister.m",
        "sourceTree": "<group>",
    },

    # Plugin-uninstall teardown batch 6 (#240-#242): AIService/AIStatusController + Purple Service + SCLView plugins
    H["aiServiceFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Frameworks/Adium/Source/AIService.m",
        "sourceTree": "<group>",
    },
    H["aiServiceUnregisterTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAIServiceUnregister.m",
        "sourceTree": "<group>",
    },
    H["aiStatusControllerFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AIStatusController.m",
        "sourceTree": "<group>",
    },
    H["purpleServicePluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Plugins/Purple Service/CBPurpleServicePlugin.m",
        "sourceTree": "<group>",
    },
    H["purpleServiceUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestCBPurpleServicePluginUninstall.m",
        "sourceTree": "<group>",
    },
    H["sclViewPluginFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../Source/AISCLViewPlugin.m",
        "sourceTree": "<group>",
    },
    H["sclViewUninstallTestFileRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.c.objc",
        "path": "../../UnitTests/TestAISCLViewPluginUninstall.m",
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

    # UniformTypeIdentifiers.framework — EKEzvOutgoingFileTransfer.m sends to UTType
    # (class sends via mimeTypeForPath:), which need the framework linked into the test bundle.
    H["uniformTypeIdentifiersFwkRef"]: {
        "isa": "PBXFileReference",
        "lastKnownFileType": "wrapper.framework",
        "name": "UniformTypeIdentifiers.framework",
        "path": "/System/Library/Frameworks/UniformTypeIdentifiers.framework",
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
                  H["ezvXmlNodeBuildFile"], H["ezvXmlNodeTestBuildFile"],
                  H["ezvFolderCleanupTestBuildFile"],
                  H["ezvXmlPropsTestBuildFile"],
                  H["ezvOutgoingBuildFile"],
                  H["ezvOutgoingDepthCapTestBuildFile"],
                  H["ezvOutgoingUTF8TestBuildFile"],
                  H["httpserverStubBuildFile"],
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
                  H["variantTeardownTestBuildFile"],
                  H["contactStatusEventsPluginBuildFile"],
                  H["contactStatusEventsUninstallTestBuildFile"],
                  H["dualWindowPluginBuildFile"],
                  H["dualWindowUninstallTestBuildFile"],
                  H["bonjourPluginBuildFile"],
                  H["bonjourUninstallTestBuildFile"],
                  H["adiumServicesBuildFile"],
                  H["adiumServicesUnregisterTestBuildFile"],
                  H["aiServiceBuildFile"],
                  H["aiServiceUnregisterTestBuildFile"],
                  H["aiStatusControllerBuildFile"],
                  H["purpleServicePluginBuildFile"],
                  H["purpleServiceUninstallTestBuildFile"],
                  H["sclViewPluginBuildFile"],
                  H["sclViewUninstallTestBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },
    H["testFrameworksPhase"]: {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["xctestFwkBuildFile"], H["aiutilitiesFwkBuildFile"],
                  H["cocoaFwkBuildFile"], H["userNotificationsFwkBuildFile"],
                  H["uniformTypeIdentifiersFwkBuildFile"]],
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
    H["ezvXmlNodeBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["ezvXmlNodeFileRef"]},
    H["ezvXmlNodeTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["ezvXmlNodeTestFileRef"]},
    H["ezvFolderCleanupTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["ezvFolderCleanupTestFileRef"]},
    H["ezvXmlPropsTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["ezvXmlPropsTestFileRef"]},
    H["ezvOutgoingBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["ezvOutgoingFileRef"]},
    H["ezvOutgoingDepthCapTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["ezvOutgoingDepthCapTestFileRef"]},
    H["ezvOutgoingUTF8TestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["ezvOutgoingUTF8TestFileRef"]},
    H["httpserverStubBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["httpserverStubFileRef"]},
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
    H["contactStatusEventsPluginBuildFile"]:       {"isa": "PBXBuildFile", "fileRef": H["contactStatusEventsPluginFileRef"]},
    H["contactStatusEventsUninstallTestBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["contactStatusEventsUninstallTestFileRef"]},
    H["dualWindowPluginBuildFile"]:                {"isa": "PBXBuildFile", "fileRef": H["dualWindowPluginFileRef"]},
    H["dualWindowUninstallTestBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["dualWindowUninstallTestFileRef"]},
    H["bonjourPluginBuildFile"]:                   {"isa": "PBXBuildFile", "fileRef": H["bonjourPluginFileRef"]},
    H["bonjourUninstallTestBuildFile"]:            {"isa": "PBXBuildFile", "fileRef": H["bonjourUninstallTestFileRef"]},
    H["adiumServicesBuildFile"]:                   {"isa": "PBXBuildFile", "fileRef": H["adiumServicesFileRef"]},
    H["adiumServicesUnregisterTestBuildFile"]:     {"isa": "PBXBuildFile", "fileRef": H["adiumServicesUnregisterTestFileRef"]},
    H["aiServiceBuildFile"]:                       {"isa": "PBXBuildFile", "fileRef": H["aiServiceFileRef"]},
    H["aiServiceUnregisterTestBuildFile"]:         {"isa": "PBXBuildFile", "fileRef": H["aiServiceUnregisterTestFileRef"]},
    H["aiStatusControllerBuildFile"]:              {"isa": "PBXBuildFile", "fileRef": H["aiStatusControllerFileRef"]},
    H["purpleServicePluginBuildFile"]:             {"isa": "PBXBuildFile", "fileRef": H["purpleServicePluginFileRef"]},
    H["purpleServiceUninstallTestBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["purpleServiceUninstallTestFileRef"]},
    H["sclViewPluginBuildFile"]:                   {"isa": "PBXBuildFile", "fileRef": H["sclViewPluginFileRef"]},
    H["sclViewUninstallTestBuildFile"]:            {"isa": "PBXBuildFile", "fileRef": H["sclViewUninstallTestFileRef"]},
    H["userNotificationsFwkBuildFile"]:      {"isa": "PBXBuildFile", "fileRef": H["userNotificationsFwkRef"]},
    H["uniformTypeIdentifiersFwkBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["uniformTypeIdentifiersFwkRef"]},

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
                "$(SRCROOT)/../../Plugins/Bonjour",
                "$(SRCROOT)/../../Plugins/Bonjour/libezv/Classes",
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Other Sources"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Private Classes"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Simple HTTP Server"',
                '"$(SRCROOT)/../../Plugins/Do Nothing Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Open Message Window Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Send Message Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Dock Icon Badging"',
                '"$(SRCROOT)/../../Plugins/Purple Service"',
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
                "$(SRCROOT)/../../Plugins/Bonjour",
                "$(SRCROOT)/../../Plugins/Bonjour/libezv/Classes",
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Other Sources"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Private Classes"',
                '"$(SRCROOT)/../../Plugins/Bonjour/libezv/Simple HTTP Server"',
                '"$(SRCROOT)/../../Plugins/Do Nothing Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Open Message Window Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Send Message Contact Alert"',
                '"$(SRCROOT)/../../Plugins/Dock Icon Badging"',
                '"$(SRCROOT)/../../Plugins/Purple Service"',
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

# Every wired TU's <ns/header> imports must be listed in SHIM_MANIFEST — the shim dir
# and the project model are one source of truth.
_validate_wired_imports(REPO_ROOT)


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
