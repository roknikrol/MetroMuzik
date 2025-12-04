import SwiftUI

// EXTENSION: Color Palette
// Extending the Color class to add our custom greyscale theme
extension Color {
    static let offWhite = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)
    static let darkShadow = Color.black.opacity(0.2)
    static let lightShadow = Color.white.opacity(0.7)
}

struct ContentView: View {
    // Instantiate our Engine
    @StateObject var engine = MetronomeEngine()
    
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
                        .frame(width: 60)
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
                        .menuStyle(BorderedButtonMenuStyle()) // Mac style
                        .frame(width: 60, height: 25)
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
                    
                
                    // The Rotating Knob
                    KnobView(bpm: $engine.bpm) { angle in
                        engine.updateBpmFromKnob(angle: angle)
                    }
                    
                    // BPM Display in Center
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
        .frame(minWidth: 400, minHeight: 600) // Mac Window Size
    }
    
    // Helper to switch icons
    func getNoteIcon() -> String {
        switch engine.subdivision {
        case 2: return "music.note.list"
        case 3: return "aqi.medium"
        default: return "music.note"
        }
    }
}

// MARK: - Custom UI Components

// The 3D Wheel Logic
struct KnobView: View {
    @Binding var bpm: Double
    var onUpdate: (Double) -> Void
    
    @State private var angle: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // The Wheel Shape
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: [Color.offWhite, Color.white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                // Inner shadow simulation for 3D feel
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 4)
                            .blur(radius: 4)
                            .offset(x: 2, y: 2)
                            .mask(Circle().fill(LinearGradient(gradient: Gradient(colors: [Color.black, Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)))
                    )
                
                // The Tiny Pin (Indicator)
                Circle()
                    .fill(Color.gray)
                    .frame(width: 15, height: 15)
                    .offset(x: 0, y: -90) // Push pin to edge
                    .rotationEffect(.degrees(calculateAngleFromBPM())) // Rotate pin based on current BPM
                
            }
            // The Drag Logic
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Calculate vector from center to finger
                        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                        
                        // Get Angle using atan2 (standard trig)
                        let radians = atan2(vector.dy, vector.dx)
                        var degrees = radians * 180 / .pi + 90 // +90 to align 0 at top
                        
                        if degrees < 0 { degrees += 360 }
                        
                        self.angle = degrees
                        self.onUpdate(degrees)
                    }
            )
        }
        .frame(width: 200, height: 200)
    }
    
    // Convert BPM back to Angle for initial rendering
    func calculateAngleFromBPM() -> Double {
        // Inverse of the math in Engine
        // BPM = 40 + (norm * 200) -> norm = (BPM - 40) / 200
        let norm = (bpm - 40) / 200
        return norm * 360
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
