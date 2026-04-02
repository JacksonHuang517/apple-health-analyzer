#!/usr/bin/env python3
"""Generate a minimal Xcode project for HealthAnalyzerApp without XcodeGen."""

import os
import uuid
import pathlib

PROJECT_NAME = "HealthAnalyzerApp"
BUNDLE_ID = "com.jacksonhuang.healthanalyzer"

def uid():
    return uuid.uuid4().hex[:24].upper()

class PBXProject:
    def __init__(self):
        self.objects = {}
        self.root_id = uid()
        self.main_group_id = uid()
        self.products_group_id = uid()
        self.app_product_id = uid()
        self.target_id = uid()
        self.build_config_list_proj = uid()
        self.build_config_list_target = uid()
        self.debug_proj = uid()
        self.release_proj = uid()
        self.debug_target = uid()
        self.release_target = uid()
        self.sources_phase = uid()
        self.resources_phase = uid()
        self.frameworks_phase = uid()
        self.healthkit_framework_id = uid()
        self.healthkit_file_id = uid()

    def generate(self, source_dir):
        source_files = []
        resource_files = []

        src_dir = pathlib.Path(source_dir) / PROJECT_NAME

        for root, dirs, files in os.walk(src_dir):
            rel = pathlib.Path(root).relative_to(src_dir)
            for f in files:
                full = pathlib.Path(root) / f
                rel_path = str(rel / f)

                if f.endswith('.swift'):
                    fid = uid()
                    bfid = uid()
                    source_files.append((fid, bfid, f, str(pathlib.Path(PROJECT_NAME) / rel_path)))
                elif f.endswith('.html'):
                    fid = uid()
                    bfid = uid()
                    resource_files.append((fid, bfid, f, str(pathlib.Path(PROJECT_NAME) / rel_path)))

        # Collect groups
        swift_refs = "\n".join(f"\t\t\t\t{fid} /* {name} */," for fid, _, name, _ in source_files)
        resource_refs = "\n".join(f"\t\t\t\t{fid} /* {name} */," for fid, _, name, _ in resource_files)

        src_build_refs = "\n".join(f"\t\t\t\t{bfid} /* {name} in Sources */," for _, bfid, name, _ in source_files)
        res_build_refs = "\n".join(f"\t\t\t\t{bfid} /* {name} in Resources */," for _, bfid, name, _ in resource_files)

        # Groups
        sources_group = uid()
        views_group = uid()
        hk_group = uid()
        resources_group = uid()
        assets_group = uid()

        # Info.plist and entitlements file refs
        info_plist_id = uid()
        entitlements_id = uid()

        all_file_refs = ""
        all_build_files = ""

        for fid, bfid, name, path in source_files:
            all_file_refs += f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT; }};\n'
            all_build_files += f'\t\t{bfid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};\n'

        for fid, bfid, name, path in resource_files:
            ftype = "text.html" if name.endswith('.html') else "text.json"
            all_file_refs += f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{path}"; sourceTree = SOURCE_ROOT; }};\n'
            all_build_files += f'\t\t{bfid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};\n'

        # Assets.xcassets
        assets_id = uid()
        assets_build_id = uid()
        all_file_refs += f'\t\t{assets_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "{PROJECT_NAME}/Assets.xcassets"; sourceTree = SOURCE_ROOT; }};\n'
        all_build_files += f'\t\t{assets_build_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_id} /* Assets.xcassets */; }};\n'

        # Info.plist
        all_file_refs += f'\t\t{info_plist_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "{PROJECT_NAME}/Info.plist"; sourceTree = SOURCE_ROOT; }};\n'
        # Entitlements
        all_file_refs += f'\t\t{entitlements_id} /* {PROJECT_NAME}.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "{PROJECT_NAME}/{PROJECT_NAME}.entitlements"; sourceTree = SOURCE_ROOT; }};\n'

        # HealthKit framework
        all_file_refs += f'\t\t{self.healthkit_file_id} /* HealthKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = HealthKit.framework; path = System/Library/Frameworks/HealthKit.framework; sourceTree = SDKROOT; }};\n'
        all_build_files += f'\t\t{self.healthkit_framework_id} /* HealthKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {self.healthkit_file_id} /* HealthKit.framework */; }};\n'

        # Product
        all_file_refs += f'\t\t{self.app_product_id} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'

        all_children = "\n".join(f"\t\t\t\t{fid} /* {name} */," for fid, _, name, _ in source_files + resource_files)

        pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{all_build_files}/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{all_file_refs}/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{self.frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{self.healthkit_framework_id} /* HealthKit.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{self.main_group_id} = {{
			isa = PBXGroup;
			children = (
{all_children}
				{assets_id} /* Assets.xcassets */,
				{info_plist_id} /* Info.plist */,
				{entitlements_id} /* {PROJECT_NAME}.entitlements */,
				{self.healthkit_file_id} /* HealthKit.framework */,
				{self.products_group_id} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{self.products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{self.app_product_id} /* {PROJECT_NAME}.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{self.target_id} /* {PROJECT_NAME} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {self.build_config_list_target} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */;
			buildPhases = (
				{self.sources_phase} /* Sources */,
				{self.resources_phase} /* Resources */,
				{self.frameworks_phase} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = {PROJECT_NAME};
			productName = {PROJECT_NAME};
			productReference = {self.app_product_id} /* {PROJECT_NAME}.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{self.root_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {self.build_config_list_proj} /* Build configuration list for PBXProject "{PROJECT_NAME}" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				"zh-Hans",
				Base,
			);
			mainGroup = {self.main_group_id};
			productRefGroup = {self.products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{self.target_id} /* {PROJECT_NAME} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{self.resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{res_build_refs}
				{assets_build_id} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{self.sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{src_build_refs}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{self.debug_proj} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{self.release_proj} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{self.debug_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = {PROJECT_NAME}/{PROJECT_NAME}.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = {PROJECT_NAME}/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{self.release_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = {PROJECT_NAME}/{PROJECT_NAME}.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = {PROJECT_NAME}/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{self.build_config_list_proj} /* Build configuration list for PBXProject "{PROJECT_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{self.debug_proj} /* Debug */,
				{self.release_proj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{self.build_config_list_target} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{self.debug_target} /* Debug */,
				{self.release_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {self.root_id} /* Project object */;
}}
"""
        return pbxproj


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    proj = PBXProject()
    content = proj.generate(base)

    xcodeproj_dir = os.path.join(base, f"{PROJECT_NAME}.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)

    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print(f"✓ 已生成 {pbxproj_path}")
    print(f"  打开项目: open {xcodeproj_dir}")


if __name__ == "__main__":
    main()
