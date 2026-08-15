.PHONY: generate test test-swift test-web build-web

generate:
	xcodegen generate

test-swift:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path packages/core
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path packages/collectors
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path packages/sync

test-web:
	npm --workspace apps/web test

build-web:
	npm --workspace apps/web run build

test: test-swift test-web
