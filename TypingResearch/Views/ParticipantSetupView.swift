import SwiftUI
import SwiftData
import UIKit

struct ParticipantSetupView: View {
    @Environment(\.modelContext) private var modelContext
    var sessionManager: SessionManager

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var ageText: String = ""
    @State private var dominantHand: DominantHand = .right

    // Session duration
    @State private var durationOption: DurationOption = .fifteen
    @State private var customMinutes: Int = 1
    @State private var customSeconds: Int = 0

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    enum DurationOption: String, CaseIterable, Identifiable {
        case fifteen = "15s"
        case thirty = "30s"
        case fortyfive = "45s"
        case oneMin = "1 min"
        case custom = "Custom"
        var id: String { rawValue }
    }

    var resolvedDurationSeconds: Int {
        switch durationOption {
        case .fifteen:   return 15
        case .thirty:    return 30
        case .fortyfive: return 45
        case .oneMin:    return 60
        case .custom:
            let total = customMinutes * 60 + customSeconds
            return max(5, total)
        }
    }

    var formattedCustomDuration: String {
        let total = resolvedDurationSeconds
        if total < 60 { return "\(total)s" }
        let m = total / 60
        let s = total % 60
        return s == 0 ? "\(m) min" : "\(m)m \(s)s"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Participant Information") {
                    TextField("First Name", text: $firstName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    TextField("Last Name", text: $lastName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    TextField("Age (optional)", text: $ageText)
                        .keyboardType(.numberPad)

                    Picker("Dominant Hand", selection: $dominantHand) {
                        Text("Right").tag(DominantHand.right)
                        Text("Left").tag(DominantHand.left)
                        Text("Ambidextrous").tag(DominantHand.ambidextrous)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Session Duration") {
                    Picker("Duration", selection: $durationOption) {
                        ForEach(DurationOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)

                    if durationOption == .custom {
                        customDurationPicker
                    } else {
                        Text("Session will run for \(durationOption.rawValue), generating phrases continuously.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Device Info") {
                    LabeledContent("Device", value: DeviceInfo.modelName)
                    LabeledContent("iOS", value: DeviceInfo.systemVersion)
                    LabeledContent("Screen", value: "\(Int(DeviceInfo.screenWidthPt)) x \(Int(DeviceInfo.screenHeightPt)) pt")
                }

                Section {
                    Button(action: startSession) {
                        HStack {
                            Spacer()
                            Text("Start Session")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.orange)
                    // Name fields are optional — session can start without them
                }
            }
            .navigationTitle("TypingResearch")
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { notification in
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    sessionManager.measuredKeyboardHeight = frame.height
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        sessionManager.safeAreaBottom = window.safeAreaInsets.bottom
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Custom Duration Wheel Picker

    private var customDurationPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                // Minutes wheel
                VStack(spacing: 2) {
                    Text("MIN")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Picker("Minutes", selection: $customMinutes) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                }

                Text(":")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                // Seconds wheel
                VStack(spacing: 2) {
                    Text("SEC")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Picker("Seconds", selection: $customSeconds) {
                        ForEach(0..<60) { s in
                            Text(String(format: "%02d", s)).tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                }
            }
            .frame(maxWidth: .infinity)

            Text("Duration: \(formattedCustomDuration)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Start

    private func startSession() {
        let fn = firstName.trimmingCharacters(in: .whitespaces)
        let ln = lastName.trimmingCharacters(in: .whitespaces)
        let age: Int? = ageText.isEmpty ? nil : Int(ageText)

        let participant = Participant(
            firstName: fn.isEmpty ? "Anonymous" : fn,
            lastName: ln.isEmpty ? "" : ln,
            age: age,
            dominantHand: dominantHand,
            deviceModel: DeviceInfo.modelName,
            systemVersion: DeviceInfo.systemVersion,
            screenWidthPt: DeviceInfo.screenWidthPt,
            screenHeightPt: DeviceInfo.screenHeightPt,
            appVersion: DeviceInfo.appVersion
        )
        modelContext.insert(participant)
        sessionManager.configure(modelContext: modelContext)
        sessionManager.startSession(participant: participant, durationSeconds: resolvedDurationSeconds)
    }
}
