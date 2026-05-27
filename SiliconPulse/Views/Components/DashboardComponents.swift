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

    private var clampedValue: Double {
        min(max(value, 0), 100)
    }

    init(value: Double, showLabel: Bool = true) {
        self.value = value
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                let fillWidth = geometry.size.width * CGFloat(clampedValue / 100)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))

                    Capsule()
                        .fill(DesignTokens.usageTint(clampedValue).gradient)
                        .frame(width: fillWidth)
                }
            }
            .frame(height: DesignTokens.gaugeHeight)
            .accessibilityHidden(true)

            if showLabel {
                Text(Formatters.percentage(value))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.usageTint(clampedValue))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage")
        .accessibilityValue(Formatters.percentage(value))
    }
}

struct MetricTrendChart: View {
    let data: [Double]
    var secondaryData: [Double] = []
    var yDomain: ClosedRange<Double>? = nil
    var tint: Color = .accentColor
    var secondaryTint: Color? = nil
    var valueFormatter: (Double) -> String = { Formatters.percentage($0) }

    private var primaryPoints: [(index: Int, value: Double)] {
        data.enumerated().map { ($0.offset, $0.element) }
    }

    private var secondaryPoints: [(index: Int, value: Double)] {
        secondaryData.enumerated().map { ($0.offset, $0.element) }
    }

    private var allValues: [Double] {
        data + secondaryData
    }

    private var resolvedDomain: ClosedRange<Double> {
        if let yDomain { return yDomain }
        guard let minValue = allValues.min(), let maxValue = allValues.max() else {
            return 0...1
        }

        if minValue == maxValue {
            let padding = max(abs(maxValue) * 0.2, 1)
            return max(0, minValue - padding)...(maxValue + padding)
        }

        let padding = max((maxValue - minValue) * 0.18, 1)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    private var xDomain: ClosedRange<Int> {
        0...max(max(data.count, secondaryData.count) - 1, 1)
    }

    private var peakValue: Double {
        allValues.max() ?? 0
    }

    private var timeLabel: String {
        data.count >= 60 ? "60s" : "Last \(max(data.count, 1))s"
    }

    private var referenceValues: [Double] {
        let lower = resolvedDomain.lowerBound
        let upper = resolvedDomain.upperBound
        let middle = lower + (upper - lower) / 2
        return [lower, middle, upper]
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: DesignTokens.trendChartRadius, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.trendChartRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

            chart
                .padding(.horizontal, 6)
                .padding(.vertical, 5)

            HStack {
                Text(timeLabel)
                Spacer()
                Text("Peak \(valueFormatter(peakValue))")
            }
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.trendChartHeight, idealHeight: DesignTokens.trendChartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trend")
        .accessibilityValue("Peak \(valueFormatter(peakValue))")
    }

    private var chart: some View {
        Chart {
            ForEach(referenceValues, id: \.self) { value in
                RuleMark(y: .value("Reference", value))
                    .foregroundStyle(Color.primary.opacity(0.08))
                    .lineStyle(StrokeStyle(lineWidth: 0.75))
            }

            if primaryPoints.count > 1 {
                ForEach(primaryPoints, id: \.index) { point in
                    AreaMark(
                        x: .value("Time", point.index),
                        yStart: .value("Baseline", resolvedDomain.lowerBound),
                        yEnd: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(tint.opacity(0.88))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let last = primaryPoints.last {
                    PointMark(
                        x: .value("Time", last.index),
                        y: .value("Value", last.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(24)
                }
            } else {
                RuleMark(y: .value("Baseline", resolvedDomain.lowerBound))
                    .foregroundStyle(Color.primary.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            }

            if let secondaryTint, secondaryPoints.count > 1 {
                ForEach(secondaryPoints, id: \.index) { point in
                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Secondary Value", point.value)
                    )
                    .foregroundStyle(secondaryTint.opacity(0.78))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let last = secondaryPoints.last {
                    PointMark(
                        x: .value("Time", last.index),
                        y: .value("Secondary Value", last.value)
                    )
                    .foregroundStyle(secondaryTint)
                    .symbolSize(18)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: resolvedDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .clipped()
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
        .fontWeight(.semibold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.18), in: Capsule())
        .overlay {
            Capsule()
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        }
        .foregroundStyle(statusColor)
    }
}

struct ControlPillLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            }
    }
}

struct PanelIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? .white : tint)
            .frame(width: 28, height: 28)
            .background(
                tint.opacity(configuration.isPressed ? 0.75 : 0.16),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.3), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
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

    @ViewBuilder
    func applyIfLet<Value, T: View>(_ value: Value?, transform: (Self, Value) -> T) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
