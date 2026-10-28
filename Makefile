F := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
APP := build/NetSwitchBar.app

.PHONY: test app install

test:
	swift test -Xswiftc -F$(F) -Xlinker -F$(F) -Xlinker -rpath -Xlinker $(F)

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/NetSwitchBar $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

install: app
	mkdir -p ~/Applications
	rm -rf ~/Applications/NetSwitchBar.app
	cp -R $(APP) ~/Applications/
