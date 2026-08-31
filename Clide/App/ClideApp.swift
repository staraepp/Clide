import SwiftUI

@main
struct ClideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // `App` requires at least one Scene, and declaring none of the usual
    // window-producing kinds is what keeps Clide from popping an empty
    // window at launch. This Settings scene is otherwise inert: Clide is
    // LSUIElement, so SwiftUI never builds the standard app menu that would
    // let `showSettingsWindow:`/`openSettings` actually reach it. The real
    // Settings window is SettingsWindowController, opened directly from the
    // status-item menu and the dashboard's gear icon.
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
