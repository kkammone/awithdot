#!/bin/bash
pod install
xcodebuild -workspace awithdot.xcworkspace -scheme awithdot  -configuration Release ARCHS="x86_64" build 
tar -zcvf archive/awithdot-0.0.1.mojave.tar.gz -C build/awithdot/Build/Products/Release awithdot.app
