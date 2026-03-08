import ContactsUI
import SwiftUI

struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onContactsSelected: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(value: true)
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactsSelected: onContactsSelected, dismiss: dismiss)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        var onContactsSelected: ([CNContact]) -> Void
        var dismiss: DismissAction

        init(onContactsSelected: @escaping ([CNContact]) -> Void, dismiss: DismissAction) {
            self.onContactsSelected = onContactsSelected
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onContactsSelected(contacts)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            dismiss()
        }
    }
}
