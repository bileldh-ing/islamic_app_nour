"""Switch the Runner target's Release config to manual App Store signing and
write ios/ExportOptions.plist. Usage: ios_manual_signing.py TEAM_ID PROFILE_NAME"""
import re
import sys

team, profile = sys.argv[1], sys.argv[2]
bundle = "com.bileldh.noor"
path = "ios/Runner.xcodeproj/project.pbxproj"
src = open(path).read()

def patch(block: str) -> str:
    if f"PRODUCT_BUNDLE_IDENTIFIER = {bundle};" not in block:
        return block
    block = re.sub(r"\s*CODE_SIGN_STYLE = \w+;", "", block)
    block = re.sub(r"\s*DEVELOPMENT_TEAM = \w*;", "", block)
    block = re.sub(r"\s*PROVISIONING_PROFILE_SPECIFIER = [^;]*;", "", block)
    block = re.sub(r'\s*"?CODE_SIGN_IDENTITY(\[sdk=iphoneos\*\])?"? = [^;]*;', "", block)
    extra = (
        f'\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
        f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
        f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile}";'
        f'\n\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'
    )
    return block.replace("buildSettings = {", "buildSettings = {" + extra, 1)

src = re.sub(r"\{\s*isa = XCBuildConfiguration;.*?name = \w+;\s*\}", lambda m: patch(m.group(0)), src, flags=re.S)
open(path, "w").write(src)

open("ios/ExportOptions.plist", "w").write(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>{team}</string>
  <key>signingStyle</key><string>manual</string>
  <key>provisioningProfiles</key>
  <dict><key>{bundle}</key><string>{profile}</string></dict>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
""")
print("Signing configured for", bundle, "team", team, "profile", profile)
