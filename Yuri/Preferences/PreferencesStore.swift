//
//  PreferencesStore.swift
//  Yuri
//

import Foundation
import os

@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults
    private let activePresetKey = "activeHotkeyPreset"
    private let soundFeedbackKey = "soundFeedbackEnabled"
    private let customShortcutsKey = "customShortcuts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activePreset: HotkeyPreset {
        get {
            guard let raw = defaults.string(forKey: activePresetKey),
                  let preset = HotkeyPreset(rawValue: raw)
            else {
                return .standard
            }
            return preset
        }
        set {
            defaults.set(newValue.rawValue, forKey: activePresetKey)
        }
    }

    /// 명령 실패 시 비프음 재생 여부. 미설정 시 기본 활성화.
    var soundFeedbackEnabled: Bool {
        get {
            guard defaults.object(forKey: soundFeedbackKey) != nil else { return true }
            return defaults.bool(forKey: soundFeedbackKey)
        }
        set {
            defaults.set(newValue, forKey: soundFeedbackKey)
        }
    }

    /// 명령 identifier → 사용자 커스텀 단축키. 프리셋 기본값을 덮어쓴다(BindingResolver).
    /// JSON으로 UserDefaults에 저장. 디코딩 실패 시 빈 맵으로 폴백(설정 손상이 앱을 막지 않게).
    var customShortcuts: [String: HotkeyShortcut] {
        get {
            guard let data = defaults.data(forKey: customShortcutsKey) else { return [:] }
            do {
                return try JSONDecoder().decode([String: HotkeyShortcut].self, from: data)
            } catch {
                // 손상된 설정이 앱을 막지 않게 빈 맵으로 폴백하되, 원인은 남긴다.
                Log.app.error("Failed to decode customShortcuts: \(error.localizedDescription, privacy: .public)")
                return [:]
            }
        }
        set {
            // UInt32 두 필드만 가진 Codable이라 인코딩은 사실상 실패하지 않는다(방어적 가드).
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: customShortcutsKey)
        }
    }

    func setShortcut(_ shortcut: HotkeyShortcut, forCommand identifier: String) {
        var shortcuts = customShortcuts
        shortcuts[identifier] = shortcut
        customShortcuts = shortcuts
    }

    func clearShortcut(forCommand identifier: String) {
        var shortcuts = customShortcuts
        shortcuts.removeValue(forKey: identifier)
        customShortcuts = shortcuts
    }

    func clearAllShortcuts() {
        customShortcuts = [:]
    }
}
