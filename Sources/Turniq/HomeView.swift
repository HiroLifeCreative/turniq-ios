import SwiftUI

/// Pestaña Inicio — héroe oscuro con reloj en vivo, estado por color,
/// recordatorio del próximo turno, próximos cobros y próximos turnos.
struct HomeView: View {
    @EnvironmentObject var store: Store
    var goTab: (Int) -> Void = { _ in }

    @State private var showClockSheet = false
    @State private var showEditEntry = false
    @State private var showNewShift = false
    @State private var entryDraft = Date()

    private enum HeroState { case working, missed, upcoming, idle }

    private var fmt12: Bool { store.settings.formatoHora == "12h" }
    private var hidden: Bool { store.settings.dineroOculto }

    private var todayShifts: [Shift] {
        let today = Calc.todayYmd()
        return store.shifts
            .filter { $0.fecha == today && !$0.esLibre }
            .sorted { $0.horaEntrada < $1.horaEntrada }
    }

    private var totals: Calc.WeekTotals {
        let mon = Calc.monday(of: Calc.todayYmd())
        let week = store.shifts.filter { Calc.monday(of: $0.fecha) == mon }
        return Calc.weekTotals(
            shifts: Calc.onlyWorked(week),
            jobsById: store.jobsById,
            umbralExtraHrs: store.settings.umbralExtraHrs,
            multExtra: store.settings.multExtra
        )
    }

    /// Próximos 3 turnos (sin contar el que está en curso).
    private var upcoming: [Shift] {
        let today = Calc.todayYmd()
        let now = Calc.nowHHMM()
        let openId = store.openShift?.id
        return Array(store.shifts
            .filter { !$0.esLibre && $0.id != openId && ($0.fecha > today || ($0.fecha == today && $0.horaEntrada >= now)) }
            .sorted { ($0.fecha + $0.horaEntrada) < ($1.fecha + $1.horaEntrada) }
            .prefix(3))
    }

    private var heroState: HeroState {
        if store.openShift != nil { return .working }
        let now = Calc.hmToMin(Calc.nowHHMM()) ?? 0
        let day = todayShifts
        let missed = day.contains { s in
            s.horaEntradaReal == nil && Calc.endDate(s) == s.fecha
                && (s.horaSalida.flatMap(Calc.hmToMin) ?? 1440) < now
        }
        if missed && !day.contains(where: { (Calc.hmToMin($0.horaEntrada) ?? 0) > now }) { return .missed }
        if day.contains(where: { (Calc.hmToMin($0.horaEntrada) ?? 0) > now }) { return .upcoming }
        return .idle
    }

    private func stateColor(_ st: HeroState) -> Color {
        switch st {
        case .working: return T.orange
        case .missed: return T.hex("#E5484D")
        case .upcoming: return T.hex("#30A46C")
        case .idle: return T.hex("#8B8D98")
        }
    }

    private func stateLabel(_ st: HeroState) -> String {
        switch st {
        case .working: return L("Trabajando")
        case .missed: return L("No marcado")
        case .upcoming: return L("Próximamente")
        case .idle: return ""
        }
    }

    var body: some View {
        // Reloj en vivo: cada segundo con un turno abierto; si no,
        // cada 30 s para la cuenta atrás del próximo turno.
        TimelineView(.periodic(from: .now, by: store.openShift != nil ? 1 : 30)) { ctx in
            content(now: ctx.date)
        }
        .sheet(isPresented: $showClockSheet) { clockSheet }
        .sheet(isPresented: $showEditEntry) { editEntrySheet }
        .sheet(isPresented: $showNewShift) {
            ShiftFormView(editing: nil, defaultFecha: Calc.todayYmd())
        }
    }

    private func content(now: Date) -> some View {
        let open = store.openShift
        let st = heroState
        let next = open == nil ? upcoming.first : nil
        return ScrollView {
            VStack(spacing: 12) {
                hero(open: open, state: st, now: now)

                if let open {
                    VStack(spacing: 8) {
                        PrimaryButton(title: L("Marcar salida"), color: stateColor(st), textColor: .white) {
                            store.clockOut(shiftId: open.id)
                        }
                        GhostButton(
                            title: L("Editar entrada · \(Calc.fmtTime(open.horaEntradaReal ?? open.horaEntrada, format12: fmt12))"),
                            icon: "pencil"
                        ) {
                            entryDraft = Calc.date(Calc.todayYmd(), open.horaEntradaReal ?? open.horaEntrada) ?? Date()
                            showEditEntry = true
                        }
                    }
                } else if todayShifts.contains(where: { $0.horaEntradaReal == nil }) {
                    PrimaryButton(title: L("Marcar entrada")) { showClockSheet = true }
                }

                if let next { reminder(next, now: now) }

                PaydaysCard()

                Button { showNewShift = true } label: {
                    Text(L("+ Añadir turno"))
                        .font(.turniq(15, .bold))
                        .foregroundStyle(T.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressStyle())
                .disabled(store.jobs.isEmpty)
                .opacity(store.jobs.isEmpty ? 0 : 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Próximos turnos"))
                        .font(.turniq(19, .bold)).tracking(-0.3)
                        .foregroundStyle(T.text)
                    if upcoming.isEmpty {
                        emptyCard
                    } else {
                        ForEach(upcoming) { s in
                            Button { goTab(1) } label: { upcomingCard(s) }
                                .buttonStyle(PressStyle())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .padding(.bottom, dockClearance)
        }
        .sensoryFeedback(.success, trigger: open?.id)
    }

    // MARK: Héroe

    private func hero(open: Shift?, state st: HeroState, now: Date) -> some View {
        let t = totals
        return DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(L("NETO TRABAJADO · ESTA SEMANA"))
                        .font(.turniqMono)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    if st != .idle {
                        HStack(spacing: 6) {
                            Circle().fill(stateColor(st)).frame(width: 8, height: 8)
                            Text(stateLabel(st))
                                .font(.turniq(12, .bold)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.12), in: Capsule())
                    }
                }

                HStack(alignment: .center) {
                    if hidden {
                        Text("•••••")
                            .font(.turniq(44, .bold)).tracking(-1.5)
                            .foregroundStyle(.white)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$").font(.turniq(28, .bold)).foregroundStyle(.white.opacity(0.7))
                            Text(String(Calc.money(t.net).dropFirst()))
                                .font(.turniq(44, .bold)).tracking(-1.5)
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                    Spacer(minLength: 8)
                    // Ojito: oculta/muestra el dinero al instante, sin PIN.
                    Button {
                        store.setSettings { $0.dineroOculto.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hidden ? "eye.slash" : "eye")
                                .font(.system(size: 15, weight: .semibold))
                            Text(hidden ? L("Mostrar") : L("Ocultar")).font(.turniqMono)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(PressStyle())
                }

                if let open { liveBlock(open, color: stateColor(st), now: now) }

                HStack(spacing: 8) {
                    chip(String(format: "%.1fh", t.hours), L("Horas"))
                    chip(T.cash(t.gross, hidden: hidden), L("Bruto"))
                    chip(T.cash(t.taxes, hidden: hidden), "Taxes")
                }
            }
        }
    }

    private func chip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.turniq(15, .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.turniq(10)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Reloj en vivo con anillo de progreso + neto estimado.
    private func liveBlock(_ s: Shift, color: Color, now: Date) -> some View {
        let job = store.job(id: s.jobId)
        let inHm = s.horaEntradaReal ?? s.horaEntrada
        let start = Calc.date(s.fecha, inHm) ?? now
        let secs = max(0, Int(now.timeIntervalSince(start)))
        var totalSecs = 8 * 3600
        if let out = s.horaSalida, let i = Calc.hmToMin(inHm), var o = Calc.hmToMin(out) {
            if o <= i { o += 1440 }
            totalSecs = max(60, (o - i) * 60)
        }
        let pct = min(1, Double(secs) / Double(totalSecs))
        let rate = job?.sueldoHora ?? 0
        let tax = (job?.taxPct ?? 0) / 100
        let liveNet = rate * Double(secs) / 3600 * (1 - tax)

        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(T.button, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(String(format: "%02d:%02d", secs / 3600, (secs % 3600) / 60))
                        .font(.turniq(16, .bold)).monospacedDigit().foregroundStyle(.white)
                    Text(String(format: ":%02d", secs % 60))
                        .font(.turniq(11)).monospacedDigit().foregroundStyle(T.button)
                }
            }
            .frame(width: 88, height: 88)
            .padding(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("\(job?.nombre ?? "") · En vivo"))
                    .font(.turniqMono).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                Text(L("Neto estimado"))
                    .font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                Text(T.cash(liveNet, hidden: hidden))
                    .font(.turniq(24, .bold)).monospacedDigit().foregroundStyle(color)
                if let out = s.horaSalida {
                    Text(L("Salida \(Calc.fmtTime(out, format12: fmt12)) · \(Int((pct * 100).rounded()))%"))
                        .font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Recordatorio del próximo turno

    private func countdown(_ s: Shift, now: Date) -> String? {
        guard let start = Calc.date(s.fecha, s.horaEntrada) else { return nil }
        let mins = Int((start.timeIntervalSince(now) / 60).rounded())
        if mins <= 1 { return nil }
        if mins >= 1440 { return "\(mins / 1440) d \((mins % 1440) / 60) h" }
        if mins >= 60 { return "\(mins / 60) h \(mins % 60) min" }
        return "\(mins) min"
    }

    private func dayLabel(_ ymd: String) -> String {
        let today = Calc.todayYmd()
        if ymd == today { return L("Hoy") }
        if ymd == Calc.addDays(today, 1) { return L("Mañana") }
        return Calc.weekdayDate(ymd)
    }

    private func reminder(_ s: Shift, now: Date) -> some View {
        let job = store.job(id: s.jobId)
        let cd = countdown(s, now: now)
        return Button { goTab(1) } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(T.button)
                        .frame(width: 44, height: 44)
                        .background(T.button.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cd.map { L("Tu turno empieza en \($0)") } ?? L("¡Tu turno empieza ya!"))
                            .font(.turniq(15, .bold)).foregroundStyle(T.text).lineLimit(1)
                        Text("\(job?.nombre ?? "") · \(dayLabel(s.fecha)) · \(Calc.rangeLabel(s, format12: fmt12))")
                            .font(.turniq(12)).foregroundStyle(T.text2).lineLimit(1)
                        if let pin = job?.pinMarcaje, !pin.isEmpty {
                            Label("PIN \(pin)", systemImage: "key")
                                .font(.turniq(12)).foregroundStyle(T.text2)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(T.text3)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    // MARK: Próximos turnos

    private func upcomingCard(_ s: Shift) -> some View {
        let job = store.job(id: s.jobId)
        let isToday = s.fecha == Calc.todayYmd()
        let stations = s.estacionIds.compactMap { id in
            job?.estaciones.first(where: { $0.id == id })?.nombre
        }
        return Card {
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    Text(String(Int(s.fecha.suffix(2)) ?? 0))
                        .font(.turniq(28, .bold))
                        .foregroundStyle(isToday ? T.primary : T.text)
                    Text(Calc.daysShort[Calc.weekdayIndex(s.fecha)])
                        .font(.turniqMono).foregroundStyle(T.text3)
                }
                .frame(minWidth: 52)
                Rectangle().fill(T.line).frame(width: 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(T.hex(job?.color ?? "#0064E0")).frame(width: 8, height: 8)
                        Text(job?.nombre ?? "")
                            .font(.turniq(16, .bold)).foregroundStyle(T.text).lineLimit(1)
                    }
                    Text(Calc.rangeLabel(s, format12: fmt12))
                        .font(.turniq(13)).foregroundStyle(T.text2)
                    if !stations.isEmpty {
                        Text(stations.joined(separator: ", "))
                            .font(.turniq(13)).foregroundStyle(T.text3).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if isToday {
                    Text(L("HOY"))
                        .font(.turniq(10, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(T.primary, in: Capsule())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 6) {
            Text(L("Tu semana empieza aquí"))
                .font(.turniq(17, .bold)).foregroundStyle(T.text)
            Text(store.jobs.isEmpty
                 ? L("Añade tus trabajos y después programa tus turnos.")
                 : L("Programa tus turnos en la pestaña Semana."))
                .font(.turniq(13)).foregroundStyle(T.text3)
                .multilineTextAlignment(.center)
            Button { goTab(store.jobs.isEmpty ? 2 : 1) } label: {
                Text(store.jobs.isEmpty ? L("+ Trabajos") : L("+ Añadir turno"))
                    .font(.turniq(15, .bold)).foregroundStyle(T.text)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(T.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(T.line, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(T.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(T.line, lineWidth: 1))
    }

    // MARK: Hojas

    /// Elegir qué turno de hoy se marca.
    private var clockSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(todayShifts.filter { $0.horaEntradaReal == nil }) { s in
                        let job = store.job(id: s.jobId)
                        Button {
                            store.clockIn(shiftId: s.id)
                            showClockSheet = false
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(T.hex(job?.color ?? "#0064E0")).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(job?.nombre ?? "") · \(Calc.rangeLabel(s, format12: fmt12))")
                                        .font(.turniq(15, .bold)).foregroundStyle(T.text)
                                    if let pin = job?.pinMarcaje, !pin.isEmpty {
                                        Label("PIN \(pin)", systemImage: "key")
                                            .font(.turniq(12)).foregroundStyle(T.text2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(T.text3)
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(T.line).frame(height: 0.5)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(L("Marcar entrada"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    /// Corregir la hora de entrada del turno en curso.
    private var editEntrySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker(L("Entrada real"), selection: $entryDraft, displayedComponents: [.hourAndMinute])
                    .font(.turniq(16, .medium))
                HStack(spacing: 8) {
                    ForEach([-30, -15, -5, 5], id: \.self) { d in
                        Button {
                            entryDraft = entryDraft.addingTimeInterval(TimeInterval(d * 60))
                        } label: {
                            Text(d > 0 ? "+\(d) min" : "−\(abs(d)) min")
                                .font(.turniq(13)).foregroundStyle(T.text)
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .overlay(Capsule().strokeBorder(T.line, lineWidth: 1))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                Text(L("¿Marcaste en el reloj del trabajo y olvidaste marcar en la app? Pon la hora real: el contador y el dinero se recalculan al momento."))
                    .font(.turniq(13)).foregroundStyle(T.text2)
                PrimaryButton(title: L("Guardar")) {
                    if let open = store.openShift {
                        store.setRealEntry(shiftId: open.id, hm: Calc.hhmm(entryDraft))
                    }
                    showEditEntry = false
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(L("Editar entrada"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
