import SwiftUI

/// Pestaña Semana — columna del día a la izquierda, tarjetas de turno
/// con barra de estado por color, hora extra por trabajo y total.
struct WeekView: View {
    @EnvironmentObject var store: Store
    @State private var weekOffset = 0
    @State private var editing: Shift? = nil
    @State private var creating: FechaRef? = nil
    @State private var confirmDup = false
    @State private var confirmDelete: Shift? = nil
    @State private var dupDone = false
    @State private var detail: Shift? = nil

    private var fmt12: Bool { store.settings.formatoHora == "12h" }
    private var hidden: Bool { store.settings.dineroOculto }

    private var monday: String {
        Calc.addDays(Calc.monday(of: Calc.todayYmd()), weekOffset * 7)
    }
    private var days: [String] { (0..<7).map { Calc.addDays(monday, $0) } }
    private var weekShifts: [Shift] {
        let mon = monday
        return store.shifts.filter { Calc.monday(of: $0.fecha) == mon }
    }

    var body: some View {
        let inWeek = weekShifts
        let worked = Calc.onlyWorked(inWeek)
        let totals = Calc.weekTotals(
            shifts: worked, jobsById: store.jobsById,
            umbralExtraHrs: store.settings.umbralExtraHrs,
            multExtra: store.settings.multExtra)
        ScrollView {
            VStack(spacing: 12) {
                weekNav
                if store.settings.mostrarHoraExtra && store.settings.umbralExtraHrs > 0 {
                    otCard(worked: worked, totals: totals)
                }
                ForEach(Array(days.enumerated()), id: \.element) { idx, day in
                    daySection(day: day, name: Calc.daysShort[idx], inWeek: inWeek)
                }
                totalsCard(totals)
                GhostButton(title: L("Duplicar a la próxima semana"), icon: "plus.square.on.square") {
                    confirmDup = true
                }
                .padding(.top, 4)
                if dupDone {
                    Text(L("✓ Semana duplicada"))
                        .font(.turniq(14, .bold)).foregroundStyle(T.success)
                }
            }
            .padding(16)
            .padding(.bottom, dockClearance)
        }
        .sheet(item: $detail) { s in
            // Tras cerrar el detalle se espera a que termine la
            // animación antes de abrir el editor o la confirmación.
            ShiftDetailSheet(
                shiftId: s.id,
                onEdit: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = store.shift(id: s.id) }
                },
                onDelete: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { confirmDelete = store.shift(id: s.id) }
                }
            )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: detail?.id)
        .sheet(item: $editing) { s in
            ShiftFormView(editing: s)
        }
        .sheet(item: $creating) { ref in
            ShiftFormView(editing: nil, defaultFecha: ref.fecha)
        }
        .confirmationDialog(
            L("¿Duplicar los \(inWeek.count) turnos de esta semana a la siguiente?"),
            isPresented: $confirmDup, titleVisibility: .visible
        ) {
            Button(L("Duplicar")) {
                if store.duplicateWeek(monday: monday) > 0 { dupDone = true }
            }
            Button(L("Cancelar"), role: .cancel) {}
        }
        .confirmationDialog(
            L("¿Eliminar este turno?"),
            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L("Eliminar"), role: .destructive) {
                if let s = confirmDelete { store.deleteShift(id: s.id) }
                confirmDelete = nil
            }
            Button(L("Cancelar"), role: .cancel) { confirmDelete = nil }
        }
        .onChange(of: weekOffset) { _, _ in dupDone = false }
    }

    private var weekNav: some View {
        HStack {
            CircleButton(icon: "chevron.left") { weekOffset -= 1 }
            Spacer()
            VStack(spacing: 4) {
                Text("\(Calc.shortDate(days[0])) – \(Calc.shortDate(days[6]))")
                    .font(.turniq(18, .bold)).tracking(-0.3)
                    .foregroundStyle(T.text)
                if weekOffset != 0 {
                    Button { weekOffset = 0 } label: {
                        Text(L("HOY")).font(.turniqMono).foregroundStyle(T.primary)
                    }
                }
            }
            Spacer()
            CircleButton(icon: "chevron.right") { weekOffset += 1 }
        }
    }

    /// Hora extra POR TRABAJO: una barra por empleo.
    @ViewBuilder
    private func otCard(worked: [Shift], totals: Calc.WeekTotals) -> some View {
        let umbral = store.settings.umbralExtraHrs
        let rows = store.jobs
            .map { (job: $0, hours: Calc.hours(ofJob: $0.id, in: worked)) }
            .filter { $0.hours > 0 }
        if !rows.isEmpty {
            TintedCard(accent: "#E8830C") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L("HORA EXTRA · POR TRABAJO"))
                            .font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("×\(store.settings.multExtra.formatted())")
                            .font(.turniq(12)).foregroundStyle(.white.opacity(0.75))
                    }
                    ForEach(rows, id: \.job.id) { row in
                        let ot = max(0, row.hours - umbral)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Circle().fill(T.hex(row.job.color)).frame(width: 8, height: 8)
                                Text(row.job.nombre)
                                    .font(.turniq(13, .bold)).foregroundStyle(.white).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Calc.fmtHours(row.hours)) / \(Calc.fmtHours(umbral))")
                                    .font(.turniq(12)).foregroundStyle(.white.opacity(0.75))
                                if ot > 0 {
                                    Text("+\(Calc.fmtHours(ot))")
                                        .font(.turniq(12, .bold)).foregroundStyle(T.amber)
                                }
                            }
                            ProgressBar(value: min(1, row.hours / umbral), color: ot > 0 ? T.amber : T.sky)
                        }
                    }
                    if totals.overtimeHours > 0 {
                        Text(L("\(Calc.fmtHoursLong(totals.overtimeHours)) de hora extra"))
                            .font(.turniq(12)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }

    private func statusColor(_ st: Calc.Status) -> Color {
        switch st {
        case .now: return T.orange
        case .missed: return T.danger
        case .upcoming: return T.success
        case .past: return T.text3
        }
    }

    private func statusLabel(_ st: Calc.Status) -> String {
        switch st {
        case .now: return L("En curso")
        case .missed: return L("No marcado")
        case .upcoming: return L("Próximamente")
        case .past: return L("Horario pasado")
        }
    }

    private func daySection(day: String, name: String, inWeek: [Shift]) -> some View {
        let ds = inWeek
            .filter { $0.fecha == day }
            .sorted { $0.horaEntrada < $1.horaEntrada }
        let hours = ds.filter { !$0.esLibre }.reduce(0.0) { $0 + Calc.shiftHours($1) }
        let isToday = day == Calc.todayYmd()
        return HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text(String(Int(day.suffix(2)) ?? 0))
                    .font(.turniq(26, .bold))
                Text(name.uppercased())
                    .font(.turniqMono)
            }
            .foregroundStyle(isToday ? T.primary : T.text3)
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(ds.count == 1 ? L("1 turno") : L("\(ds.count) turnos"))
                        .font(.turniq(12)).foregroundStyle(T.text2)
                    Spacer()
                    Text(Calc.fmtHoursLong(hours))
                        .font(.turniq(12, .bold)).foregroundStyle(T.text)
                    if !ds.isEmpty {
                        CircleButton(icon: "plus", size: 30) { creating = FechaRef(fecha: day) }
                    }
                }
                .frame(minHeight: 30)
                ForEach(ds) { s in
                    shiftCard(s, overlaps: overlaps(s, in: ds))
                }
                if ds.isEmpty {
                    Button { creating = FechaRef(fecha: day) } label: {
                        Text(L("+ Añadir turno"))
                            .font(.turniq(14, .bold)).foregroundStyle(T.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(T.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                    }
                    .buttonStyle(PressStyle())
                    .disabled(store.jobs.isEmpty)
                }
            }
        }
    }

    /// ¿Se traslapa con otro turno del mismo día?
    private func overlaps(_ s: Shift, in ds: [Shift]) -> Bool {
        func span(_ x: Shift) -> (Int, Int)? {
            guard !x.esLibre, let a = Calc.hmToMin(x.horaEntrada) else { return nil }
            var b = x.horaSalida.flatMap(Calc.hmToMin) ?? (a + 1)
            if b <= a { b += 1440 }
            return (a, b)
        }
        guard let a = span(s) else { return false }
        return ds.contains { o in
            guard o.id != s.id, let b = span(o) else { return false }
            return a.0 < b.1 && b.0 < a.1
        }
    }

    private func shiftCard(_ s: Shift, overlaps: Bool) -> some View {
        let job = store.job(id: s.jobId)
        let st = Calc.status(s)
        let stations = s.estacionIds.compactMap { id in
            job?.estaciones.first(where: { $0.id == id })?.nombre
        }
        var subtitle = job?.nombre ?? ""
        if !stations.isEmpty { subtitle += " · " + stations.joined(separator: ", ") }
        if s.esLibre { subtitle = L("Día libre") }
        return Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor(st))
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(s.esLibre ? L("Libre") : Calc.rangeLabel(s, format12: fmt12))
                            .font(.turniq(15, .bold)).foregroundStyle(T.text)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 8)
                        if !s.esLibre {
                            Text(Calc.fmtHours(Calc.shiftHours(s)))
                                .font(.turniq(15, .bold)).foregroundStyle(statusColor(st))
                        }
                    }
                    HStack {
                        Text(subtitle)
                            .font(.turniq(13)).foregroundStyle(T.text2).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(statusLabel(st))
                            .font(.turniq(12, .bold)).foregroundStyle(statusColor(st))
                    }
                    if overlaps {
                        Text(L("⚠️ Misma hora"))
                            .font(.turniq(12, .bold)).foregroundStyle(T.hex("#E65100"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(T.hex("#FFF3E0"), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Menu {
                    Button { detail = s } label: { Label(L("Ver detalles"), systemImage: "info.circle") }
                    Button { editing = s } label: { Label(L("Editar"), systemImage: "pencil") }
                    Button { store.duplicateShift(id: s.id) } label: {
                        Label(L("Duplicar turno"), systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { confirmDelete = s } label: {
                        Label(L("Eliminar"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(T.primary)
                        .frame(width: 28, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { editing = s }
        // Mantener pulsado: hoja con el detalle del turno.
        .onLongPressGesture(minimumDuration: 0.35) { detail = s }
    }

    private func totalsCard(_ t: Calc.WeekTotals) -> some View {
        TintedCard(accent: "#0064E0") {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("TOTAL SEMANAL"))
                    .font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                HStack(alignment: .top, spacing: 8) {
                    DarkStat(label: L("Horas"), value: Calc.fmtHoursLong(t.hours))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DarkStat(label: L("Bruto"), value: T.cash(t.gross, hidden: hidden))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DarkStat(label: L("Neto"), value: T.cash(t.net, hidden: hidden), color: T.money, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if t.overtimeHours > 0 {
                    Text("+\(Calc.fmtHoursLong(t.overtimeHours)) extra ×\(store.settings.multExtra.formatted())")
                        .font(.turniq(12)).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
    }
}

/// Barra de progreso redondeada de 10 pt.
struct ProgressBar: View {
    var value: Double
    var color: Color
    var track: Color = .white.opacity(0.14)
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.6), value: value)
    }
}

struct FechaRef: Identifiable {
    var fecha: String
    var id: String { fecha }
}
