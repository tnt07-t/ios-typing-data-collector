import SwiftUI

// MARK: - CustomKeyboardView

struct CustomKeyboardView: View {
    var onKeyTap: (String, TapInfo) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var kbBg: Color {
        colorScheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.18)
            : Color(red: 0.82, green: 0.83, blue: 0.855)
    }

    private let row0 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1 = ["a","s","d","f","g","h","j","k","l"]
    private let row2 = ["z","x","c","v","b","n","m"]

    // iOS standard key spacing constants (consistent across all devices)
    private let sidePad: CGFloat  = 3
    private let keyGap: CGFloat   = 6
    private let rowGap: CGFloat   = 11
    private let topPad: CGFloat   = 11
    private let bottomPad: CGFloat = 3
    // iOS standard key height — Apple keeps this constant across devices, adjusts padding
    private let keyH: CGFloat     = 42

    var body: some View {
        GeometryReader { geo in
            let kw: CGFloat   = (geo.size.width - 2*sidePad - 9*keyGap) / 10
            let sp: CGFloat   = (geo.size.width - 2*sidePad - 7*kw - 8*keyGap) / 2

            VStack(spacing: rowGap) {
                // Row 0: qwertyuiop
                HStack(spacing: keyGap) {
                    ForEach(row0, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: keyH,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                }

                // Row 1: asdfghjkl (centered, indented to align under row 0 gaps)
                HStack(spacing: keyGap) {
                    Spacer().frame(width: sp + keyGap)
                    ForEach(row1, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: keyH,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                    Spacer().frame(width: sp + keyGap)
                }

                // Row 2: ⇧ zxcvbnm ⌫
                HStack(spacing: keyGap) {
                    KeyCap(label: "⇧", action: "", width: sp, height: keyH,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                    ForEach(row2, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: keyH,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                    KeyCap(label: "⌫", action: "delete", width: sp, height: keyH,
                           isSpecial: true, colorScheme: colorScheme, onTap: onKeyTap)
                }

                // Row 3: 123 space return
                HStack(spacing: keyGap) {
                    KeyCap(label: "123", action: "", width: sp, height: keyH,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                    KeyCap(label: "space", action: "space",
                           width: geo.size.width - 2*sidePad - 2*sp - 2*keyGap,
                           height: keyH, isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    KeyCap(label: "return", action: "", width: sp, height: keyH,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                }
            }
            .padding(.horizontal, sidePad)
            .padding(.top, topPad)
            .padding(.bottom, bottomPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(kbBg)
        }
    }
}

// MARK: - KeyCap

private struct KeyCap: View {
    let label: String
    let action: String
    let width: CGFloat
    let height: CGFloat
    let isSpecial: Bool
    let colorScheme: ColorScheme
    let onTap: (String, TapInfo) -> Void

    @State private var keyGlobalFrame: CGRect = .zero

    private var keyBg: Color {
        isSpecial
            ? (colorScheme == .dark ? Color(white: 0.21) : Color(red: 0.69, green: 0.71, blue: 0.73))
            : (colorScheme == .dark ? Color(white: 0.31) : .white)
    }

    private var labelColor: Color { colorScheme == .dark ? .white : .black }

    private var labelFont: Font {
        switch label {
        case "space", "return", "123": return .system(size: 15, weight: .regular)
        case "⇧", "⌫":               return .system(size: 20, weight: .regular)
        default:                       return .system(size: 22, weight: .light)
        }
    }

    var body: some View {
        Text(label)
            .font(labelFont)
            .foregroundColor(labelColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(keyBg)
                    .shadow(color: Color(white: 0, opacity: 0.35), radius: 0, x: 0, y: 1)
            )
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        keyGlobalFrame = geo.frame(in: .global)
                    }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        guard !action.isEmpty else { return }
                        let info = TapInfo(
                            keyLabel: action,
                            tapLocalX: Double(value.location.x),
                            tapLocalY: Double(value.location.y),
                            keyScreenX: Double(keyGlobalFrame.minX),
                            keyScreenY: Double(keyGlobalFrame.minY),
                            keyWidth:   Double(keyGlobalFrame.width),
                            keyHeight:  Double(keyGlobalFrame.height)
                        )
                        onTap(action, info)
                    }
            )
    }
}
