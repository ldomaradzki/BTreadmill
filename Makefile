.PHONY: build clean generate run stop

# Default target
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