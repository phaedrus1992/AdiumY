PREFIX?=
BUILD_DIR?=$(shell defaults read com.apple.Xcode PBXProductDirectory 2> /dev/null)

ifeq ($(strip $(BUILD_DIR)),)
	BUILD_DIR=build
endif

DEFAULT_BUILDCONFIGURATION=Release-Debug

BUILDCONFIGURATION?=$(DEFAULT_BUILDCONFIGURATION)

# Choose xcodebuild 
# currently used for build machines
# XCODEBUILD ?= $(shell if test -d /Xcode4; then echo "/Xcode4/usr/bin/xcodebuild"; else echo "xcodebuild"; fi)
XCODEBUILD ?= xcodebuild
#

CP=ditto --rsrc
RM=rm

.PHONY: all adium clean localizable-strings latest test astest install format format-check coverage-check setup-blame install-hooks xcodeproj

adium:
	$(XCODEBUILD) -version
	$(XCODEBUILD) -project Adium.xcodeproj -configuration $(BUILDCONFIGURATION) CFLAGS="$(ADIUM_CFLAGS)" $(ADIUM_NIGHTLY_FLAGS) build

test:
	$(XCODEBUILD) -version
	$(XCODEBUILD) test -project Tests/CoverageHost/CoverageHost.xcodeproj -scheme CoverageHost -configuration Debug -sdk macosx -derivedDataPath build/DerivedData -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
astest:
	osascript unittest\ runner.applescript | tr '\r' '\n'

install:
	mkdir -p ~/Applications
	cp -R build/$(BUILDCONFIGURATION)/AdiumY.app ~/Applications/

clean:
	$(XCODEBUILD) -version
	$(XCODEBUILD) -project Adium.xcodeproj -configuration $(BUILDCONFIGURATION) $(ADIUM_NIGHTLY_FLAGS) clean

localizable-strings:
	mkdir tmp || true
	mv "Plugins/Purple Service" tmp
	genstrings -o Resources/en.lproj -s AILocalizedString Source/*.m Source/*.h Plugins/*/*.h Plugins/*/*.m Plugins/*/*/*.h Plugins/*/*/*.m
	genstrings -o tmp/Purple\ Service/Resources/en.lproj -s AILocalizedString tmp/Purple\ Service/*.h tmp/Purple\ Service/*.m
	genstrings -o Frameworks/AIUtilities\ Framework/Resources/en.lproj -s AILocalizedString Frameworks/AIUtilities\ Framework/Source/*.h Frameworks/AIUtilities\ Framework/Source/*.m
	mkdir -p Frameworks/Adium/Resources/en.lproj
	genstrings -o Frameworks/Adium/Resources/en.lproj -s AILocalizedString Frameworks/Adium/Source/*.m Frameworks/Adium/Source/*.h
	mv "tmp/Purple Service" Plugins
	rmdir tmp || true

# -- Quality enforcement targets --

format:
	scripts/format-check.sh --list | xargs -0 clang-format -i

format-check:
	scripts/format-check.sh

coverage-check:
	scripts/coverage-check.sh

setup-blame:
	git config blame.ignoreRevsFile .git-blame-ignore-revs
	@echo "git blame configured to skip the bulk format commit."

install-hooks:
	@mkdir -p .git/hooks
	@cat > .git/hooks/pre-commit <<- 'HOOK'
	#!/bin/bash
	# clang-format pre-commit hook — dry-run on staged ObjC files
	set -euo pipefail
	git diff --cached --name-only --diff-filter=ACM | grep -E '\.(m|mm|h|c|cpp)$$' | \
	  while IFS= read -r f; do
	    if ! clang-format --dry-run --Werror "$$f" 2>/dev/null; then
	      echo "FAIL: $$f does not match .clang-format style"
	      echo "Run 'make format' to fix, or 'git commit --no-verify' to bypass"
	      exit 1
	    fi
	  done
	HOOK
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed. Run 'make format' to reformat all files."

# Regenerate the CoverageHost test project + the repo-root clangd compilation
# database (compile_commands.json) from the single source of truth.
xcodeproj:
	python3 Tests/CoverageHost/generate-xcodeproj.py

latest:
	hg pull -u
	make adium
