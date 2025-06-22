.PHONY: help build clean generate run stop archive

# Default target - show help
help:
	@echo "BTreadmill Build Commands:"
	@echo ""
	@echo "  generate    Generate Xcode project from project.yml"
	@echo "  build       Build the application using xcodebuild"
	@echo "  clean       Clean build artifacts"
	@echo "  run         Build and launch the application"
	@echo "  stop        Terminate running BTreadmill processes"
	@echo "  archive     Create distribution archive"
	@echo ""
	@echo "All commands use xcbeautify for formatted output."
	@echo "Run 'make generate' after modifying project.yml."

# Build target
build: generate
	xcodebuild -project BTreadmill.xcodeproj -scheme BTreadmill build | xcbeautify

# Generate project using xcodegen
generate:
	xcodegen generate

# Clean build artifacts
clean:
	xcodebuild -project BTreadmill.xcodeproj -scheme BTreadmill clean | xcbeautify

# Build and run
run: build
	open ./build/Debug/BTreadmill.app || xcodebuild -project BTreadmill.xcodeproj -scheme BTreadmill build -configuration Debug | xcbeautify && open ~/Library/Developer/Xcode/DerivedData/BTreadmill-*/Build/Products/Debug/BTreadmill.app

# Stop the running app
stop:
	pkill -f "BTreadmill" || true

# Archive for distribution
archive: generate
	xcodebuild -project BTreadmill.xcodeproj -scheme BTreadmill archive -archivePath ./build/BTreadmill.xcarchive | xcbeautify