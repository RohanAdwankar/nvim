#!/bin/sh
set -eu

app="$HOME/Applications/nvim.app"
bundle="com.rohanadwankar.nvim.finder"
src="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/nvim.applescript"

mkdir -p "$HOME/Applications"
rm -rf "$app"
osacompile -o "$app" "$src"

plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle" "$plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle" "$plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Text documents" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$plist"

i=0
for type in public.plain-text public.json net.daringfireball.markdown; do
	/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string $type" "$plist"
	i=$((i + 1))
done

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"

defaults_swift="$(mktemp /tmp/nvim-finder-defaults.XXXXXX.swift)"
trap 'rm -f "$defaults_swift"' EXIT
cat >"$defaults_swift" <<SWIFT
import Foundation
import CoreServices

let bundle = "$bundle" as NSString
for type in ["public.plain-text", "public.json", "net.daringfireball.markdown"] {
    let status = LSSetDefaultRoleHandlerForContentType(type as NSString, .editor, bundle)
    print("\\(type): \\(status == noErr ? "ok" : "error \\(status)")")
}
SWIFT
swift "$defaults_swift"

