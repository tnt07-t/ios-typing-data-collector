import SwiftUI
import UIKit

struct LoggingTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onEvent: (InputEventData) -> Void
    var buildEventData: (String, String, String, Int, Int, InputEventType) -> InputEventData
    var onReturn: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.keyboardType = .asciiCapable
        tf.returnKeyType = .next
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 17)
        DispatchQueue.main.async {
            tf.becomeFirstResponder()
        }
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LoggingTextField

        init(_ parent: LoggingTextField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let textBefore = textField.text ?? ""

            // Classify event
            let eventType: InputEventType
            if string.isEmpty && range.length > 0 {
                eventType = .delete
            } else if string.count == 1 && range.length == 0 {
                eventType = .insert
            } else if string.count == 1 && range.length > 0 {
                eventType = .replace
            } else if string.count > 1 {
                eventType = .paste
            } else {
                // no-op (empty replacement with no range)
                return false
            }

            // Compute textAfter manually
            let nsTextBefore = textBefore as NSString
            let textAfter = nsTextBefore.replacingCharacters(in: range, with: string)

            // Build and fire event
            let eventData = parent.buildEventData(
                textBefore,
                textAfter,
                string,
                range.location,
                range.length,
                eventType
            )
            parent.onEvent(eventData)

            // Update binding manually
            parent.text = textAfter
            textField.text = textAfter

            return false // We handled the update
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn?()
            return true
        }
    }
}
