//
//  MetroMuzika_WatchOSApp.swift
//  MetroMuzika WatchOS Watch App
//
//  Created by Nikita Podobedov on 12/8/25.
//

import SwiftUI

@main
struct MetroMuzika_WatchOS_Watch_AppApp: App {
    
    @StateObject private var engine = MetronomeEngineiOS()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine)
        }
    }
}
