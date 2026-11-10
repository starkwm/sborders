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

.DEFAULT_GOAL := build
.PHONY: build release format lint test clean
