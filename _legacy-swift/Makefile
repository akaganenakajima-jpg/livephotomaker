PROJECT := LivePhotoMaker
SCHEME  := LivePhotoMaker
DESTINATION := "platform=iOS Simulator,name=iPhone 15,OS=latest"
CONFIGURATION := Debug

.PHONY: help gen build test lint format clean ci

help:
	@echo "Targets:"
	@echo "  gen     - Generate Xcode project from project.yml (requires xcodegen)"
	@echo "  build   - xcodebuild build for simulator"
	@echo "  test    - xcodebuild test for simulator"
	@echo "  lint    - Run swiftlint"
	@echo "  format  - Run swiftformat"
	@echo "  clean   - Clean build artifacts"
	@echo "  ci      - Run lint + build + test (CI entrypoint)"

gen:
	@command -v xcodegen >/dev/null 2>&1 || { echo >&2 "xcodegen is required. brew install xcodegen"; exit 1; }
	xcodegen generate

build:
	xcodebuild \
	  -project $(PROJECT).xcodeproj \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination $(DESTINATION) \
	  build

test:
	xcodebuild \
	  -project $(PROJECT).xcodeproj \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination $(DESTINATION) \
	  test

lint:
	@command -v swiftlint >/dev/null 2>&1 && swiftlint || echo "swiftlint not installed, skipping"

format:
	@command -v swiftformat >/dev/null 2>&1 && swiftformat . || echo "swiftformat not installed, skipping"

clean:
	xcodebuild clean -project $(PROJECT).xcodeproj -scheme $(SCHEME) || true
	rm -rf build DerivedData

ci: lint build test
