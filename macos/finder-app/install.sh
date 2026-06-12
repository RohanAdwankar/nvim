#!/bin/sh
set -eu

app="$HOME/Applications/nvim.app"
bundle="com.rohanadwankar.nvim.finder"
src="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/nvim.applescript"
content_types='public.data
public.text
public.plain-text
public.source-code
public.script
public.shell-script
public.json
public.yaml
public.xml
public.comma-separated-values-text
public.tab-separated-values-text
com.apple.property-list
net.daringfireball.markdown'
extensions='txt text md markdown json jsonc yaml yml toml xml plist csv tsv log conf config ini env gitignore dockerignore editorconfig sh bash zsh fish ksh command py pyw ipynb lua vim go rs c h cpp cxx cc hpp java js jsx ts tsx mjs cjs css scss sass html htm svelte vue astro rb pl php swift kt kts scala sql proto graphql gql tf tfvars hcl nix make mk Dockerfile Makefile Procfile Brewfile Justfile Taskfile Rakefile Gemfile'

mkdir -p "$HOME/Applications"
rm -rf "$app"
osacompile -o "$app" "$src"

plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle" "$plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle" "$plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string nvim documents" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$plist"

i=0
printf '%s\n' "$content_types" | while IFS= read -r type; do
	[ -n "$type" ] || continue
	/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string $type" "$plist"
	i=$((i + 1))
done

i=0
for ext in $extensions; do
	/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:$i string $ext" "$plist"
	i=$((i + 1))
done

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"

defaults_swift="$(mktemp /tmp/nvim-finder-defaults.XXXXXX.swift)"
trap 'rm -f "$defaults_swift"' EXIT
types_swift=$(printf '%s\n' "$content_types" | awk 'NF { printf "%s\"%s\"", sep, $0; sep = ", " }')
extensions_swift=$(printf '%s\n' $extensions | awk 'NF { printf "%s\"%s\"", sep, $0; sep = ", " }')
cat >"$defaults_swift" <<SWIFT
import Foundation
import CoreServices
import UniformTypeIdentifiers

let bundle = "$bundle" as NSString
var types = Set<String>([$types_swift])
for ext in [$extensions_swift] {
    if let type = UTType(filenameExtension: ext) {
        types.insert(type.identifier)
    }
}

var ok = 0
var failed = 0
for type in types.sorted() {
    let editor = LSSetDefaultRoleHandlerForContentType(type as NSString, .editor, bundle)
    let viewer = LSSetDefaultRoleHandlerForContentType(type as NSString, .viewer, bundle)
    if editor == noErr || viewer == noErr {
        ok += 1
    } else {
        failed += 1
    }
}
print("registered \\(ok) file types; \\(failed) protected types unchanged")
SWIFT
swift "$defaults_swift"

