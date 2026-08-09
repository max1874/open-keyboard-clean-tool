.PHONY: app dmg icon test

MODULE_CACHE := $(CURDIR)/.build/clang-module-cache

app:
	./scripts/build-app.sh

dmg:
	./scripts/build-dmg.sh

icon:
	./scripts/build-icon.sh

test:
	CLANG_MODULE_CACHE_PATH="$(MODULE_CACHE)" SWIFTPM_MODULECACHE_OVERRIDE="$(MODULE_CACHE)" swift test --disable-sandbox
