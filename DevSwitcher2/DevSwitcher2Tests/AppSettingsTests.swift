import XCTest
@testable import DevSwitcher2

final class AppSettingsTests: XCTestCase {
    func testMenuBarIconIsVisibleByDefault() {
        XCTAssertTrue(AppSettings.default.showMenuBarIcon)
    }

    func testFirstInstallAndResetAppearanceDefaults() {
        let defaults = AppSettings.default
        XCTAssertEqual(defaults.switcherLayoutStyle, .circular)
        XCTAssertEqual(defaults.circularLayoutOuterRingStyle, .transparent)
        XCTAssertEqual(defaults.colorScheme, .graphite)
        XCTAssertEqual(defaults.circularLayoutSize, 2.0)
    }

    func testLegacySettingsWithoutMenuBarIconPreserveExistingValues() throws {
        var legacySettings = AppSettings.default
        legacySettings.modifierKey = .option
        legacySettings.triggerKey = .space
        legacySettings.ct2Enabled = false
        legacySettings.ct2ModifierKey = .control
        legacySettings.ct2TriggerKey = .semicolon
        legacySettings.launchAtStartup = true
        legacySettings.showNumberKeys = false
        legacySettings.switcherFollowActiveWindow = false
        legacySettings.switcherVerticalPosition = 0.61
        legacySettings.switcherLayoutStyle = .list
        legacySettings.circularLayoutSize = 1.4
        legacySettings.circularLayoutOuterRingStyle = .frosted
        legacySettings.colorScheme = .ocean
        legacySettings.appTitleConfigs = [
            "com.example.LegacyApp": AppTitleConfig(
                bundleId: "com.example.LegacyApp",
                appName: "Legacy App",
                strategy: .afterLastSeparator,
                customSeparator: " | "
            )
        ]

        let encodedSettings = try JSONEncoder().encode(legacySettings)
        var legacyJSONObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedSettings) as? [String: Any]
        )
        legacyJSONObject.removeValue(forKey: "showMenuBarIcon")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSONObject)

        let migratedSettings = try JSONDecoder().decode(AppSettings.self, from: legacyData)

        XCTAssertTrue(migratedSettings.showMenuBarIcon)
        XCTAssertEqual(migratedSettings.modifierKey, .option)
        XCTAssertEqual(migratedSettings.triggerKey, .space)
        XCTAssertFalse(migratedSettings.ct2Enabled)
        XCTAssertEqual(migratedSettings.ct2ModifierKey, .control)
        XCTAssertEqual(migratedSettings.ct2TriggerKey, .semicolon)
        XCTAssertTrue(migratedSettings.launchAtStartup)
        XCTAssertFalse(migratedSettings.showNumberKeys)
        XCTAssertFalse(migratedSettings.switcherFollowActiveWindow)
        XCTAssertEqual(migratedSettings.switcherVerticalPosition, 0.61)
        XCTAssertEqual(migratedSettings.switcherLayoutStyle, .list)
        XCTAssertEqual(migratedSettings.circularLayoutSize, 1.4)
        XCTAssertEqual(migratedSettings.circularLayoutOuterRingStyle, .frosted)
        XCTAssertEqual(migratedSettings.colorScheme, .ocean)

        let migratedAppConfig = try XCTUnwrap(migratedSettings.appTitleConfigs["com.example.LegacyApp"])
        XCTAssertEqual(migratedAppConfig.appName, "Legacy App")
        XCTAssertEqual(migratedAppConfig.strategy, .afterLastSeparator)
        XCTAssertEqual(migratedAppConfig.customSeparator, " | ")
    }

    func testHiddenMenuBarIconSurvivesPersistenceRoundTrip() throws {
        var settings = AppSettings.default
        settings.showMenuBarIcon = false

        let data = try JSONEncoder().encode(settings)
        let decodedSettings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(decodedSettings.showMenuBarIcon)
    }
}
