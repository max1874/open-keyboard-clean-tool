.PHONY: app release icon test

MODULE_CACHE := $(CURDIR)/.build/clang-module-cache

app:
	./scripts/build-app.sh

# A signed, notarized, stapled DMG. Runs on the maintainer's machine, never in
# CI. The pipeline lives in the account-level tool (github.com/max1874/
# apple-developer, `asc`); this repo only builds the .app, and `asc notarize`
# takes over from build/OpenKeyboardCleanTool.app.
release:
	asc notarize open-keyboard-clean-tool

icon:
	./scripts/build-icon.sh

test:
	CLANG_MODULE_CACHE_PATH="$(MODULE_CACHE)" SWIFTPM_MODULECACHE_OVERRIDE="$(MODULE_CACHE)" swift test --disable-sandbox
