VERSION_TMPL=Sources/Sborders/Version.swift.tmpl
VERSION_FILE=Sources/Sborders/Version.swift

build:
	@swift build

release:
	@swift build --configuration release

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint --strict -r Sources Tests Package.swift

test:
	@swift test --parallel --disable-xctest

clean:
	@swift package clean

bump_version:
	@test -n "$(NEW_VERSION)" || (echo 'Set NEW_VERSION' >&2; exit 1)
	@sed 's/__VERSION__/$(NEW_VERSION)/g' $(VERSION_TMPL) > $(VERSION_FILE)

.DEFAULT_GOAL := build
.PHONY: build release format lint test clean bump_version
