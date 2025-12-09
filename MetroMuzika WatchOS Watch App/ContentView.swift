//
//  ContentView.swift
//  MetroMuzika WatchOS Watch App
//
//  Created by Nikita Podobedov on 12/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: MetronomeEngine
    @State private var crownValue: Double = 120

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(engine.bpm)) BPM")
                .font(.headline)

            Button(engine.isPlaying ? "Stop" : "Start") {
                engine.togglePlay()
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .foregroundColor(.gray)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
            .shadow(color: Color.white.opacity(0.7), radius: 4, x: -2, y: -2)
            
            Toggle("Mute", isOn: $engine.hapticsOnly).font(.caption2)
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: 40,
            through: 400,
            by: 1,
            sensitivity: .medium,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { newValue in
            engine.bpm = newValue
        }
    }
}

#Preview {
    ContentView()
}
