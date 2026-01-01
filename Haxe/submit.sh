#!/bin/bash

cd "$(dirname "$0")"

zip -r clipper.zip . -x "*.git*" -x "*.zip" -x "bin/*" -x "*.sh"
haxelib submit clipper.zip
rm clipper.zip
