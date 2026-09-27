import SwiftUI

/// Every bonus the board currently grants, one line per stat: the answer to
/// "how much am I actually getting" that five hundred small tiles can't give
/// at a glance.
struct TotalsBoard: View {
    let totals: [LegacyTotal]

    var body: some View {
        Group {
            if totals.isEmpty {
                empty
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(totals) { total in
                            row(total)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 28))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
            Text("Nothing taken yet. Buy a node on the board and its bonus shows up here.")
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchmentDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ total: LegacyTotal) -> some View {
        HStack {
            Text(total.stat.displayName)
                .font(FLTheme.Typeface.body(13))
                .foregroundStyle(FLTheme.Palette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(total.displayText)
                .font(FLTheme.Typeface.number(14))
                .foregroundStyle(FLTheme.Palette.emberBright)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(FLTheme.Palette.stoneRaised.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(FLTheme.Palette.rim, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
