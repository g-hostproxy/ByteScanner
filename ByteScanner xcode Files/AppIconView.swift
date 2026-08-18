import SwiftUI

// --- 1024x1024 GLOWING PURPLE APP ICON COMPONENT ---
struct AppIconView: View {
    // Cyberpunk Neon Purple/Magenta Palette
    let purplePrimary = Color(red: 0.78, green: 0.25, blue: 1.0)
    let purpleBright = Color(red: 0.95, green: 0.50, blue: 1.0)
    let deepViolet = Color(red: 0.12, green: 0.05, blue: 0.22)
    let darkBackground = Color(red: 0.04, green: 0.02, blue: 0.08)

    var body: some View {
        ZStack {
            // Dark Background Matrix Base
            darkBackground
            
            // Radial Glowing Purple Backdrop Aura
            RadialGradient(
                colors: [
                    purplePrimary.opacity(0.45),
                    deepViolet,
                    darkBackground
                ],
                center: .center,
                startRadius: 50,
                endRadius: 500
            )

            // Cybernetic Radar Grid Ring Layer
            ZStack {
                Circle()
                    .stroke(purplePrimary.opacity(0.25), lineWidth: 3)
                    .frame(width: 680, height: 680)

                Circle()
                    .stroke(purplePrimary.opacity(0.40), lineWidth: 2)
                    .frame(width: 480, height: 480)

                Circle()
                    .stroke(purplePrimary.opacity(0.60), lineWidth: 1.5)
                    .frame(width: 320, height: 320)

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 512, y: 140))
                    path.addLine(to: CGPoint(x: 512, y: 884))
                    path.move(to: CGPoint(x: 140, y: 512))
                    path.addLine(to: CGPoint(x: 884, y: 512))
                }
                .stroke(purplePrimary.opacity(0.20), lineWidth: 2)
            }

            // Central Glowing Bluetooth Logo Glyph (<BT Rune)
            ZStack {
                // Background Outer Neon Shadow
                BluetoothRuneShape()
                    .stroke(purplePrimary, lineWidth: 44)
                    .blur(radius: 20)
                    .opacity(0.9)

                // Secondary Neon Glow Layer
                BluetoothRuneShape()
                    .stroke(purplePrimary, lineWidth: 32)
                    .blur(radius: 10)

                // Foreground Crisp Bright White-Violet Core
                BluetoothRuneShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white, purpleBright, purplePrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
                    )
            }
            .scaleEffect(0.62)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 224, style: .continuous)) // Standard App Icon Corner Radius
    }
}

// Custom Bluetooth Symbol Geometry Path
struct BluetoothRuneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Top-left arrow stem (<)
        path.move(to: CGPoint(x: w * 0.32, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.14))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.70))

        return path
    }
}

struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconView()
            .previewLayout(.fixed(width: 1024, height: 1024))
    }
}