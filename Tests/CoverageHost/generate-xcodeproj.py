#!/usr/bin/env python3
"""Generate CoverageHost.xcodeproj — XCTest host + test bundle for AIUtilities.framework coverage.

Creates two targets:
  1. CoverageHost     — minimal Cocoa app serving as the test host
  2. CoverageHostTests — XCTest bundle injected into CoverageHost

Both are in a standalone project so we don't touch AIUtilities.xcodeproj.
"""

import uuid, plistlib, os

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
XCODE_PROJ = os.path.join(PROJECT_DIR, "CoverageHost.xcodeproj")
SCHEME_DIR = os.path.join(XCODE_PROJ, "xcshareddata", "xcschemes")
AIUTILITIES_PATH = "../../build/DerivedData/Build/Products/Debug"


def uid() -> str:
    return uuid.uuid4().hex.upper()[:24]


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

    # Frameworks
    "xctestFwkRef", "xctestFwkBuildFile",
    "aiutilitiesFwkRef", "aiutilitiesFwkBuildFile",
    "cocoaFwkRef", "cocoaFwkBuildFile",
]:
    H[k] = uid()


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
                     H["testFileRef"], H["testInfoPlistRef"]],
        "name": "Sources",
        "sourceTree": "<group>",
    },
    H["frameworksGroup"]: {
        "isa": "PBXGroup",
        "children": [H["xctestFwkRef"]],
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
        "files": [H["testBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },
    H["testFrameworksPhase"]: {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": 2147483647,
        "files": [H["xctestFwkBuildFile"], H["aiutilitiesFwkBuildFile"]],
        "runOnlyForDeploymentPostprocessing": False,
    },

    # ── Build Files ─────────────────────────────────────────────
    H["hostMainBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["hostMainFileRef"]},
    H["testBuildFile"]:    {"isa": "PBXBuildFile", "fileRef": H["testFileRef"]},
    H["xctestFwkBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["xctestFwkRef"]},
    H["aiutilitiesFwkBuildFile"]: {"isa": "PBXBuildFile", "fileRef": H["aiutilitiesFwkRef"]},
    H["cocoaFwkBuildFile"]:  {"isa": "PBXBuildFile", "fileRef": H["cocoaFwkRef"]},

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
            "GCC_PREFIX_HEADER": "",
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
            "GCC_PREFIX_HEADER": "",
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
print(f"  1. Build AIUtilities: xcodebuild -project Frameworks/AIUtilities/AIUtilities.xcodeproj -configuration Debug -derivedDataPath build/DerivedData")
print("  2. Run tests:         xcodebuild test -project Tests/CoverageHost/CoverageHost.xcodeproj -scheme CoverageHost -configuration Debug -derivedDataPath build/DerivedData -enableCodeCoverage YES")
