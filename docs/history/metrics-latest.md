## 2026/04/08
- focused verification: xcodebuild test -scheme YoutubeFeeder -destination platform=iOS Simulator,name=iPhone 17,OS=26.4 -only-testing:YoutubeFeederTests/BasicGUICompositionTests -only-testing:YoutubeFeederTests/AppLayoutTests
- Issue1 focused verification: user visually confirmed the icon on the Home screen and in Settings, so additional automated checks were skipped by instruction.
- Issue1 focused verification: project.pbxproj still sets ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon and Assets.xcassets contains only AppIcon.appiconset.
- Issue1 focused verification: Contents.json maps light/dark/tinted slots to app-icon-light/dark/tinted.png and remains valid JSON.
- Issue1 focused verification: copied app-icon-light/dark/tinted.png into AppIcon.appiconset and verified all three remain 1024x1024.
- Issue1 focused verification: image.png=1024x1024, AppIcon.appiconset has light/dark/tinted slots, project.pbxproj keeps ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
- Issue82 focused verification: rg -n "assistant-line|assistant_line" docs/rules.md skills scripts/history -g "*.md" -g "*.py" -g "*.json" -> no matches
