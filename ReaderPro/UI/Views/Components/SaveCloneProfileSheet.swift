import SwiftUI

/// Sheet for naming and saving a cloned voice profile
struct SaveCloneProfileSheet: View {

    @Binding var profileName: String
    var isSaving: Bool
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Voice Profile")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            TextField("Profile name (e.g. Morgan Freeman)", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button {
                    onSave()
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}
