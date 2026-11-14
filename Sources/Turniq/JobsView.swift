import SwiftUI

/// Trabajos en TARJETAS (radio 20, como el resto de la app): botón
/// azul arriba y cada trabajo con Editar / Eliminar, igual que Android.
struct JobsView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Job? = nil
    @State private var creating = false
    @State private var confirmDelete: Job? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                PrimaryButton(title: L("+ Agregar trabajo"), color: T.primary, textColor: .white) {
                    creating = true
                }
                .padding(.bottom, 4)

                ForEach(store.jobs) { job in
                    jobCard(job)
                }
                if store.jobs.isEmpty {
                    Text(L("Todavía no tienes trabajos. Crea el primero con el botón de arriba."))
                        .font(.turniq(14)).foregroundStyle(T.text3)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                }
            }
            .padding(16)
            .padding(.bottom, dockClearance)
        }
        .sheet(item: $editing) { j in JobFormView(editing: j) }
        .sheet(isPresented: $creating) { JobFormView(editing: nil) }
        .confirmationDialog(
            L("¿Eliminar este trabajo y sus turnos?"),
            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L("Eliminar"), role: .destructive) {
                if let j = confirmDelete { store.deleteJob(id: j.id) }
                confirmDelete = nil
            }
            Button(L("Cancelar"), role: .cancel) { confirmDelete = nil }
        }
    }

    private func jobCard(_ job: Job) -> some View {
        var detail = "$\(ShiftFormView.num(job.sueldoHora))/h · \(ShiftFormView.num(job.taxPct))% tax"
        if !job.estaciones.isEmpty {
            detail += " · " + job.estaciones.map { $0.nombre }.joined(separator: ", ")
        }
        if let pin = job.pinMarcaje, !pin.isEmpty { detail += " · PIN \(pin)" }
        let next = Pay.nextPayday(job, settings: store.settings, from: Calc.todayYmd())
        return Card {
            HStack(spacing: 12) {
                Circle().fill(T.hex(job.color)).frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.nombre)
                        .font(.turniq(17, .bold)).foregroundStyle(T.text).lineLimit(1)
                    Text(detail)
                        .font(.turniq(12)).foregroundStyle(T.text2)
                    Label(L("\(Pay.summary(job, settings: store.settings)) · próximo \(Calc.shortDate(next))"),
                          systemImage: "wallet.pass")
                        .font(.turniq(12)).foregroundStyle(T.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { editing = job } label: {
                    Text(L("Editar")).font(.turniq(14, .bold)).foregroundStyle(T.text2)
                }
                .buttonStyle(.plain)
                Button { confirmDelete = job } label: {
                    Text(L("Eliminar")).font(.turniq(14, .bold)).foregroundStyle(T.danger)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct JobFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: Job?

    @State private var nombre = ""
    @State private var color = Job.palette[0]
    @State private var sueldo = "15"
    @State private var tax = "0"
    @State private var pinReloj = ""
    @State private var estaciones: [Station] = []
    @State private var nuevaEstacion = ""
    @State private var freq: PayFreq = .semanal
    @State private var payDay = 4
    @State private var anchor = Date()
    @State private var lag = 1
    @State private var lat: Double? = nil
    @State private var lon: Double? = nil
    @StateObject private var locator = LocationOnce()
    @State private var loaded = false

    /// El trabajo tal como quedaría, para la vista previa del cobro.
    private var draft: Job {
        let pin = pinReloj.trimmingCharacters(in: .whitespaces)
        let ancla = Calc.ymd(anchor)
        return Job(
            id: editing?.id ?? "nuevo",
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            color: color,
            sueldoHora: ShiftFormView.parse(sueldo),
            taxPct: min(100, ShiftFormView.parse(tax)),
            estaciones: estaciones,
            pinMarcaje: pin.isEmpty ? nil : pin,
            pagoFrecuencia: freq.rawValue,
            pagoDia: freq == .semanal ? payDay : Calc.weekdayIndex(ancla),
            pagoAncla: freq == .quincenal ? ancla : nil,
            pagoRetraso: lag,
            lat: lat,
            lon: lon
        )
    }

    private var payPreview: String {
        let j = draft
        let next = Pay.nextPayday(j, settings: store.settings, from: Calc.todayYmd())
        let p = Pay.period(j, payday: next)
        return L("Próximo cobro: \(Calc.weekdayDate(next)). Ese día te pagan lo trabajado del \(Calc.shortDate(p.start)) al \(Calc.shortDate(p.end)). Si no coincide con tu cheque, cambia «Cobro después de trabajar».")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Trabajo")) {
                    TextField(L("Nombre"), text: $nombre)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(Job.palette, id: \.self) { c in
                                Circle()
                                    .fill(T.hex(c))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(T.text, lineWidth: color == c ? 3 : 0))
                                    .onTapGesture { color = c }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    LabeledContent(L("Sueldo por hora ($)")) {
                        TextField("15", text: $sueldo)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Taxes (%)") {
                        TextField("0", text: $tax)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Picker(L("Me pagan"), selection: $freq) {
                        ForEach(PayFreq.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    if freq == .semanal {
                        Picker(L("Día de cobro"), selection: $payDay) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(Calc.daysLong[i]).tag(i)
                            }
                        }
                    } else {
                        DatePicker(L("Un día de cobro"), selection: $anchor, displayedComponents: [.date])
                    }
                    Picker(L("Cobro después de trabajar"), selection: $lag) {
                        ForEach(1...3, id: \.self) { w in
                            Text(Pay.lagLabel(w)).tag(w)
                        }
                    }
                } header: {
                    Text(L("Cobro"))
                } footer: {
                    Text(freq == .quincenal
                         ? L("Elige cualquier fecha en que este trabajo te pagó o te va a pagar (por ejemplo tu último cheque). Turniq calcula los demás cobros cada 14 días.\n\(payPreview)")
                         : payPreview)
                }

                Section {
                    if lat != nil {
                        Label(L("Ubicación del trabajo guardada"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(T.success)
                        Button(L("Actualizar con mi ubicación actual")) { askLocation() }
                        Button(L("Quitar ubicación"), role: .destructive) {
                            lat = nil
                            lon = nil
                        }
                    } else {
                        Button { askLocation() } label: {
                            Label(L("Usar mi ubicación actual"), systemImage: "location.fill")
                        }
                    }
                    if locator.busy {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(L("Buscando tu ubicación…")).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let status = locator.status, lat == nil {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L("Aviso al llegar"))
                } footer: {
                    Text(L("Tócalo estando en el trabajo. Los días que tengas turno ahí, Turniq te avisa al llegar para que marques la entrada."))
                }

                Section {
                    TextField(L("Ej. 2001"), text: $pinReloj)
                        .keyboardType(.numberPad)
                } header: {
                    Text(L("PIN del reloj (opcional)"))
                } footer: {
                    Text(L("El PIN que marcas en el reloj de este trabajo. Turniq te lo muestra al marcar entrada, para que no se te olvide."))
                }

                Section(L("Estaciones")) {
                    ForEach(estaciones) { st in
                        Text(st.nombre)
                    }
                    .onDelete { estaciones.remove(atOffsets: $0) }
                    HStack {
                        TextField(L("Nueva estación"), text: $nuevaEstacion)
                        Button(L("Añadir")) {
                            let n = nuevaEstacion.trimmingCharacters(in: .whitespaces)
                            if !n.isEmpty {
                                estaciones.append(Station(id: UUID().uuidString, nombre: n))
                                nuevaEstacion = ""
                            }
                        }
                        .disabled(nuevaEstacion.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle(editing == nil ? L("Agregar trabajo") : L("Editar trabajo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancelar")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Guardar")) { save() }
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let today = Calc.todayYmd()
        if let e = editing {
            nombre = e.nombre
            color = e.color
            sueldo = ShiftFormView.num(e.sueldoHora)
            tax = ShiftFormView.num(e.taxPct)
            pinReloj = e.pinMarcaje ?? ""
            estaciones = e.estaciones
            freq = Pay.freq(e)
            lag = Pay.lag(e)
            lat = e.lat
            lon = e.lon
            payDay = Pay.weekday(e, settings: store.settings)
            let next = Pay.nextPayday(e, settings: store.settings, from: today)
            anchor = Calc.parseDay(e.pagoAncla ?? next) ?? Date()
        } else {
            color = Job.palette.randomElement() ?? Job.palette[0]
            payDay = min(6, max(0, store.settings.diaCobro))
            let delta = ((payDay - Calc.weekdayIndex(today)) + 7) % 7
            anchor = Calc.parseDay(Calc.addDays(today, delta)) ?? Date()
        }
    }

    private func askLocation() {
        locator.request { c in
            lat = c.latitude
            lon = c.longitude
        }
    }

    private func save() {
        var job = draft
        job.id = editing?.id ?? UUID().uuidString
        store.upsertJob(job)
        dismiss()
    }
}
