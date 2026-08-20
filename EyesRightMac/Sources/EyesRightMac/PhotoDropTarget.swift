import SwiftUI
import UniformTypeIdentifiers

struct PhotoDropTarget: View {
    let isEnabled: Bool
    let onDrop: (URL) -> Void
    var onTargeted: (Bool) -> Void = { _ in }

    var body: some View {
        Color.clear
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { false },
                set: { targeted in
                    onTargeted(isEnabled && targeted)
                }
            )) { providers in
                guard isEnabled else { return false }
                guard let provider = providers.first else { return false }

                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isFileURL
                    else { return }

                    let ext = url.pathExtension.lowercased()
                    guard ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) else { return }

                    DispatchQueue.main.async {
                        onDrop(url)
                    }
                }
                return true
            }
    }
}
