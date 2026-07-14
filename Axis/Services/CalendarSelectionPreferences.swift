import EventKit
import Foundation

/// Persists which EventKit calendars feed Day Brief, daily plans, schedule
/// views, and AI calendar actions. Empty/never configured = include all
/// calendars (backward compatible). Once the user toggles any calendar,
/// the enabled ID set is stored explicitly.
enum CalendarSelectionPreferences {
    static let includedIDsKey = "axis_included_calendar_ids"
    static let configuredKey = "axis_calendar_selection_configured"
    private static let appGroupSuite = "group.com.runellking.axis"

    /// `nil` means “never configured → include every calendar”.
    /// A set (possibly empty) means only those IDs are included.
    static var includedCalendarIDs: Set<String>? {
        get {
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: configuredKey) else { return nil }
            let ids = defaults.stringArray(forKey: includedIDsKey) ?? []
            return Set(ids)
        }
        set {
            let defaults = UserDefaults.standard
            if let newValue {
                defaults.set(true, forKey: configuredKey)
                defaults.set(Array(newValue).sorted(), forKey: includedIDsKey)
                writeToAppGroup(configured: true, ids: Array(newValue).sorted())
            } else {
                defaults.set(false, forKey: configuredKey)
                defaults.removeObject(forKey: includedIDsKey)
                writeToAppGroup(configured: false, ids: [])
            }
        }
    }

    static var hasExplicitSelection: Bool {
        UserDefaults.standard.bool(forKey: configuredKey)
    }

    static func isIncluded(_ calendarIdentifier: String) -> Bool {
        guard let ids = includedCalendarIDs else { return true }
        return ids.contains(calendarIdentifier)
    }

    static func setIncluded(_ calendarIdentifier: String, enabled: Bool, knownIDs: [String]) {
        var current = includedCalendarIDs ?? Set(knownIDs)
        if enabled {
            current.insert(calendarIdentifier)
        } else {
            current.remove(calendarIdentifier)
        }
        includedCalendarIDs = current
    }

    static func includeAll() {
        includedCalendarIDs = nil
    }

    /// Read selection from App Group (for widgets). Falls back to standard defaults.
    static func includedCalendarIDsForWidget() -> Set<String>? {
        if let suite = UserDefaults(suiteName: appGroupSuite),
           suite.bool(forKey: configuredKey) {
            return Set(suite.stringArray(forKey: includedIDsKey) ?? [])
        }
        return includedCalendarIDs
    }

    private static func writeToAppGroup(configured: Bool, ids: [String]) {
        guard let suite = UserDefaults(suiteName: appGroupSuite) else { return }
        suite.set(configured, forKey: configuredKey)
        if configured {
            suite.set(ids, forKey: includedIDsKey)
        } else {
            suite.removeObject(forKey: includedIDsKey)
        }
    }
}
