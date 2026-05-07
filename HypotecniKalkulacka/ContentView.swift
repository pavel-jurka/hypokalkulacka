/// ContentView.swift — HypotecniKalkulacka
///
/// SwiftUI views — veškerý UI kód.
/// Domain modely, výpočetní engine a ViewModel jsou v separátních souborech:
///   - FinancialTypes.swift  — CZK, Percent, czk() formatter
///   - Models.swift          — TaxMode, ExtraPayment, YearData, MortgageInputs
///   - CalculationEngine.swift — pure výpočty bez SwiftUI závislosti
///   - MortgageViewModel.swift — @Observable ViewModel

import SwiftUI
import Charts

// MARK: - Root View

struct ContentView: View {
    @State private var vm = MortgageViewModel()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            InputPanel(vm: vm)
                .navigationTitle("Parametry")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            DetailPanel(vm: vm)
                .navigationTitle("Přehled")
        }
    }
}

// MARK: - Input Panel

struct InputPanel: View {
    @Bindable var vm: MortgageViewModel

    var body: some View {
        Form {
            // MARK: Nemovitost
            Section {
                SliderRow("Cena nemovitosti", $vm.propertyPrice,
                          1_000_000...30_000_000, 25_000, czk(vm.propertyPrice))
                SliderRow("Vlastní kapitál", $vm.ownCapitalPct,
                          5...50, 1,
                          String(format: "%.0f %% = %@", vm.ownCapitalPct, czk(vm.downPayment)))
                Toggle("Rekonstrukce v hypotéce", isOn: $vm.includeReconstruction)
                    .tint(.blue)

                if vm.includeReconstruction {
                    SliderRow("Náklady na rekonstrukci", $vm.reconstructionAmount,
                              0...2_000_000, 10_000, czk(vm.reconstructionAmount))
                }

                Toggle("Roční zhodnocení nemovitosti", isOn: $vm.includeAppreciation)
                    .tint(.blue)

                if vm.includeAppreciation {
                    SliderRow("Zhodnocení", $vm.propertyAppreciationPct,
                              0...10, 0.25,
                              String(format: "%.2f %% / rok", vm.propertyAppreciationPct))
                }

                LabeledContent("Hypotéka") {
                    Text(czk(vm.mortgageAmount)).foregroundStyle(.secondary)
                }
            } header: { Text("Nemovitost") }

            // MARK: Hypotéka + Refixace
            Section {
                SliderRow("Délka hypotéky", $vm.mortgageYears,
                          5...30, 1, "\(Int(vm.mortgageYears)) let")
                SliderRow("Úroková sazba", $vm.interestRate,
                          0.5...10, 0.05,
                          String(format: "%.2f %%", vm.interestRate))
                LabeledContent("Měsíční splátka") {
                    Text(czk(vm.monthlyPayment))
                        .foregroundStyle(.blue).fontWeight(.semibold)
                }

                Toggle("Změna sazby po refixaci", isOn: $vm.useRefixation)
                    .tint(.blue)

                if vm.useRefixation {
                    SliderRow("Konec fixace", $vm.refixYear,
                              1...(vm.mortgageYears - 1), 1,
                              "po \(Int(vm.refixYear)) letech")
                    SliderRow("Nová sazba po refixaci", $vm.refixRate,
                              0.5...12, 0.05,
                              String(format: "%.2f %%", vm.refixRate))
                    LabeledContent("Splátka po refixaci") {
                        Text(czk(vm.monthlyPaymentAfterRefix))
                            .foregroundStyle(.indigo).fontWeight(.semibold)
                    }
                }
            } header: { Text("Hypotéka") }

            // MARK: Celkový výsledek
            Section {
                if let y = vm.payoffYear {
                    LabeledContent("Splaceno v roce") {
                        Text("\(y)").foregroundStyle(.purple).fontWeight(.bold)
                    }
                }
                if let y = vm.breakEvenYear {
                    LabeledContent("Bod zvratu") {
                        Text("rok \(y)").foregroundStyle(.blue).fontWeight(.semibold)
                    }
                } else {
                    LabeledContent("Bod zvratu") {
                        Text("nedosaženo").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Čistý výsledek za \(Int(vm.mortgageYears)) let") {
                    Text(czk(vm.finalBalance))
                        .foregroundStyle(vm.finalBalance >= 0 ? .green : .red)
                        .fontWeight(.bold)
                }
                if vm.includeAppreciation {
                    LabeledContent("Hodnota nemovitosti") {
                        Text(czk(vm.finalPropertyValue)).foregroundStyle(.blue).fontWeight(.bold)
                    }
                    LabeledContent("Celkový výsledek investice") {
                        Text(czk(vm.finalTotalInvestment))
                            .foregroundStyle(vm.finalTotalInvestment >= 0 ? .green : .red)
                            .fontWeight(.bold)
                    }
                } else {
                    LabeledContent("+ nemovitost v hodnotě") {
                        Text(czk(vm.propertyPrice)).foregroundStyle(.blue)
                    }
                }
            } header: { Text("Celkový výsledek") }

            // MARK: Mimořádné splátky
            Section {
                Toggle("Uplatnit nájem jako splátky", isOn: $vm.useRentAsExtraPayments)
                    .tint(.purple)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rok:").foregroundStyle(.secondary)
                        Stepper("\(vm.newExtraYear)", value: $vm.newExtraYear,
                                in: 1...max(1, Int(vm.mortgageYears)))
                    }
                    SliderRow("Částka", $vm.newExtraAmount,
                              10_000...3_000_000, 10_000, czk(vm.newExtraAmount))
                    Button { vm.addExtraPayment() } label: {
                        Label("Přidat mimořádnou splátku", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.purple)
                }

                ForEach($vm.extraPayments) { $ep in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $ep.isEnabled).labelsHidden().tint(.purple)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rok \(ep.year)").fontWeight(.semibold)
                                .foregroundStyle(ep.isEnabled ? .primary : .secondary)
                            Text(czk(ep.amount)).font(.caption)
                                .foregroundStyle(ep.isEnabled ? .purple : .secondary)
                        }
                        Spacer()
                        Button { vm.removeExtraPayment(id: ep.id) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(vm.autoExtraPayments) { ep in
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.uturn.right").font(.caption)
                            .foregroundStyle(.purple.opacity(0.5))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rok \(ep.year)").fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(czk(ep.amount)).font(.caption)
                                .foregroundStyle(.purple.opacity(0.5))
                        }
                        Spacer()
                        Text("auto").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } header: { Text("Mimořádné splátky jistiny") }

            // MARK: Příjmy z nájmu
            Section {
                SliderRow("Měsíční nájem (rok 1)", $vm.monthlyRent,
                          10_000...80_000, 500, czk(vm.monthlyRent))
                SliderRow("Roční růst nájmu", $vm.rentGrowthPct,
                          0...8, 0.25,
                          String(format: "%.2f %%", vm.rentGrowthPct))
                SliderRow("Neobsazenost", $vm.vacancyMonths,
                          0...4, 0.5,
                          String(format: "%.1f měs. / rok", vm.vacancyMonths))
            } header: { Text("Příjmy z nájmu") }

            // MARK: Daň z příjmu z nájmu
            Section {
                Toggle("Zohledňovat daň z nájmu", isOn: $vm.includeTax)
                    .tint(.blue)

                if vm.includeTax {
                    Picker("Výdajový režim", selection: $vm.taxMode) {
                        ForEach(TaxMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    SliderRow("Sazba daně", $vm.taxRate,
                              10...25, 1,
                              String(format: "%.0f %%", vm.taxRate))
                    // Informativní řádek — kolik daně zaplatíte celkem
                    LabeledContent("Daň celkem za \(Int(vm.mortgageYears)) let") {
                        Text(czk(vm.totalTax)).foregroundStyle(.purple)
                    }
                }
            } header: { Text("Daň z příjmu z nájmu") }

            // MARK: Provozní náklady
            Section {
                SliderRow("Pojištění nemovitosti", $vm.annualInsurance,
                          0...30_000, 1_000, czk(vm.annualInsurance) + " / rok")
                SliderRow("SVJ / fond oprav", $vm.monthlySVJ,
                          0...10_000, 500, czk(vm.monthlySVJ) + " / měs.")

                Toggle("Správa nemovitosti", isOn: $vm.includeManagement)
                    .tint(.blue)

                if vm.includeManagement {
                    SliderRow("Poplatek za správu", $vm.managementFeePct,
                              0...20, 1,
                              String(format: "%.0f %% z nájmu", vm.managementFeePct))
                }
            } header: { Text("Provozní náklady") }

            // MARK: Opravy a údržba
            Section {
                SliderRow("Roční opravy / údržba", $vm.annualRepairs,
                          0...300_000, 5_000, czk(vm.annualRepairs))
                SliderRow("Velká údržba každých N let", $vm.largeRepairEveryNYears,
                          2...20, 1, "každých \(Int(vm.largeRepairEveryNYears)) let")
                SliderRow("Náklady velké údržby", $vm.largeRepairAmount,
                          50_000...1_000_000, 10_000, czk(vm.largeRepairAmount))
            } header: { Text("Opravy & Údržba") }

            // MARK: Alternativní investice
            Section {
                Toggle("Porovnat s alternativní investicí", isOn: $vm.includeOpportunityCost)
                    .tint(.blue)

                if vm.includeOpportunityCost {
                    SliderRow("Roční výnosnost", $vm.alternativeReturnPct,
                              0...15, 0.5,
                              String(format: "%.1f %%", vm.alternativeReturnPct))
                }

                Toggle("Diskontovat inflací", isOn: $vm.includeInflation)
                    .tint(.blue)

                if vm.includeInflation {
                    SliderRow("Roční inflace", $vm.inflationRate,
                              0...8, 0.25,
                              String(format: "%.2f %%", vm.inflationRate))
                }
            } header: { Text("Srovnání & Inflace") }

        }
        .formStyle(.grouped)
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String

    init(_ label: String, _ value: Binding<Double>,
         _ range: ClosedRange<Double>, _ step: Double, _ display: String) {
        self.label = label; self._value = value
        self.range = range; self.step = step; self.display = display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) { Text(display) }
            Slider(value: $value, in: range, step: step).tint(.blue)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Panel

struct DetailPanel: View {
    @Bindable var vm: MortgageViewModel
    @State private var selectedTab = 0
    @State private var pdfURL: URL?
    @State private var showPDFSheet = false

    var body: some View {
        VStack(spacing: 0) {
            SnapshotHeader(vm: vm)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Graf").tag(0)
                    Text("Tabulka").tag(1)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button {
                    pdfURL = vm.generatePDF()
                    showPDFSheet = pdfURL != nil
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedTab == 0 {
                ChartPanel(vm: vm)
            } else {
                YearTable(vm: vm)
            }
        }
        .sheet(isPresented: $showPDFSheet) {
            if let url = pdfURL {
                VStack(spacing: 20) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                    Text("PDF je připraveno")
                        .font(.title2).fontWeight(.semibold)
                    Text("HypotecniKalkulacka.pdf")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ShareLink(
                        item: url,
                        preview: SharePreview(
                            "HypotecniKalkulacka.pdf",
                            icon: Image(systemName: "doc.richtext.fill"))
                    ) {
                        Label("Sdílet / Uložit do souborů", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)

                    Button("Zavřít") { showPDFSheet = false }
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Snapshot Header

/// Slider roku + dvě sady karet s kumulativními hodnotami.
struct SnapshotHeader: View {
    @Bindable var vm: MortgageViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Rok \(vm.snapYear) z \(Int(vm.mortgageYears))")
                    .font(.headline)
                Spacer()
                Text("Kumulativní přehled")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Slider(value: $vm.selectedYear, in: 1...vm.mortgageYears, step: 1)
                .tint(.indigo)

            Text("Se započtením vlastního kapitálu")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                SnapCard("Splátky celkem",  vm.snapCumPayments,   .blue)
                SnapCard("z toho jistina", vm.snapCumPrincipal,  .blue.opacity(0.6))
                SnapCard("z toho úroky",   vm.snapCumInterest,   .red)
                SnapCard("Zbývající dluh", vm.snapRemainingDebt, .orange)
                SnapCard("Příjmy z nájmu", vm.snapCumRent,       .green)
                SnapCard("Čistý výsledek", vm.snapNet,           vm.snapNet >= 0 ? .green : .red)
            }

            // Řádek 2: Nemovitost + investiční pohled
            if vm.includeAppreciation || vm.includeOpportunityCost || vm.includeInflation {
                Divider()

                Text("Investiční pohled")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    if vm.includeAppreciation {
                        SnapCard("Hodnota nemovitosti", vm.snapPropertyValue, .blue)
                        SnapCard("Celkový výsledek", vm.snapTotalInvestment,
                                 vm.snapTotalInvestment >= 0 ? .green : .red)
                    }
                    if vm.includeOpportunityCost {
                        SnapCard("Alternativní výnos", vm.snapOpportunityCost, .indigo)
                    }
                    if vm.includeInflation {
                        SnapCard("Reálná hodnota", vm.snapNetReal,
                                 vm.snapNetReal >= 0 ? .green : .red)
                    }
                }
            }

            Divider()

            Text("Bez vlastního kapitálu — čistý tok peněz\(vm.includeTax ? " (po dani)" : "")")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: vm.includeTax ? 4 : 3),
                      spacing: 10) {
                SnapCard("Splátky bance",  vm.snapCumPayments, .blue)
                SnapCard("Příjmy z nájmu", vm.snapCumRent,     .green)
                if vm.includeTax {
                    SnapCard("Daň",        vm.snapCumTax,      .purple)
                }
                SnapCard("Nájem − splátky\(vm.includeTax ? " − daň" : "")",
                         vm.snapCashflow,  vm.snapCashflow >= 0 ? .green : .red)
            }
        }
    }
}

struct SnapCard: View {
    let title: String; let value: Double; let color: Color
    init(_ t: String, _ v: Double, _ c: Color) { title = t; value = v; color = c }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(2).minimumScaleFactor(0.8)
            Text(czk(value, compact: true)).font(.title3).fontWeight(.bold)
                .foregroundStyle(color).minimumScaleFactor(0.7).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Charts

struct ChartPanel: View {
    var vm: MortgageViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Graf 1 — Složení splátky (amortizace)
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.principalPaid),
                                stacking: .normalized)
                            .foregroundStyle(Color.blue.opacity(0.75))
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.interestPaid),
                                stacking: .normalized)
                            .foregroundStyle(Color.red.opacity(0.75))
                        // Vertikální čára refixace
                        if vm.useRefixation {
                            RuleMark(x: .value("Rok", Int(vm.refixYear)))
                                .foregroundStyle(Color.indigo.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        }
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text("\(Int(val * 100)) %").font(.caption) }}
                    }}
                    .frame(height: 180).padding(.top, 4)

                    HStack(spacing: 20) {
                        Label("Jistina", systemImage: "rectangle.fill").foregroundStyle(.blue)
                        Label("Úroky", systemImage: "rectangle.fill").foregroundStyle(.red)
                        if vm.useRefixation {
                            Label("Refixace rok \(Int(vm.refixYear))", systemImage: "line.diagonal")
                                .foregroundStyle(.indigo)
                        }
                    }
                    .font(.caption).padding(.top, 4)
                } label: {
                    Label("Složení splátky: jistina vs. úroky", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                }

                // Graf 2 — Kumulativní čistý výsledek
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(.linearGradient(
                                colors: [.green.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(d.cumulativeNet >= 0 ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 260).padding(.top, 4)
                } label: {
                    Label("Kumulativní čistý výsledek", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                }

                // Graf 3 — Zbývající dluh vs. kumulativní úroky
                // series: parametr zajišťuje oddělení čar (bez něj vzniká zubatý vzor)
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh")).opacity(0.12)
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh"))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeInterest),
                                 series: .value("Typ", "Kumulativní úroky"))
                            .foregroundStyle(by: .value("Typ", "Kumulativní úroky"))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartForegroundStyleScale([
                        "Zbývající dluh": Color.blue, "Kumulativní úroky": Color.red
                    ])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)") } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 220).padding(.top, 4)
                } label: {
                    Label("Zbývající dluh a celkové úroky", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                }

                // Graf 4 — Čistý roční výsledek
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.netYear))
                            .foregroundStyle(d.netYear >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                            .cornerRadius(3)
                            .annotation(position: d.isLargeRepairYear ? .top : .overlay) {
                                if d.isLargeRepairYear {
                                    Image(systemName: "wrench.fill")
                                        .font(.system(size: 8)).foregroundStyle(.orange)
                                }
                            }
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.caption) }}
                    }}
                    .frame(height: 200).padding(.top, 4)

                    HStack {
                        Image(systemName: "wrench.fill").foregroundStyle(.orange)
                        Text("= rok velké údržby").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Čistý výsledek po letech (nájem − úroky − opravy − provoz − daň)", systemImage: "chart.bar.fill")
                        .font(.headline)
                }
            }
            .padding()
        }
    }
}

// MARK: - Table

struct YearTable: View {
    var vm: MortgageViewModel

    var body: some View {
        Table(vm.schedule) {
            TableColumn("Rok") { d in
                HStack(spacing: 3) {
                    Text("\(d.year).").fontWeight(.semibold)
                    if d.isLargeRepairYear {
                        Image(systemName: "wrench.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    if d.isRefixYear {
                        Image(systemName: "arrow.trianglehead.2.clockwise").font(.caption2).foregroundStyle(.indigo)
                    }
                }
                .monospacedDigit()
            }
            .width(80)

            TableColumn("Úroky") { d in
                Text(czk(d.interestPaid)).foregroundStyle(.red).monospacedDigit()
            }.width(min: 140)

            TableColumn("Mim. splátka") { d in
                if d.extraPayment > 0 {
                    Text(czk(d.extraPayment)).foregroundStyle(.purple).fontWeight(.semibold).monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.quaternary)
                }
            }.width(min: 125)

            TableColumn("Jistina") { d in
                Text(czk(d.principalPaid)).monospacedDigit()
            }.width(min: 130)

            TableColumn("Zbývající dluh") { d in
                Text(czk(d.remainingBalance)).foregroundStyle(.orange).monospacedDigit()
            }.width(min: 140)

            TableColumn("Příjmy z nájmu") { d in
                Text(czk(d.rentalIncome)).foregroundStyle(.green).monospacedDigit()
            }.width(min: 135)

            TableColumn("Daň") { d in
                if d.taxAmount > 0 {
                    Text(czk(d.taxAmount)).foregroundStyle(.purple).monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.quaternary)
                }
            }.width(min: 115)

            TableColumn("Náklady") { d in
                let total = d.repairCost + d.operatingCosts
                Text(czk(total))
                    .foregroundStyle(d.isLargeRepairYear ? .orange : .secondary)
                    .fontWeight(d.isLargeRepairYear ? .semibold : .regular)
                    .monospacedDigit()
            }.width(min: 130)

            TableColumn("Čistý rok") { d in
                Text(czk(d.netYear))
                    .foregroundStyle(d.netYear >= 0 ? .green : .red)
                    .fontWeight(.semibold).monospacedDigit()
            }.width(min: 125)

            TableColumn("Kumulativní") { d in
                Text(czk(d.cumulativeNet))
                    .foregroundStyle(d.cumulativeNet >= 0 ? .green : .red)
                    .fontWeight(.bold).monospacedDigit()
            }.width(min: 140)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - PDF Report View

/// View renderovaný do PDF. Šířka 1000 pt.
struct PDFReportView: View {
    var vm: MortgageViewModel

    private var dateStr: String {
        let f = DateFormatter()
        f.dateStyle = .long; f.locale = Locale(identifier: "cs_CZ")
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Hlavička
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hypoteční kalkulačka").font(.title).fontWeight(.bold)
                    Text("Výsledky simulace · \(dateStr)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "house.fill").font(.largeTitle).foregroundStyle(.blue)
            }
            .padding(.bottom, 4)

            Divider()

            // Parametry ve dvou sloupcích
            Text("PARAMETRY").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                PDFParam("Cena nemovitosti", czk(vm.propertyPrice))
                PDFParam("Vlastní kapitál", String(format: "%.0f %% = %@", vm.ownCapitalPct, czk(vm.downPayment)))
                if vm.includeReconstruction {
                    PDFParam("Rekonstrukce", czk(vm.reconstructionAmount))
                }
                PDFParam("Hypotéka", czk(vm.mortgageAmount))
                PDFParam("Měsíční splátka", czk(vm.monthlyPayment))
                PDFParam("Úroková sazba", String(format: "%.2f %%", vm.interestRate))
                PDFParam("Délka hypotéky", "\(Int(vm.mortgageYears)) let")
                PDFParam("Měsíční nájem (rok 1)", czk(vm.monthlyRent))
                PDFParam("Růst nájmu", String(format: "%.2f %% / rok", vm.rentGrowthPct))
                if vm.vacancyMonths > 0 {
                    PDFParam("Neobsazenost", String(format: "%.1f měs. / rok", vm.vacancyMonths))
                }
                if vm.useRefixation {
                    PDFParam("Refixace po", "\(Int(vm.refixYear)) letech → \(String(format: "%.2f %%", vm.refixRate))")
                    PDFParam("Splátka po refixaci", czk(vm.monthlyPaymentAfterRefix))
                }
                if vm.includeAppreciation {
                    PDFParam("Zhodnocení nemovitosti", String(format: "%.2f %% / rok", vm.propertyAppreciationPct))
                }
                PDFParam("Pojištění", czk(vm.annualInsurance) + " / rok")
                PDFParam("SVJ / fond oprav", czk(vm.monthlySVJ) + " / měs.")
                if vm.includeManagement {
                    PDFParam("Správa nemovitosti", String(format: "%.0f %% z nájmu", vm.managementFeePct))
                }
                PDFParam("Roční opravy", czk(vm.annualRepairs))
                PDFParam("Velká údržba", "každých \(Int(vm.largeRepairEveryNYears)) let / \(czk(vm.largeRepairAmount))")
                if vm.includeTax {
                    PDFParam("Daň z nájmu", "\(vm.taxMode.rawValue), \(String(format: "%.0f %%", vm.taxRate))")
                }
            }

            Divider()

            // Celkové výsledky
            Text("VÝSLEDKY ZA \(Int(vm.mortgageYears)) LET").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                PDFResult("Celkem zaplaceno úroků", czk(vm.totalInterest), .red)
                PDFResult("Celkem příjmy z nájmu", czk(vm.totalRent), .green)
                PDFResult("Celkem opravy", czk(vm.totalRepairs), .orange)
                if vm.totalOperating > 0 {
                    PDFResult("Celkem provoz", czk(vm.totalOperating), .secondary)
                }
                if vm.includeTax {
                    PDFResult("Celkem daň", czk(vm.totalTax), .purple)
                }
                if let y = vm.breakEvenYear {
                    PDFResult("Bod zvratu", "rok \(y)", .blue)
                }
                PDFResult("Čistý výsledek", czk(vm.finalBalance), vm.finalBalance >= 0 ? .green : .red)
                if vm.includeAppreciation {
                    PDFResult("Hodnota nemovitosti", czk(vm.finalPropertyValue), .blue)
                    PDFResult("Celkový výsledek investice", czk(vm.finalTotalInvestment),
                              vm.finalTotalInvestment >= 0 ? .green : .red)
                }
            }

            Divider()

            // Grafy ve dvou sloupcích
            Text("GRAFY").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                // Graf 1: Kumulativní čistý výsledek
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kumulativní čistý výsledek")
                        .font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(.linearGradient(
                                colors: [.green.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeNet))
                            .foregroundStyle(d.cumulativeNet >= 0 ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.system(size: 7)) }}
                    }}
                    .frame(height: 160)
                }

                // Graf 2: Čistý výsledek po letech
                VStack(alignment: .leading, spacing: 4) {
                    Text("Čistý výsledek po letech")
                        .font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.netYear))
                            .foregroundStyle(d.netYear >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                            .cornerRadius(2)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.system(size: 7)) }}
                    }}
                    .frame(height: 160)
                }

                // Graf 3: Složení splátky (amortizace)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Složení splátky: jistina vs. úroky")
                        .font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.principalPaid), stacking: .normalized)
                            .foregroundStyle(Color.blue.opacity(0.75))
                        BarMark(x: .value("Rok", d.year), y: .value("Kč", d.interestPaid), stacking: .normalized)
                            .foregroundStyle(Color.red.opacity(0.75))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } }
                    }}
                    .chartYAxis { AxisMarks(values: [0, 0.5, 1.0]) { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text("\(Int(val * 100)) %").font(.system(size: 7)) }}
                    }}
                    .frame(height: 160)
                    HStack(spacing: 8) {
                        Label("Jistina", systemImage: "rectangle.fill").foregroundStyle(.blue)
                        Label("Úroky", systemImage: "rectangle.fill").foregroundStyle(.red)
                    }
                    .font(.system(size: 7))
                }

                // Graf 4: Zbývající dluh vs. kumulativní úroky
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zbývající dluh a celkové úroky")
                        .font(.caption).fontWeight(.semibold)
                    Chart(vm.schedule) { d in
                        AreaMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh")).opacity(0.15)
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.remainingBalance),
                                 series: .value("Typ", "Zbývající dluh"))
                            .foregroundStyle(by: .value("Typ", "Zbývající dluh"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        LineMark(x: .value("Rok", d.year), y: .value("Kč", d.cumulativeInterest),
                                 series: .value("Typ", "Kumulativní úroky"))
                            .foregroundStyle(by: .value("Typ", "Kumulativní úroky"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartForegroundStyleScale(["Zbývající dluh": Color.blue, "Kumulativní úroky": Color.red])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis { AxisMarks(values: .stride(by: 5)) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text("rok \(y)").font(.system(size: 7)) } }
                    }}
                    .chartYAxis { AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let val = v.as(Double.self) {
                            Text(czk(val, compact: true)).font(.system(size: 7)) }}
                    }}
                    .frame(height: 160)
                }
            }

            Divider()

            // Tabulka rok po roku
            Text("PŘEHLED ROK PO ROKU").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            // Záhlaví tabulky
            HStack(spacing: 0) {
                PDFCell("Rok", width: 35, bold: true)
                PDFCell("Úroky", width: 85, bold: true)
                PDFCell("Jistina", width: 85, bold: true)
                PDFCell("Dluh", width: 90, bold: true)
                PDFCell("Nájem", width: 85, bold: true)
                if vm.includeTax { PDFCell("Daň", width: 70, bold: true) }
                PDFCell("Opravy", width: 75, bold: true)
                PDFCell("Provoz", width: 75, bold: true)
                PDFCell("Čistý", width: 80, bold: true)
                PDFCell("Kumul.", width: 90, bold: true)
            }
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(4)

            // Řádky
            ForEach(vm.schedule) { d in
                HStack(spacing: 0) {
                    PDFCell("\(d.year).\(d.isLargeRepairYear ? " 🔧" : "")\(d.isRefixYear ? " ↺" : "")",
                            width: 35)
                    PDFCell(czk(d.interestPaid, compact: true), width: 85, color: .red)
                    PDFCell(czk(d.principalPaid, compact: true), width: 85)
                    PDFCell(czk(d.remainingBalance, compact: true), width: 90, color: .orange)
                    PDFCell(czk(d.rentalIncome, compact: true), width: 85, color: .green)
                    if vm.includeTax {
                        PDFCell(d.taxAmount > 0 ? czk(d.taxAmount, compact: true) : "—",
                                width: 70, color: .purple)
                    }
                    PDFCell(czk(d.repairCost, compact: true), width: 75,
                            color: d.isLargeRepairYear ? .orange : .secondary)
                    PDFCell(d.operatingCosts > 0 ? czk(d.operatingCosts, compact: true) : "—",
                            width: 75, color: .secondary)
                    PDFCell(czk(d.netYear, compact: true), width: 80,
                            color: d.netYear >= 0 ? .green : .red)
                    PDFCell(czk(d.cumulativeNet, compact: true), width: 90,
                            color: d.cumulativeNet >= 0 ? .green : .red, bold: true)
                }
                .background(d.year % 2 == 0 ? Color.secondary.opacity(0.07) : .clear)
            }
        }
        .padding(32)
        .background(Color.white)
    }
}

private struct PDFParam: View {
    let label: String; let value: String
    init(_ l: String, _ v: String) { label = l; value = v }
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

private struct PDFResult: View {
    let label: String; let value: String; let color: Color
    init(_ l: String, _ v: String, _ c: Color) { label = l; value = v; color = c }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct PDFCell: View {
    let text: String; let width: CGFloat
    var color: Color = .primary; var bold: Bool = false
    init(_ t: String, width: CGFloat, color: Color = .primary, bold: Bool = false) {
        text = t; self.width = width; self.color = color; self.bold = bold
    }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: bold ? .semibold : .regular))
            .foregroundStyle(color)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 3)
            .padding(.horizontal, 3)
    }
}

