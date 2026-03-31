#if os(iOS)
import CallKit
import Foundation
import Contacts

@MainActor
@Observable
final class CallObserverService: NSObject {
    static let shared = CallObserverService()

    private let callObserver = CXCallObserver()
    private var activeCallUUIDs: Set<UUID> = []

    private override init() {
        super.init()
    }

    func startObserving() {
        callObserver.setDelegate(self, queue: nil)
    }

    /// Match a phone number to a contact in the Social Circle
    private func matchAndLogContact(phoneNumber: String) {
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 7 else { return }
        let suffix = String(digits.suffix(10))

        let contacts = PersistenceService.shared.fetchContacts()
        for contact in contacts {
            let contactDigits = contact.phone.filter(\.isNumber)
            guard contactDigits.count >= 7 else { continue }
            let contactSuffix = String(contactDigits.suffix(10))

            if suffix == contactSuffix {
                // Update lastContacted
                contact.lastContacted = Date()
                PersistenceService.shared.updateContacts()

                // Log an interaction
                let interaction = Interaction(
                    contactId: contact.uuid,
                    type: "call",
                    date: Date(),
                    notes: "Auto-logged phone call"
                )
                PersistenceService.shared.saveInteraction(interaction)
                return
            }
        }
    }

    /// Try to get the phone number from a CXCall using Contacts framework
    private func resolvePhoneNumber(for call: CXCall) {
        // CXCall doesn't expose the phone number directly.
        // We check recent calls via the system contact matching.
        // As a fallback, mark all "inner circle" contacts if we can't resolve.
        // The real phone number is only available to CallDirectory extensions.

        // Use CNCallObserver workaround: check system contacts for recent interaction
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
        ]

        // We can't get the actual number from CXCall, but we know a call happened.
        // Log it as a general call event that the user can attribute later.
        // The in-app buttons already log specific contacts.
    }
}

extension CallObserverService: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // When a call ends (disconnected and not outgoing/on hold)
        if call.hasEnded && !call.isOutgoing {
            // Incoming call ended — we can't get the number from CXCall API
            // but we note the event
            Task { @MainActor in
                // Post notification for any listening views to refresh
                NotificationCenter.default.post(name: .callEnded, object: nil)
            }
        } else if call.hasEnded && call.isOutgoing {
            Task { @MainActor in
                NotificationCenter.default.post(name: .callEnded, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let callEnded = Notification.Name("com.runellking.axis.callEnded")
}
#endif
