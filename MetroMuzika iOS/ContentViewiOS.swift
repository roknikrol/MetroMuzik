import SwiftUI

// EXTENSION: Color Palette
// Extending the Color class to add our custom greyscale theme
extension Color {
    static let offWhite = Color(red: 180/255, green: 200/255, blue: 190/255)
    static let darkShadow = Color.black.opacity(0.2)
    static let lightShadow = Color.white.opacity(0.1)
}

struct ContentViewiOS: View {
    // Instantiate our Engine
    @StateObject var engine = MetronomeEngineiOS()
    
    var body: some View {
        ZStack {
            // 1. Background
            Color.offWhite.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                
                // 2. Top Frame: Time Signature & Subdivision
                HStack(spacing: 40) {
                    VStack {
                        Text("BEATS")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("", selection: $engine.timeSignature) {
                            ForEach(1...12, id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 50)
                        .background(NeumorphicBackground())
                    }
                    
                    VStack {
                        Text("NOTE")
                            .font(.caption)
                            .foregroundColor(.gray)
                        // Text-less dropdown using Symbols
                        Menu {
                            Button(action: { engine.subdivision = 1 }) { Label("Quarter", systemImage: "music.note") }
                            Button(action: { engine.subdivision = 2 }) { Label("Eighth", systemImage: "music.note.list") }
                            Button(action: { engine.subdivision = 3 }) { Label("Triplet", systemImage: "aqi.medium") } // Approximation icon
                        } label: {
                            Image(systemName: getNoteIcon())
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                        #if os(macOS)
                        .menuStyle(BorderedButtonMenuStyle()) // Mac style
                        .frame(width: 60, height: 25)
                        #endif
                        .background(NeumorphicBackground())
                    }
                }
                .padding(.top, 20)
                
                // 3. Center: Giant 3D Wheel (The Knob)
                Spacer()
                ZStack {
                    // Outer Ring
                    Circle()
                        .fill(Color.offWhite)
                        .frame(width: 250, height: 250)
                        .shadow(color: .darkShadow, radius: 10, x: 10, y: 10)
                        .shadow(color: .lightShadow, radius: 10, x: -5, y: -5)

                    KnobView(bpm: $engine.bpm)

                    Text("\(Int(engine.bpm))")
                        .font(.system(size: 50, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                // 4. Bottom: Controls
                HStack(spacing: 30) {
                    // Tap Button
                    Button(action: { engine.tapTempo() }) {
                        Text("TAP")
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .frame(width: 80, height: 40)
                    }
                    .buttonStyle(NeumorphicButtonStyle())
                    
                    // Play Button
                    Button(action: { engine.togglePlay() }) {
                        Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(engine.isPlaying ? .red : .green)
                            .frame(width: 80, height: 40)
                    }
                    .buttonStyle(NeumorphicButtonStyle())
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 600) // Mac Window Size
        #endif
    }
    
    // Helper to switch icons
    func getNoteIcon() -> String {
        switch engine.subdivision {
        case 2: return "music.note.list"
        case 3: return "aqi.medium"
        default: return "music.note"
        }
    }
    
    
    // Convert BPM back to angle for rendering
    // 120 BPM = 0° (noon). Every 25° corresponds to 5 BPM.
    func calculateAngleFromBPM() -> Double {
        let steps = (engine.bpm - 120.0) / 5.0
        let angle = steps * 25.0
        return angle
    }
}

// MARK: - Custom UI Components

// The 3D Wheel Logic
 struct KnobView: View {
    @Binding var bpm: Double

    @State private var totalRotation: Double = 0.0   // can be any number of degrees (multi-turn)
    @State private var lastDragAngle: Double? = nil  // 0–360 for current drag

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2,
                                 y: geometry.size.height / 2)

            ZStack {
                // The Wheel Shape
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.offWhite, Color.white]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 4)
                            .blur(radius: 4)
                            .offset(x: 2, y: 2)
                            .mask(
                                Circle().fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black, Color.clear]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                    )

                // Tick markings around the wheel
                ForEach(0..<72, id: \.self) { tick in
                    Capsule()
                        .fill(Color.gray.opacity(tick % 6 == 0 ? 0.5 : 0.2))
                        .frame(width: 2, height: tick % 6 == 0 ? 14 : 7)
                        .offset(x: 0, y: -95)
                        .rotationEffect(.degrees(Double(tick) * 5)) // 5° per tick
                }

                // The Tiny Pin (Indicator) – part of the knob face
                Circle()
                    .fill(Color.gray)
                    .frame(width: 15, height: 15)
                    .offset(x: 0, y: -90) // push pin to edge
            }
            // Rotate the entire knob (wheel, ticks, and pin) like a physical button
            .rotationEffect(.degrees(totalRotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Vector from center to finger
                        let vector = CGVector(dx: value.location.x - center.x,
                                              dy: value.location.y - center.y)

                        // Base angle from finger position
                        let radians = atan2(vector.dy, vector.dx)
                        var degrees = radians * 180 / .pi + 90 // 0° at noon
                        if degrees < 0 { degrees += 360 }

                        if let last = lastDragAngle {
                            // Smallest signed delta between last and current
                            var delta = degrees - last
                            if delta > 180 { delta -= 360 }
                            if delta < -180 { delta += 360 }

                            totalRotation += delta
                            updateBpmFromRotation()
                        }

                        lastDragAngle = degrees
                    }
                    .onEnded { _ in
                        lastDragAngle = nil
                    }
            )
            .onAppear {
                // Initialize rotation from current BPM
                totalRotation = rotationForBpm(bpm)
            }
            .onChange(of: bpm) { oldValue, newValue in
                // Keep knob in sync if BPM changes from elsewhere (e.g. Tap)
                totalRotation = rotationForBpm(newValue)
            }
        }
        .frame(width: 200, height: 200)
    }

    /// Map totalRotation → BPM.
    /// 120 BPM = 0° (pin at noon).
    /// Every full revolution (360°) changes BPM by 20.
    private func updateBpmFromRotation() {
        let bpmPerRevolution = 20.0
        let centerBpm = 120.0

        let revolutions = totalRotation / 360.0
        var newBpm = centerBpm + revolutions * bpmPerRevolution

        // Clamp to [40, 400]
        newBpm = max(40.0, min(400.0, newBpm))

        bpm = newBpm
    }

    /// Inverse mapping: BPM → totalRotation (for initial state / external changes)
    private func rotationForBpm(_ bpm: Double) -> Double {
        let bpmPerRevolution = 20.0
        let centerBpm = 120.0

        let revolutions = (bpm - centerBpm) / bpmPerRevolution
        return revolutions * 360.0
    }
}

// Styling wrapper for buttons
struct NeumorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if configuration.isPressed {
                        // Pressed state: Inner shadow
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.offWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: 2, y: 2)
                                    .mask(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(gradient: Gradient(colors: [Color.black, Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)))
                            )
                    } else {
                        // Unpressed state: Drop shadow (Pop out)
                        NeumorphicBackground()
                    }
                }
            )
    }
}

// Reusable Background View
struct NeumorphicBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.offWhite)
            .shadow(color: .darkShadow, radius: 5, x: 5, y: 5)
            .shadow(color: .lightShadow, radius: 5, x: -5, y: -5)
    }
}
#Preview {
    ContentViewiOS()
}
