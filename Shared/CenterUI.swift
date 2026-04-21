import SwiftUI

func centerHeader<Actions: View>(title: String, subtitle: String, @ViewBuilder actions: () -> Actions) -> some View {
    HStack(alignment: .top, spacing: ClawSpacing.md) {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ClawPalette.textPrimary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(ClawPalette.textSecondary)
        }

        Spacer()

        actions()
    }
}

func infoPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: ClawSpacing.sm) {
        Text(title)
            .font(.headline)
            .foregroundStyle(ClawPalette.textPrimary)
        content()
    }
    .padding(ClawSpacing.md)
    .clawCard()
}

func placeholderText(_ text: String) -> some View {
    Text(text)
        .foregroundStyle(ClawPalette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
}

func splitDetailShell<Sidebar: View, Detail: View>(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) -> some View {
    HStack(alignment: .top, spacing: ClawSpacing.md) {
        sidebar()
            .frame(maxWidth: 320, alignment: .topLeading)

        detail()
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

func selectableRow(title: String, subtitle: String? = nil, isSelected: Bool = false, trailing: String? = nil, tint: Color = ClawPalette.accent) -> some View {
    HStack(spacing: ClawSpacing.sm) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(ClawPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let trailing, !trailing.isEmpty {
            Text(trailing)
                .font(.caption)
                .foregroundStyle(tint)
        }
    }
    .padding(.horizontal, ClawSpacing.sm)
    .padding(.vertical, 10)
    .background(isSelected ? ClawPalette.accentSoft : ClawPalette.elevated.opacity(0.35))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
}

func detailCard(title: String, badge: String? = nil, lines: [(String, String)], description: String? = nil, footer: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: ClawSpacing.md) {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ClawPalette.textPrimary)
            Spacer()
            if let badge, !badge.isEmpty {
                Text(badge)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ClawPalette.accentSoft)
                    .foregroundStyle(ClawPalette.accent)
                    .clipShape(Capsule())
            }
        }

        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                LabeledValue(label: line.0, value: line.1)
            }
        }

        if let description, !description.isEmpty {
            Text(description)
                .foregroundStyle(ClawPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let footer, !footer.isEmpty {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(ClawPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(ClawSpacing.md)
    .clawCard()
}
