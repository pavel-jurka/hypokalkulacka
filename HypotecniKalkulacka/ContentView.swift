/// ContentView.swift — HypotecniKalkulacka
///
/// Hlavní soubor aplikace. Obsahuje celý datový model, výpočetní logiku
/// i všechny SwiftUI views.
///
/// Architektura: @Observable ViewModel + SwiftUI views (NavigationSplitView)
/// Minimální požadavek: iOS/iPadOS 17 (kvůli @Observable makru a Charts API)

import SwiftUI
import Charts
import Observation
import UIKit

// MARK: - Enums

/// Způsob výpočtu základu daně z příjmu z nájmu.
enum TaxMode: String, CaseIterable, Identifiable {
    /// Základ daně = 70 % příjmu (30 % paušální výdaj dle § 9 ZDP).
    case pausalni = "Paušální výdaj 30 %"
    /// Základ daně = příjem − úroky − opravy (skutečné výdaje, min. 0).
    case skutecne  = "Skutečné náklady"
    var id: String { rawValue }
}

// MARK: - Model

/// Jednorázová mimořádná splátka jistiny v konkrétním roce.
/// Lze ji dočasně vypnout togglem (isEnabled = false) bez smazání.
struct ExtraPayment: Identifiable {
    let id = UUID()
    var year: Int
    var amount: Double
    var isEnabled: Bool = true
}

/// Vypočtená data pro jeden rok splácení hypotéky.
/// Všechny hodnoty jsou v Kč.
struct YearData: Identifiable {
    let id = UUID()
    let year: Int

    /// Součet pravidelných měsíčních splátek za rok. Po splacení je 0.
    let annualPayment: Double

    /// Část pravidelných splátek, která šla na úroky (náklad).
    let interestPaid: Double

    /// Část pravidelných splátek, která šla na jistinu (snižuje dluh).
    let principalPaid: Double

    /// Mimořádná splátka jistiny zaplacená nad rámec pravidelné splátky.
    let extraPayment: Double

    /// Zbývající nesplacená jistina na konci roku.
    let remainingBalance: Double

    /// Kumulativní součet úroků od roku 1 do tohoto roku (pro graf).
    let cumulativeInterest: Double

    /// Skutečný roční příjem z nájmu (roste každý rok o rentGrowthPct).
    let rentalIncome: Double

    /// Roční náklady na pravidelnou drobnou údržbu.
    let regularRepair: Double

    /// Náklady na velkou údržbu (nenulové jen v roce N, 2N, 3N, …).
    let largeRepair: Double

    /// Daň z příjmu z nájmu (0 pokud je includeTax = false).
    let taxAmount: Double

    /// True pokud v tomto roce nastala refixace sazby.
    let isRefixYear: Bool

    var repairCost: Double   { regularRepair + largeRepair }
    var isLargeRepairYear: Bool { largeRepair > 0 }
    var totalPaidOut: Double { annualPayment + extraPayment }

    /// Čistý roční výsledek: nájem − úroky − opravy − daň.
    /// Splátka jistiny záměrně není odečtena — zvyšuje vlastní kapitál v nemovitosti.
    var netYear: Double { rentalIncome - interestPaid - repairCost - taxAmount }

    var cumulativeNet: Double
}

// MARK: - ViewModel

/// Centrální datový model. Drží všechny vstupní parametry a počítá amortizační harmonogram.
@Observable
class MortgageViewModel {

    // MARK: Vstupy — Nemovitost
    var propertyPrice: Double = 12_875_000
    var ownCapitalPct: Double = 10

    // MARK: Vstupy — Hypotéka
    var mortgageYears: Double = 20
    var interestRate: Double = 4.5

    // MARK: Vstupy — Refixace
    /// Zapnutí/vypnutí simulace změny sazby po refixaci.
    var useRefixation: Bool = false
    /// Rok, po kterém se mění úroková sazba (konec fixačního období).
    var refixYear: Double = 5
    /// Nová úroková sazba po refixaci.
    var refixRate: Double = 5.0

    // MARK: Vstupy — Příjmy z nájmu
    var monthlyRent: Double = 30_000
    var rentGrowthPct: Double = 2.0

    // MARK: Vstupy — Opravy a údržba
    var annualRepairs: Double = 130_000
    var largeRepairAmount: Double = 300_000
    var largeRepairEveryNYears: Double = 10

    // MARK: Vstupy — Daň z příjmu z nájmu
    var includeTax: Bool = true
    var taxMode: TaxMode = .pausalni
    /// Sazba daně z příjmu (v ČR standardně 15 %).
    var taxRate: Double = 15

    // MARK: Vstupy — Časová osa
    var selectedYear: Double = 10

    // MARK: Vstupy — Mimořádné splátky
    var extraPayments: [ExtraPayment] = []
    var newExtraYear: Int = 5
    var newExtraAmount: Double = 500_000

    func addExtraPayment() {
        extraPayments.append(ExtraPayment(year: newExtraYear, amount: newExtraAmount))
        extraPayments.sort { $0.year < $1.year }
    }
    func removeExtraPayment(id: UUID) {
        extraPayments.removeAll { $0.id == id }
    }

    // MARK: Odvozené — Základní výpočty

    var mortgageAmount: Double { propertyPrice * (1 - ownCapitalPct / 100) }
    var downPayment: Double    { propertyPrice * ownCapitalPct / 100 }

    /// Měsíční anuitní splátka: P × r × (1+r)^n / ((1+r)^n − 1)
    var monthlyPayment: Double {
        let r = interestRate / 100 / 12
        let n = mortgageYears * 12
        guard r > 0 else { return mortgageAmount / n }
        return mortgageAmount * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
    }

    /// Měsíční splátka po refixaci (vypočtená z aktuálního zůstatku a zbývající doby).
    /// Zobrazuje se jen jako informace v InputPanel.
    var monthlyPaymentAfterRefix: Double {
        guard useRefixation else { return 0 }
        // Simulujeme zůstatek po refixYear letech
        let r = interestRate / 100 / 12
        let mp = monthlyPayment
        var bal = mortgageAmount
        for _ in 1...(max(1, Int(refixYear)) * 12) {
            guard bal > 0 else { break }
            let interest = bal * r
            bal = max(0, bal - (mp - interest))
        }
        let remainingMonths = (mortgageYears - refixYear) * 12
        let r2 = refixRate / 100 / 12
        guard bal > 0, remainingMonths > 0 else { return 0 }
        guard r2 > 0 else { return bal / remainingMonths }
        return bal * r2 * pow(1 + r2, remainingMonths) / (pow(1 + r2, remainingMonths) - 1)
    }

    // MARK: Odvozené — Amortizační harmonogram

    /// Vypočítá rok po roku celý amortizační harmonogram.
    ///
    /// Kumulativní čistý výsledek:
    ///   Start = −downPayment
    ///   Každý rok += příjem_z_nájmu − úroky − opravy − daň − mimořádná_splátka
    var schedule: [YearData] {
        var r = interestRate / 100 / 12
        var currentMp = monthlyPayment
        let nYears = max(1, Int(mortgageYears))
        let repairCycle = max(1, Int(largeRepairEveryNYears))

        var balance = mortgageAmount
        var cum = -downPayment
        var cumInterest = 0.0
        var result: [YearData] = []

        for year in 1...nYears {
            // Refixace: na začátku roku po refixYear přepočítáme splátku
            let isRefixYear = useRefixation && year == Int(refixYear) + 1 && balance > 0
            if isRefixYear {
                let remainingMonths = Double((nYears - Int(refixYear)) * 12)
                let r2 = refixRate / 100 / 12
                r = r2
                if r2 > 0, remainingMonths > 0 {
                    currentMp = balance * r2 * pow(1+r2, remainingMonths) / (pow(1+r2, remainingMonths) - 1)
                } else if remainingMonths > 0 {
                    currentMp = balance / remainingMonths
                }
            }

            let actualRent = monthlyRent * 12 * pow(1 + rentGrowthPct / 100, Double(year - 1))
            let large = (year % repairCycle == 0) ? largeRepairAmount : 0
            let totalRepair = annualRepairs + large
            let extra = extraPayments.filter { $0.year == year && $0.isEnabled }
                                     .reduce(0) { $0 + $1.amount }

            var yi = 0.0, yp = 0.0
            var usedPayment = currentMp * 12

            // Hypotéka splacena — generujeme rok bez splátek
            if balance <= 0 {
                let tax = computeTax(rent: actualRent, interest: 0, repairs: totalRepair)
                cum += actualRent - totalRepair - tax
                result.append(YearData(
                    year: year, annualPayment: 0, interestPaid: 0, principalPaid: 0,
                    extraPayment: 0, remainingBalance: 0, cumulativeInterest: cumInterest,
                    rentalIncome: actualRent, regularRepair: annualRepairs, largeRepair: large,
                    taxAmount: tax, isRefixYear: false, cumulativeNet: cum
                ))
                continue
            }

            // 12 měsíčních splátek
            for _ in 1...12 {
                guard balance > 0 else { usedPayment -= currentMp; break }
                let interest = balance * r
                let principal = min(currentMp - interest, balance)
                yi += interest
                yp += principal
                balance = max(0, balance - principal)
            }

            // Mimořádná splátka jistiny (nesmí přesáhnout zbývající dluh)
            let actualExtra = min(extra, balance)
            balance = max(0, balance - actualExtra)

            cumInterest += yi
            let tax = computeTax(rent: actualRent, interest: yi, repairs: totalRepair)
            cum += actualRent - yi - totalRepair - tax - actualExtra

            result.append(YearData(
                year: year,
                annualPayment: usedPayment,
                interestPaid: yi,
                principalPaid: yp,
                extraPayment: actualExtra,
                remainingBalance: balance,
                cumulativeInterest: cumInterest,
                rentalIncome: actualRent,
                regularRepair: annualRepairs,
                largeRepair: large,
                taxAmount: tax,
                isRefixYear: isRefixYear,
                cumulativeNet: cum
            ))
        }
        return result
    }

    /// Výpočet daně z nájmu dle zvoleného režimu.
    private func computeTax(rent: Double, interest: Double, repairs: Double) -> Double {
        guard includeTax else { return 0 }
        let base: Double
        switch taxMode {
        case .pausalni:
            base = rent * 0.70     // 30 % paušální výdaj
        case .skutecne:
            base = max(0, rent - interest - repairs)
        }
        return base * taxRate / 100
    }

    // MARK: Snapshot ke zvolenému roku

    var snapYear: Int { max(1, min(Int(selectedYear), Int(mortgageYears))) }
    private var upTo: [YearData] { schedule.filter { $0.year <= snapYear } }

    var snapCumPayments: Double   { upTo.reduce(0) { $0 + $1.annualPayment + $1.extraPayment } }
    var snapCumInterest: Double   { upTo.reduce(0) { $0 + $1.interestPaid } }
    var snapCumPrincipal: Double  { upTo.reduce(0) { $0 + $1.principalPaid } }
    var snapRemainingDebt: Double { upTo.last?.remainingBalance ?? mortgageAmount }
    var snapCumRent: Double       { upTo.reduce(0) { $0 + $1.rentalIncome } }
    var snapCumRepairs: Double    { upTo.reduce(0) { $0 + $1.repairCost } }
    var snapCumTax: Double        { upTo.reduce(0) { $0 + $1.taxAmount } }
    var snapNet: Double           { upTo.last?.cumulativeNet ?? -downPayment }
    /// Čistý tok peněz bez vlastního kapitálu (zahrnuje daň).
    var snapCashflow: Double      { snapCumRent - snapCumPayments - snapCumTax }

    var payoffYear: Int? {
        schedule.first(where: { $0.remainingBalance == 0 && $0.annualPayment > 0 })?.year
    }

    // MARK: Celkové výsledky

    var totalInterest: Double { schedule.reduce(0) { $0 + $1.interestPaid } }
    var totalRent: Double     { schedule.reduce(0) { $0 + $1.rentalIncome } }
    var totalRepairs: Double  { schedule.reduce(0) { $0 + $1.repairCost } }
    var totalTax: Double      { schedule.reduce(0) { $0 + $1.taxAmount } }
    var finalBalance: Double  { schedule.last?.cumulativeNet ?? 0 }
    var breakEvenYear: Int?   { schedule.first(where: { $0.cumulativeNet >= 0 })?.year }

    // MARK: PDF export

    /// Vygeneruje PDF report a vrátí URL dočasného souboru.
    @MainActor
    func generatePDF() -> URL? {
        let reportView = PDFReportView(vm: self).frame(width: 794)
        let renderer = ImageRenderer(content: reportView)
        renderer.scale = 2.0

        guard let image = renderer.uiImage else { return nil }

        let pageRect = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: pageRect)
        }

        let url = URL.temporaryDirectory
            .appendingPathComponent("HypotecniKalkulacka_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - Formatter

/// Formátuje částku v Kč. compact = zkrácený formát pro grafy (1,2 M / 350 k).
func czk(_ value: Double, compact: Bool = false) -> String {
    if compact {
        let a = Swift.abs(value)
        let sign = value < 0 ? "−" : ""
        if a >= 1_000_000 { return "\(sign)\(String(format: "%.1f", a / 1_000_000)) M" }
        if a >= 1_000     { return "\(sign)\(String(format: "%.0f", a / 1_000)) k" }
        return "\(sign)\(String(format: "%.0f", a))"
    }
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.groupingSeparator = "\u{202F}"
    return (f.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " Kč"
}

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

            // MARK: Příjmy z nájmu
            Section {
                SliderRow("Měsíční nájem (rok 1)", $vm.monthlyRent,
                          10_000...80_000, 500, czk(vm.monthlyRent))
                SliderRow("Roční růst nájmu", $vm.rentGrowthPct,
                          0...8, 0.25,
                          String(format: "%.2f %%", vm.rentGrowthPct))
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

            // MARK: Opravy a údržba
            Section {
                SliderRow("Roční opravy / údržba", $vm.annualRepairs,
                          0...300_000, 5_000, czk(vm.annualRepairs))
                SliderRow("Velká údržba každých N let", $vm.largeRepairEveryNYears,
                          2...20, 1, "každých \(Int(vm.largeRepairEveryNYears)) let")
                SliderRow("Náklady velké údržby", $vm.largeRepairAmount,
                          50_000...1_000_000, 10_000, czk(vm.largeRepairAmount))
            } header: { Text("Opravy & Údržba") }

            // MARK: Mimořádné splátky
            Section {
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
            } header: { Text("Mimořádné splátky jistiny") }

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
            } header: { Text("Celkový výsledek") }
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
    @State private var showShare = false

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

                // Export do PDF
                Button {
                    pdfURL = vm.generatePDF()
                    if pdfURL != nil { showShare = true }
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
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ActivityView(items: [url])
                    .presentationDetents([.medium, .large])
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                SnapCard("Splátky celkem",  vm.snapCumPayments,   .blue)
                SnapCard("z toho úroky",   vm.snapCumInterest,   .red)
                SnapCard("Zbývající dluh", vm.snapRemainingDebt, .orange)
                SnapCard("Příjmy z nájmu", vm.snapCumRent,       .green)
                SnapCard("Čistý výsledek", vm.snapNet,           vm.snapNet >= 0 ? .green : .red)
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

                // Graf 1 — Kumulativní čistý výsledek
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

                // Graf 2 — Složení splátky (amortizace)
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
                    Label("Čistý výsledek po letech (nájem − úroky − opravy − daň)", systemImage: "chart.bar.fill")
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

            TableColumn("Opravy") { d in
                Text(czk(d.repairCost))
                    .foregroundStyle(d.isLargeRepairYear ? .orange : .secondary)
                    .fontWeight(d.isLargeRepairYear ? .semibold : .regular)
                    .monospacedDigit()
            }.width(min: 125)

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

/// View renderovaný do PDF. Šířka 794 pt (A4 @ 96 dpi).
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
                PDFParam("Hypotéka", czk(vm.mortgageAmount))
                PDFParam("Měsíční splátka", czk(vm.monthlyPayment))
                PDFParam("Úroková sazba", String(format: "%.2f %%", vm.interestRate))
                PDFParam("Délka hypotéky", "\(Int(vm.mortgageYears)) let")
                PDFParam("Měsíční nájem (rok 1)", czk(vm.monthlyRent))
                PDFParam("Růst nájmu", String(format: "%.2f %% / rok", vm.rentGrowthPct))
                if vm.useRefixation {
                    PDFParam("Refixace po", "\(Int(vm.refixYear)) letech → \(String(format: "%.2f %%", vm.refixRate))")
                    PDFParam("Splátka po refixaci", czk(vm.monthlyPaymentAfterRefix))
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
                if vm.includeTax {
                    PDFResult("Celkem daň", czk(vm.totalTax), .purple)
                }
                if let y = vm.breakEvenYear {
                    PDFResult("Bod zvratu", "rok \(y)", .blue)
                }
                PDFResult("Čistý výsledek", czk(vm.finalBalance), vm.finalBalance >= 0 ? .green : .red)
            }

            Divider()

            // Tabulka rok po roku
            Text("PŘEHLED ROK PO ROKU").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)

            // Záhlaví tabulky
            HStack(spacing: 0) {
                PDFCell("Rok", width: 40, bold: true)
                PDFCell("Úroky", width: 95, bold: true)
                PDFCell("Jistina", width: 95, bold: true)
                PDFCell("Zbývající dluh", width: 105, bold: true)
                PDFCell("Nájem", width: 95, bold: true)
                if vm.includeTax { PDFCell("Daň", width: 80, bold: true) }
                PDFCell("Opravy", width: 85, bold: true)
                PDFCell("Čistý rok", width: 90, bold: true)
                PDFCell("Kumulativní", width: 100, bold: true)
            }
            .background(Color(.systemGray5))
            .cornerRadius(4)

            // Řádky
            ForEach(vm.schedule) { d in
                HStack(spacing: 0) {
                    PDFCell("\(d.year).\(d.isLargeRepairYear ? " 🔧" : "")\(d.isRefixYear ? " ↺" : "")",
                            width: 40)
                    PDFCell(czk(d.interestPaid, compact: true), width: 95, color: .red)
                    PDFCell(czk(d.principalPaid, compact: true), width: 95)
                    PDFCell(czk(d.remainingBalance, compact: true), width: 105, color: .orange)
                    PDFCell(czk(d.rentalIncome, compact: true), width: 95, color: .green)
                    if vm.includeTax {
                        PDFCell(d.taxAmount > 0 ? czk(d.taxAmount, compact: true) : "—",
                                width: 80, color: .purple)
                    }
                    PDFCell(czk(d.repairCost, compact: true), width: 85,
                            color: d.isLargeRepairYear ? .orange : .secondary)
                    PDFCell(czk(d.netYear, compact: true), width: 90,
                            color: d.netYear >= 0 ? .green : .red)
                    PDFCell(czk(d.cumulativeNet, compact: true), width: 100,
                            color: d.cumulativeNet >= 0 ? .green : .red, bold: true)
                }
                .background(d.year % 2 == 0 ? Color(.systemGray6) : .clear)
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

// MARK: - Activity View (Share Sheet)

/// UIViewControllerRepresentable wrapper pro UIActivityViewController.
/// Používá se pro sdílení PDF přes systémový share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
