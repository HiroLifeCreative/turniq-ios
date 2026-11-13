import ActivityKit
import WidgetKit
import SwiftUI
import TurniqShared

/// Actividad en Vivo del turno en curso: contador desde la entrada
/// real, barra hacia la salida programada y neto por hora. Aparece en
/// la pantalla de bloqueo y en la Dynamic Island mientras trabajas.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            LockScreenLiveView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WColor.band)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "turniq://abrir"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle().fill(WColor.hex(context.attributes.colorHex)).frame(width: 8, height: 8)
                        Text(context.attributes.jobName)
                            .font(.system(size: 15, weight: .bold)).lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.start, style: .timer)
                        .font(.system(size: 20, weight: .bold)).monospacedDigit()
                        .foregroundStyle(WColor.orange)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if let end = context.state.scheduledEnd, end > context.state.start {
                            ProgressView(timerInterval: context.state.start...end, countsDown: false) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(WColor.button)
                        }
                        HStack {
                            Text("Neto \(WFmt.money(context.state.netPerHour, hidden: context.state.hideMoney))/h")
                            Spacer()
                            if let pin = context.attributes.pin, !pin.isEmpty {
                                Text("PIN \(pin)")
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "clock.fill").foregroundStyle(WColor.orange)
            } compactTrailing: {
                Text(context.state.start, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(WColor.orange)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "clock.fill").foregroundStyle(WColor.orange)
            }
            .widgetURL(URL(string: "turniq://abrir"))
        }
    }
}

struct LockScreenLiveView: View {
    var attributes: ShiftActivityAttributes
    var state: ShiftActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRABAJANDO")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WColor.orange)
                    HStack(spacing: 6) {
                        Circle().fill(WColor.hex(attributes.colorHex)).frame(width: 8, height: 8)
                        Text(attributes.jobName)
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(state.start, style: .timer)
                    .font(.system(size: 28, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            if let end = state.scheduledEnd, end > state.start {
                ProgressView(timerInterval: state.start...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(WColor.button)
            }
            HStack {
                Text("Neto \(WFmt.money(state.netPerHour, hidden: state.hideMoney))/h")
                if let end = state.scheduledEnd {
                    Text("· Salida \(end, style: .time)")
                }
                Spacer()
                if let pin = attributes.pin, !pin.isEmpty {
                    Text("PIN \(pin)")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
    }
}
