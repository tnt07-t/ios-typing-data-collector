import SwiftUI

// MARK: - KeyInfo

private struct KeyInfo {
    let label: String   // display label
    let action: String  // value passed to callback: "a"-"z", "space", "delete", or "" for shift
}

// MARK: - CustomKeyboardView

struct CustomKeyboardView: View {
    var onKeyTap: (String, TapInfo) -> Void

    // Keyboard layout rows
    private let row0: [KeyInfo] = "qwertyuiop".map { KeyInfo(label: String($0), action: String($0)) }
    private let row1: [KeyInfo] = "asdfghjkl".map  { KeyInfo(label: String($0), action: String($0)) }
    private let row2letters: [KeyInfo] = "zxcvbnm".map { KeyInfo(label: String($0), action: String($0)) }

    // Layout constants
    private let sidePad: CGFloat = 3
    private let keyGap: CGFloat = 6
    private let keyHeight: CGFloat = 46
    private let rowGap: CGFloat = 13

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let innerWidth = totalWidth - 2 * sidePad
            let standardKeyWidth = (innerWidth - 9 * keyGap) / 10
            let row1Indent = (standardKeyWidth + keyGap) / 2
            let specialKeyWidth = (innerWidth - 7 * standardKeyWidth - 8 * keyGap) / 2
            let spaceKeyWidth = innerWidth

            VStack(spacing: rowGap) {
                // Row 0: q w e r t y u i o p
                HStack(spacing: keyGap) {
                    ForEach(row0, id: \.label) { key in
                        KeyButton(
                            key: key,
                            width: standardKeyWidth,
                            height: keyHeight,
                            style: .regular,
                            onKeyTap: onKeyTap
                        )
                    }
                }
                .padding(.horizontal, sidePad)

                // Row 1: a s d f g h j k l  (centered via indent)
                HStack(spacing: keyGap) {
                    Spacer().frame(width: row1Indent)
                    ForEach(row1, id: \.label) { key in
                        KeyButton(
                            key: key,
                            width: standardKeyWidth,
                            height: keyHeight,
                            style: .regular,
                            onKeyTap: onKeyTap
                        )
                    }
                    Spacer().frame(width: row1Indent)
                }
                .padding(.horizontal, sidePad)

                // Row 2: [⇧] z x c v b n m [⌫]
                HStack(spacing: keyGap) {
                    // Shift (non-functional)
                    KeyButton(
                        key: KeyInfo(label: "⇧", action: ""),
                        width: specialKeyWidth,
                        height: keyHeight,
                        style: .special,
                        onKeyTap: { _, _ in }
                    )

                    ForEach(row2letters, id: \.label) { key in
                        KeyButton(
                            key: key,
                            width: standardKeyWidth,
                            height: keyHeight,
                            style: .regular,
                            onKeyTap: onKeyTap
                        )
                    }

                    // Delete
                    KeyButton(
                        key: KeyInfo(label: "⌫", action: "delete"),
                        width: specialKeyWidth,
                        height: keyHeight,
                        style: .special,
                        onKeyTap: onKeyTap
                    )
                }
                .padding(.horizontal, sidePad)

                // Row 3: space bar
                HStack(spacing: 0) {
                    KeyButton(
                        key: KeyInfo(label: "space", action: "space"),
                        width: spaceKeyWidth,
                        height: keyHeight,
                        style: .space,
                        onKeyTap: onKeyTap
                    )
                }
                .padding(.horizontal, sidePad)
            }
            .padding(.top, rowGap)
            .padding(.bottom, rowGap)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
        }
    }
}

// MARK: - Key Style

private enum KeyStyle {
    case regular
    case special
    case space
}

// MARK: - KeyButton

private struct KeyButton: View {
    let key: KeyInfo
    let width: CGFloat
    let height: CGFloat
    let style: KeyStyle
    let onKeyTap: (String, TapInfo) -> Void

    // Stores the global frame of the key for computing keyScreenX/Y
    @State private var keyGlobalFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // Background captures global frame via GeometryReader
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        keyGlobalFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        keyGlobalFrame = newFrame
                    }
            }

            // Key surface with tap gesture in local coordinate space
            RoundedRectangle(cornerRadius: 5)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1)
                .overlay(
                    Text(key.label)
                        .font(labelFont)
                        .foregroundColor(.primary)
                )
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { value in
                            guard !key.action.isEmpty else { return }
                            let tapX = Double(value.location.x)
                            let tapY = Double(value.location.y)
                            let info = TapInfo(
                                keyLabel: key.action,
                                tapLocalX: tapX,
                                tapLocalY: tapY,
                                keyScreenX: Double(keyGlobalFrame.minX),
                                keyScreenY: Double(keyGlobalFrame.minY),
                                keyWidth: Double(keyGlobalFrame.width),
                                keyHeight: Double(keyGlobalFrame.height)
                            )
                            onKeyTap(key.action, info)
                        }
                )
        }
        .frame(width: width, height: height)
    }

    private var backgroundColor: Color {
        switch style {
        case .regular, .space:
            return Color(.white)
        case .special:
            return Color(.systemGray3)
        }
    }

    private var labelFont: Font {
        switch style {
        case .regular:
            return .system(size: 17, weight: .regular)
        case .special, .space:
            return .system(size: 15, weight: .regular)
        }
    }
}
