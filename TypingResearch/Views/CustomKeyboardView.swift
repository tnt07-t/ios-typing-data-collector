import SwiftUI

// MARK: - CustomKeyboardView

struct CustomKeyboardView: View {
    var onKeyTap: (String, TapInfo) -> Void

    @Environment(\.colorScheme) private var colorScheme

    // iOS keyboard background colors
    private var kbBg: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : Color(red: 0.82, green: 0.84, blue: 0.87)
    }

    private let row0 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1 = ["a","s","d","f","g","h","j","k","l"]
    private let row2 = ["z","x","c","v","b","n","m"]

    private let keyGap: CGFloat = 6
    private let sidePad: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            // Key width derived from screen width (10 keys, 9 gaps, side padding)
            let kw: CGFloat = (geo.size.width - 2 * sidePad - 9 * keyGap) / 10
            // Special key (shift/delete) width fills the space shift/delete normally occupy
            let sp: CGFloat = (geo.size.width - 2 * sidePad - 7 * kw - 8 * keyGap) / 2
            // Key height fills available vertical space evenly across 4 rows + 3 gaps + 2 paddings
            let kh: CGFloat = (geo.size.height - 3 * keyGap - 2 * keyGap) / 4

            VStack(spacing: keyGap) {
                // Row 0: q w e r t y u i o p
                HStack(spacing: keyGap) {
                    ForEach(row0, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: kh,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                }

                // Row 1: a s d f g h j k l  (centered, indented by sp+gap each side)
                HStack(spacing: keyGap) {
                    Spacer().frame(width: sp + keyGap)
                    ForEach(row1, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: kh,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                    Spacer().frame(width: sp + keyGap)
                }

                // Row 2: ⇧ z x c v b n m ⌫
                HStack(spacing: keyGap) {
                    KeyCap(label: "⇧", action: "", width: sp, height: kh,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                    ForEach(row2, id: \.self) { k in
                        KeyCap(label: k, action: k, width: kw, height: kh,
                               isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    }
                    KeyCap(label: "⌫", action: "delete", width: sp, height: kh,
                           isSpecial: true, colorScheme: colorScheme, onTap: onKeyTap)
                }

                // Row 3: [123] [space] [return]  — 123 and return are non-functional decorations
                HStack(spacing: keyGap) {
                    KeyCap(label: "123", action: "", width: sp, height: kh,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                    KeyCap(label: "space", action: "space",
                           width: geo.size.width - 2 * sidePad - 2 * sp - 2 * keyGap,
                           height: kh, isSpecial: false, colorScheme: colorScheme, onTap: onKeyTap)
                    KeyCap(label: "return", action: "", width: sp, height: kh,
                           isSpecial: true, colorScheme: colorScheme, onTap: { _, _ in })
                }
            }
            .padding(.horizontal, sidePad)
            .padding(.vertical, keyGap)
            .frame(width: geo.size.width, height: geo.size.height)
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
        if isSpecial {
            return colorScheme == .dark
                ? Color(white: 0.20)
                : Color(red: 0.68, green: 0.71, blue: 0.74)
        } else {
            return colorScheme == .dark
                ? Color(white: 0.31)
                : .white
        }
    }

    private var labelColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var labelFont: Font {
        switch label {
        case "space", "return", "123":
            return .system(size: 15, weight: .regular)
        case "⇧", "⌫":
            return .system(size: 18, weight: .regular)
        default:
            return .system(size: 22, weight: .light)
        }
    }

    var body: some View {
        Text(label)
            .font(labelFont)
            .foregroundColor(labelColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(keyBg)
                    .shadow(color: .black.opacity(0.40), radius: 0, x: 0, y: 1)
            )
            .background(
                // Capture global frame for tap coordinate logging
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
                            keyWidth: Double(keyGlobalFrame.width),
                            keyHeight: Double(keyGlobalFrame.height)
                        )
                        onTap(action, info)
                    }
            )
    }
}
