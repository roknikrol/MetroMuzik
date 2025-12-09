//
//  ContentView.swift
//  MetroMuzika WatchOS Watch App
//
//  Created by Nikita Podobedov on 12/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: MetronomeEngine

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(engine.bpm)) BPM")
                .font(.headline)

            // Simple control for now: +/- buttons
            HStack {
                Button("-") {
                    engine.bpm = max(40, engine.bpm - 5)
                }
                Button("+") {
                    engine.bpm = min(400, engine.bpm + 5)
                }
            }
            .font(.title3)

            Button(engine.isPlaying ? "Stop" : "Start") {
                engine.togglePlay()
            }
            .padding(.top, 4)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
