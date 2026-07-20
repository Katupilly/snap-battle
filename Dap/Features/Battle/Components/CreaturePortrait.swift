import SwiftUI
import UIKit

struct CreaturePortrait: View {
    private let image: UIImage?
    private let name: String

    init(creature: Creature) {
        image = UIImage(data: creature.extractedSubject)
        name = creature.name
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .bold))
                    Text(name)
                        .font(.caption.monospaced())
                }
                .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: 16))
        .accessibilityLabel("Portrait of \(name)")
    }
}
