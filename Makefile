.PHONY: build test app install run package icon clean

build:        ## Compile a debug build
	swift build

test:         ## Run the unit tests
	swift test

app install:  ## Build "SafeSweep.app" and install it into ~/Applications
	./build.sh

run: install  ## Build, install and launch the app
	open "$(HOME)/Applications/SafeSweep.app"

package:      ## Build a universal app and package it as .dmg and .zip in build/
	./build.sh --package

icon:         ## Regenerate Resources/AppIcon.icns and docs/icon.png
	swift scripts/make-icon.swift

clean:        ## Remove build artifacts
	rm -rf .build build
