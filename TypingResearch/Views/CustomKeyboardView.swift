import SwiftUI
import UIKit

// MARK: - CustomKeyboardView

struct CustomKeyboardView: View {
    var overlayMode: Bool = false
    var onKeyTap: (String, TapInfo) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var kbBg: Color {
        if overlayMode { return .clear }
        return colorScheme == .dark
            ? Color(red: 0.176, green: 0.176, blue: 0.184)
            : Color(red: 0.816, green: 0.827, blue: 0.851)
    }

    private let row0 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row1 = ["a","s","d","f","g","h","j","k","l"]
    private let row2 = ["z","x","c","v","b","n","m"]

    private let sidePad:   CGFloat = 5
    private let keyGap:    CGFloat = 6
    private let rowGap:    CGFloat = 11
    private let topPad:    CGFloat = 0
    private let bottomPad: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            keyboardStack(geo: geo)
        }
    }

    private func keyboardStack(geo: GeometryProxy) -> some View {
        let kw: CGFloat = (geo.size.width - 2*sidePad - 9*keyGap) / 10
        let sp: CGFloat = (geo.size.width - 2*sidePad - 7*kw - 8*keyGap) / 2
        let availH: CGFloat = geo.size.height - topPad - bottomPad - 3*rowGap
        let keyH: CGFloat = max(34, availH / 5)
        return keyRows(geo: geo, kw: kw, sp: sp, keyH: keyH)
    }

    private func keyRows(geo: GeometryProxy, kw: CGFloat, sp: CGFloat, keyH: CGFloat) -> some View {
        VStack(spacing: rowGap) {
            row0View(kw: kw, keyH: keyH)
            row1View(kw: kw, sp: sp, keyH: keyH)
            row2View(kw: kw, sp: sp, keyH: keyH)
            row3View(geo: geo, kw: kw, sp: sp, keyH: keyH)
        }
        .padding(.horizontal, sidePad)
        .padding(.top, topPad)
        .padding(.bottom, bottomPad)
        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        .background(kbBg)
    }

    // MARK: Row builders

    private func row0View(kw: CGFloat, keyH: CGFloat) -> some View {
        HStack(spacing: keyGap) {
            ForEach(row0, id: \.self) { k in
                KeyCap(label: k, action: k, width: kw, height: keyH,
                       isSpecial: false, colorScheme: colorScheme,
                       overlayMode: overlayMode, onTap: onKeyTap)
            }
        }
    }

    private func row1View(kw: CGFloat, sp: CGFloat, keyH: CGFloat) -> some View {
        HStack(spacing: keyGap) {
            Spacer().frame(width: sp + keyGap)
            ForEach(row1, id: \.self) { k in
                KeyCap(label: k, action: k, width: kw, height: keyH,
                       isSpecial: false, colorScheme: colorScheme,
                       overlayMode: overlayMode, onTap: onKeyTap)
            }
            Spacer().frame(width: sp + keyGap)
        }
    }

    private func row2View(kw: CGFloat, sp: CGFloat, keyH: CGFloat) -> some View {
        HStack(spacing: keyGap) {
            KeyCap(label: "⇧", action: "", width: sp, height: keyH,
                   isSpecial: true, colorScheme: colorScheme,
                   overlayMode: overlayMode, onTap: { _, _ in })
            ForEach(row2, id: \.self) { k in
                KeyCap(label: k, action: k, width: kw, height: keyH,
                       isSpecial: false, colorScheme: colorScheme,
                       overlayMode: overlayMode, onTap: onKeyTap)
            }
            KeyCap(label: "⌫", action: "delete", width: sp, height: keyH,
                   isSpecial: true, colorScheme: colorScheme,
                   overlayMode: overlayMode, onTap: onKeyTap)
        }
    }

    private func row3View(geo: GeometryProxy, kw: CGFloat, sp: CGFloat, keyH: CGFloat) -> some View {
        HStack(spacing: keyGap) {
            KeyCap(label: "123", action: "", width: sp, height: keyH,
                   isSpecial: true, colorScheme: colorScheme,
                   overlayMode: overlayMode, onTap: { _, _ in })
            KeyCap(label: "space", action: "space",
                   width: geo.size.width - 2*sidePad - 2*sp - 2*keyGap,
                   height: keyH, isSpecial: false, colorScheme: colorScheme,
                   overlayMode: overlayMode, onTap: onKeyTap)
            KeyCap(label: "return", action: "", width: sp, height: keyH,
                   isSpecial: true, colorScheme: colorScheme,
                   overlayMode: overlayMode, onTap: { _, _ in })
        }
    }
}

// MARK: - KeyCalloutView

private struct KeyCalloutView: View {
    let label: String
    let keyWidth: CGFloat
    let keyHeight: CGFloat
    let colorScheme: ColorScheme

    private static let bubbleH: CGFloat = 54
    private static let stemH:   CGFloat = 16
    private static let overlap: CGFloat = 4
    static  let totalHeight:    CGFloat = bubbleH + stemH - overlap

    private var bubbleW: CGFloat { max(44, keyWidth) }
    private var stemW:   CGFloat { min(keyWidth, 28) }

    private var bgColor: Color {
        colorScheme == .dark ? Color(white: 0.31) : .white
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5)
                .fill(bgColor)
                .frame(width: stemW, height: Self.stemH)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgColor)
                    .shadow(color: Color(white: 0, opacity: 0.18), radius: 8, x: 0, y: 4)
                Text(label)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .frame(width: bubbleW, height: Self.bubbleH)
            .offset(y: -(Self.stemH - Self.overlap))
        }
        .frame(width: max(bubbleW, stemW), height: Self.totalHeight)
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
    let overlayMode: Bool
    let onTap: (String, TapInfo) -> Void

    @State private var keyGlobalFrame: CGRect = .zero
    @State private var isPressed: Bool = false

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var keyBg: Color {
        let pressed = isPressed && !isSpecial
        if overlayMode {
            if isSpecial {
                return colorScheme == .dark
                    ? Color(white: 0.21, opacity: 0.72)
                    : Color(red: 0.69, green: 0.71, blue: 0.73, opacity: 0.72)
            } else {
                return colorScheme == .dark
                    ? Color(white: pressed ? 0.22 : 0.31, opacity: 0.72)
                    : Color(white: pressed ? 0.82 : 1.0,  opacity: 0.72)
            }
        }
        if isSpecial {
            return colorScheme == .dark
                ? Color(white: 0.21)
                : Color(red: 0.69, green: 0.71, blue: 0.73)
        }
        return colorScheme == .dark
            ? Color(white: pressed ? 0.22 : 0.31)
            : (pressed ? Color(white: 0.82) : .white)
    }

    private var labelColor: Color { colorScheme == .dark ? .white : .black }

    private var labelFont: Font {
        switch label {
        case "space", "return", "123": return .system(size: 16, weight: .regular)
        case "⇧":                      return .system(size: 19, weight: .regular)
        case "⌫":                      return .system(size: 21, weight: .regular)
        default:                        return .system(size: 22, weight: .regular)
        }
    }

    private var keyShape: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(keyBg)
            .shadow(color: Color(white: 0, opacity: overlayMode ? 0.20 : 0.40),
                    radius: 0, x: 0, y: 1)
    }

    private var frameTracker: some View {
        GeometryReader { geo in
            Color.clear.onAppear {
                keyGlobalFrame = geo.frame(in: .global)
            }
        }
    }

    private var keyGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { _ in
                if !isPressed { isPressed = true }
            }
            .onEnded { value in
                isPressed = false
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
    }

    var body: some View {
        Text(label)
            .font(labelFont)
            .foregroundColor(labelColor)
            .frame(width: width, height: height)
            .background(keyShape)
            .background(frameTracker)
            .contentShape(Rectangle())
            // Callout appears above the key — local overlay, no parent re-render
            .overlay(alignment: .top) {
                if isPressed && label.count == 1 && !isSpecial {
                    KeyCalloutView(label: label, keyWidth: width,
                                   keyHeight: height, colorScheme: colorScheme)
                        .offset(y: -KeyCalloutView.totalHeight)
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .onAppear { haptic.prepare() }
            .onChange(of: isPressed) { pressed in
                if pressed { haptic.impactOccurred() }
            }
            .gesture(keyGesture)
    }
}
