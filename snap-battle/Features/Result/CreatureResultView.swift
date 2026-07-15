import SwiftUI
import UIKit

struct CreatureResultView: View {
    let creature: Creature
    let reset: () -> Void
    let onBattle: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = UIImage(data: creature.extractedSubject) { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 260).background(.black.opacity(0.06), in: .rect(cornerRadius: 20)) }
                Text(creature.name).font(.largeTitle.bold())
                Text(creature.role.rawValue.capitalized).font(.headline).foregroundStyle(.tint)
                Text(creature.description)
                Text(creature.temperament).font(.subheadline).foregroundStyle(.secondary)
                HStack { ForEach(creature.tags, id: \.self) { Text($0).font(.caption).padding(8).background(.tint.opacity(0.12), in: Capsule()) } }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stats").font(.title3.bold())
                    StatRowView(name: "Defense", value: creature.stats.defense)
                    StatRowView(name: "Power", value: creature.stats.power)
                    StatRowView(name: "Agility", value: creature.stats.agility)
                    StatRowView(name: "Energy", value: creature.stats.energy)
                }
                Button("Battle", action: onBattle).buttonStyle(.borderedProminent)
                Button("Create another", action: reset).buttonStyle(.borderedProminent)
            }.padding()
        }
        .accessibilityElement(children: .contain)
    }
}
