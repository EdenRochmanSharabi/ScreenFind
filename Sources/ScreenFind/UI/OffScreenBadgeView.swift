import SwiftUI

struct OffScreenBadgeView: View {
    let matchCount: Int
    let direction: String  // "below" or "above"

    var body: some View {
        HStack(spacing: 4) {
            Text("\(matchCount) more match\(matchCount == 1 ? "" : "es") \(direction)")
                .font(.system(size: 11, weight: .medium))
            Image(systemName: direction == "below" ? "arrow.down" : "arrow.up")
                .font(.system(size: 10))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.orange.opacity(0.9), in: Capsule())
        .foregroundColor(.white)
    }
}
