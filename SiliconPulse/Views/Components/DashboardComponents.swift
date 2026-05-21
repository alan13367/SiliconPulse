import SwiftUI
import Charts

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(DesignTokens.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nativeSectionBackground()
    }
}

struct MetricRow: View {
    let label: String?
    let value: String

    init(_ label: String? = nil, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        if let label {
            LabeledContent(label) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        } else {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct UsageGauge: View {
    let value: Double
    let showLabel: Bool

    init(value: Double, showLabel: Bool = true) {
        self.value = value
        self.showLabel = showLabel
    }

    var body: some View {
        Gauge(value: value, in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            if showLabel {
                Text(Formatters.percentage(value))
                    .monospacedDigit()
            }
        }
        .gaugeStyle(.linearCapacity)
        .tint(DesignTokens.usageTint(value))
    }
}

struct SparklineChart: View {
    let data: [Double]
    var yDomain: ClosedRange<Double>? = nil
    var accentTint: Bool = false

    private var strokeColor: Color {
        accentTint ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.45)
    }

    private var fillColor: Color {
        accentTint ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    var body: some View {
        if data.count > 1 {
            Chart(Array(data.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(fillColor)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(strokeColor)
                .interpolationMethod(.catmullRom)
            }
            .applyIf(yDomain != nil) { chart in
                chart.chartYScale(domain: yDomain!)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.sparklineHeight, idealHeight: DesignTokens.sparklineHeight)
            .clipped()
        }
    }
}

struct TemperatureBadge: View {
    let temperature: Double
    let useFahrenheit: Bool

    private var statusColor: Color {
        switch temperature {
        case ..<40: return .green
        case 40..<55: return .yellow
        case 55..<70: return .orange
        case 70..<85: return .red
        default: return .purple
        }
    }

    var body: some View {
        Label {
            Text(Formatters.temperature(temperature, useFahrenheit: useFahrenheit))
                .monospacedDigit()
        } icon: {
            Image(systemName: "thermometer.medium")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
        .foregroundStyle(statusColor)
    }
}

extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
