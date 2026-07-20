import SwiftUI

struct StatRowView: View {
    let name: String
    let value: Int
    var body: some View {
        HStack { Text(name); Spacer(); Text("\(value)").monospacedDigit().bold() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(name), \(value) out of 100")
    }
}
