/// ContentView.swift — HypotecniKalkulacka
///
/// Hlavní soubor aplikace. Obsahuje celý datový model, výpočetní logiku
/// i všechny SwiftUI views. Aplikace je záměrně v jednom souboru pro
/// přehlednost — při rozrůstání projektu lze view rozdělit do samostatných souborů.
///
/// Architektura: @Observable ViewModel + SwiftUI views (NavigationSplitView)
/// Minimální požadavek: iOS/iPadOS 17 (kvůli @Observable makru a Charts API)

import SwiftUI
import Charts
import Observation

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

    /// Součet pravidelných měsíčních splátek za rok (= 12 × měsíční splátka).
    /// Po úplném splacení hypotéky je 0.
    let annualPayment: Double

    /// Část pravidelných splátek, která šla na úroky (náklad — nesnižuje dluh).
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

    /// Celkové roční náklady na opravy (regularRepair + largeRepair).
    var repairCost: Double { regularRepair + largeRepair }

    /// True v letech velké údržby — použito pro vizuální označení v grafu/tabulce.
    var isLargeRepairYear: Bool { largeRepair > 0 }

    /// Celková částka odvedená bance v daném roce (pravidelné + mimořádná splátka).
    var totalPaidOut: Double { annualPayment + extraPayment }

    /// Čistý roční výsledek: co přinesl nájem mínus co stálo udržovat a splácet úroky.
    /// Splátka jistiny záměrně není odečtena — ta zvyšuje vlastní kapitál v nemovitosti.
    /// netYear = rentalIncome − interestPaid − repairCost
    var netYear: Double { rentalIncome - interestPaid - repairCost }

    /// Kumulativní čistý výsledek od začátku investice (viz výpočet v MortgageViewModel.schedule).
    var cumulativeNet: Double
}

// MARK: - ViewModel

/// Centrální datový model aplikace. Drží všechny vstupní parametry a počítá
/// amortizační harmonogram. Díky @Observable makru SwiftUI views automaticky
/// reagují na změny — není potřeba @Published ani ObservableObject.
@Observable
class MortgageViewModel {

    // MARK: Vstupy — Nemovitost

    /// Pořizovací cena nemovitosti v Kč.
    var propertyPrice: Double = 12_875_000

    /// Výše vlastního kapitálu jako procento z ceny nemovitosti.
    /// Zbytek (100 % − ownCapitalPct) tvoří výši hypotéky.
    var ownCapitalPct: Double = 10

    // MARK: Vstupy — Hypotéka

    /// Délka hypotéky v letech (5–30).
    var mortgageYears: Double = 20

    /// Roční úroková sazba v procentech.
    var interestRate: Double = 4.5

    // MARK: Vstupy — Příjmy z nájmu

    /// Měsíční příjem z nájmu v prvním roce.
    var monthlyRent: Double = 30_000

    /// Roční procentní růst nájmu (modeluje inflaci / tržní vývoj nájmů).
    var rentGrowthPct: Double = 2.0

    // MARK: Vstupy — Opravy a údržba

    /// Roční náklady na drobnou údržbu (malování, drobné opravy apod.).
    var annualRepairs: Double = 130_000

    /// Náklady na jednu velkou údržbu (rekonstrukce koupelny, výměna oken apod.).
    var largeRepairAmount: Double = 300_000

    /// Interval velké údržby v letech (velká údržba nastane v roce N, 2N, 3N, …).
    var largeRepairEveryNYears: Double = 10

    // MARK: Vstupy — Časová osa

    /// Rok zobrazený v SnapshotHeader (slider v detailním panelu).
    var selectedYear: Double = 10

    // MARK: Vstupy — Mimořádné splátky

    /// Seznam všech definovaných mimořádných splátek (seřazeno podle roku).
    var extraPayments: [ExtraPayment] = []

    /// Rok pro připravovanou novou mimořádnou splátku (ovládáno Stepperem).
    var newExtraYear: Int = 5

    /// Výše připravované nové mimořádné splátky.
    var newExtraAmount: Double = 500_000

    /// Přidá novou mimořádnou splátku a seznam seřadí chronologicky.
    func addExtraPayment() {
        extraPayments.append(ExtraPayment(year: newExtraYear, amount: newExtraAmount))
        extraPayments.sort { $0.year < $1.year }
    }

    /// Smaže mimořádnou splátku se zadaným id.
    func removeExtraPayment(id: UUID) {
        extraPayments.removeAll { $0.id == id }
    }

    // MARK: Odvozené — Základní výpočty hypotéky

    /// Výše úvěru = cena nemovitosti × (1 − vlastní kapitál v %).
    var mortgageAmount: Double { propertyPrice * (1 - ownCapitalPct / 100) }

    /// Výše vlastního kapitálu vloženého při koupi (záporný startovní bod kumulativu).
    var downPayment: Double { propertyPrice * ownCapitalPct / 100 }

    /// Měsíční anuitní splátka vypočtená standardním vzorcem:
    ///   P × r × (1+r)^n / ((1+r)^n − 1)
    /// kde P = jistina, r = měsíční úroková sazba, n = počet měsíců.
    /// Při nulové sazbě se degeneruje na rovnoměrné splácení.
    var monthlyPayment: Double {
        let r = interestRate / 100 / 12
        let n = mortgageYears * 12
        guard r > 0 else { return mortgageAmount / n }
        return mortgageAmount * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
    }

    // MARK: Odvozené — Amortizační harmonogram

    /// Vypočítá rok po roku celý amortizační harmonogram.
    ///
    /// Logika výpočtu kumulativního čistého výsledku:
    ///   - Startovní hodnota: −downPayment (vlastní kapitál vložený při koupi)
    ///   - Každý rok se přičítá: +nájem −úroky −opravy −mimořádná splátka
    ///   - Splátka jistiny (principalPaid) se NEZAPOČÍTÁVÁ, protože snižuje dluh —
    ///     peníze nepřicházíte, ale "přesunují se" z cashflow do vlastního kapitálu.
    ///
    /// Po úplném splacení hypotéky (balance = 0) se generují roky bez splátek
    /// s čistým příjmem z nájmu mínus opravy.
    var schedule: [YearData] {
        let r = interestRate / 100 / 12          // měsíční úroková sazba
        let mp = monthlyPayment                   // měsíční splátka
        let mp12 = mp * 12                        // roční splátka (bez mimořádných)
        let nYears = max(1, Int(mortgageYears))
        let repairCycle = max(1, Int(largeRepairEveryNYears))

        var balance = mortgageAmount              // aktuální nesplacená jistina
        var cum = -downPayment                    // kumulativní čistý výsledek
        var cumInterest = 0.0                     // kumulativní úroky (pro graf)
        var result: [YearData] = []

        for year in 1...nYears {
            // Roční příjem z nájmu roste geometricky o rentGrowthPct % každý rok
            let actualRent = monthlyRent * 12 * pow(1 + rentGrowthPct / 100, Double(year - 1))

            // Velká údržba nastane v roce N, 2N, 3N, …
            let large = (year % repairCycle == 0) ? largeRepairAmount : 0
            let totalRepair = annualRepairs + large

            // Součet aktivních (isEnabled) mimořádných splátek pro tento rok
            let extra = extraPayments.filter { $0.year == year && $0.isEnabled }
                                     .reduce(0) { $0 + $1.amount }

            var yi = 0.0, yp = 0.0
            var usedPayment = mp12

            // Hypotéka již splacena — generujeme rok bez splátek
            if balance <= 0 {
                cum += actualRent - totalRepair
                result.append(YearData(
                    year: year, annualPayment: 0, interestPaid: 0, principalPaid: 0,
                    extraPayment: 0, remainingBalance: 0, cumulativeInterest: cumInterest,
                    rentalIncome: actualRent, regularRepair: annualRepairs, largeRepair: large,
                    cumulativeNet: cum
                ))
                continue
            }

            // 12 měsíčních splátek — každý měsíc se znovu dělí na úrok a jistinu
            for _ in 1...12 {
                guard balance > 0 else { usedPayment -= mp; break }
                let interest = balance * r
                // Pokud zbývá méně než jedna splátka, nesplácíme víc než dlužíme
                let principal = min(mp - interest, balance)
                yi += interest
                yp += principal
                balance = max(0, balance - principal)
            }

            // Mimořádná splátka — nesmí přesáhnout zbývající dluh
            let actualExtra = min(extra, balance)
            balance = max(0, balance - actualExtra)

            cumInterest += yi
            // Mimořádná splátka snižuje kumulativní výsledek (odchod peněz z kapsy)
            cum += actualRent - yi - totalRepair - actualExtra

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
                cumulativeNet: cum
            ))
        }
        return result
    }

    // MARK: Odvozené — Snapshot ke zvolenému roku

    /// Rok zobrazený v detailním přehledu (snapYear je Int clamped do <1, mortgageYears>).
    var snapYear: Int { max(1, min(Int(selectedYear), Int(mortgageYears))) }

    /// Podmnožina harmonogramu do zvoleného roku (lazy computed, není cachována).
    private var upTo: [YearData] { schedule.filter { $0.year <= snapYear } }

    /// Celková suma zaplacená bance (pravidelné + mimořádné splátky) od začátku do snapYear.
    var snapCumPayments: Double  { upTo.reduce(0) { $0 + $1.annualPayment + $1.extraPayment } }

    /// Kumulativní úroky od začátku do snapYear.
    var snapCumInterest: Double  { upTo.reduce(0) { $0 + $1.interestPaid } }

    /// Kumulativní splacená jistina od začátku do snapYear.
    var snapCumPrincipal: Double { upTo.reduce(0) { $0 + $1.principalPaid } }

    /// Zbývající dluh ke konci snapYear.
    var snapRemainingDebt: Double { upTo.last?.remainingBalance ?? mortgageAmount }

    /// Kumulativní příjmy z nájmu od začátku do snapYear.
    var snapCumRent: Double      { upTo.reduce(0) { $0 + $1.rentalIncome } }

    /// Kumulativní náklady na opravy od začátku do snapYear.
    var snapCumRepairs: Double   { upTo.reduce(0) { $0 + $1.repairCost } }

    /// Kumulativní čistý výsledek ke snapYear (zahrnuje −downPayment jako startovní bod).
    var snapNet: Double          { upTo.last?.cumulativeNet ?? -downPayment }

    /// Čistý tok peněz bez vlastního kapitálu: kolik přinesl nájem mínus co šlo bance.
    /// Kladná hodnota = nájem pokrývá splátky s přebytkem.
    var snapCashflow: Double     { snapCumRent - snapCumPayments }

    /// Rok, ve kterém byla hypotéka zcela splacena díky mimořádným splátkám
    /// (nebo klasickým splácením na poslední rok). Nil pokud se hypotéka táhne celou dobu.
    var payoffYear: Int? {
        schedule.first(where: { $0.remainingBalance == 0 && $0.annualPayment > 0 })?.year
    }

    // MARK: Odvozené — Celkové výsledky za celou dobu

    /// Celkové úroky zaplacené za celou dobu hypotéky.
    var totalInterest: Double { schedule.reduce(0) { $0 + $1.interestPaid } }

    /// Celkové příjmy z nájmu za celou dobu.
    var totalRent: Double     { schedule.reduce(0) { $0 + $1.rentalIncome } }

    /// Celkové náklady na opravy za celou dobu.
    var totalRepairs: Double  { schedule.reduce(0) { $0 + $1.repairCost } }

    /// Kumulativní čistý výsledek na konci posledního roku.
    var finalBalance: Double  { schedule.last?.cumulativeNet ?? 0 }

    /// První rok, kdy kumulativní čistý výsledek přejde do kladných čísel (bod zvratu).
    var breakEvenYear: Int?   { schedule.first(where: { $0.cumulativeNet >= 0 })?.year }
}

// MARK: - Formatter

/// Formátuje částku v Kč.
/// - Parameter compact: true = zkrácený formát pro grafy (např. "1,2 M", "350 k")
/// - Returns: Naformátovaný řetězec s " Kč" nebo zkrácenou verzí.
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
    f.groupingSeparator = "\u{202F}"   // úzká mezera jako oddělovač tisíců (česká konvence)
    return (f.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " Kč"
}

// MARK: - Root View

/// Kořenový view. Používá NavigationSplitView — levý panel jsou vstupy,
/// pravý panel jsou grafy a tabulka. Na iPadu jsou oba panely viditelné současně.
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

/// Levý panel s parametry hypotéky. Veškeré vstupy jsou slidery pro okamžitou
/// zpětnou vazbu — změna libovolného parametru okamžitě přepočítá harmonogram.
struct InputPanel: View {
    @Bindable var vm: MortgageViewModel

    var body: some View {
        Form {
            // MARK: Nemovitost
            Section {
                SliderRow("Cena nemovitosti", $vm.propertyPrice,
                          1_000_000...30_000_000, 25_000,
                          czk(vm.propertyPrice))
                SliderRow("Vlastní kapitál", $vm.ownCapitalPct,
                          5...50, 1,
                          String(format: "%.0f %% = %@", vm.ownCapitalPct, czk(vm.downPayment)))
                // Výše hypotéky je jen informativní — odvozuje se ze dvou výše
                LabeledContent("Hypotéka") {
                    Text(czk(vm.mortgageAmount)).foregroundStyle(.secondary)
                }
            } header: { Text("Nemovitost") }

            // MARK: Hypotéka
            Section {
                SliderRow("Délka hypotéky", $vm.mortgageYears,
                          5...30, 1, "\(Int(vm.mortgageYears)) let")
                SliderRow("Úroková sazba", $vm.interestRate,
                          0.5...10, 0.05,
                          String(format: "%.2f %%", vm.interestRate))
                // Měsíční splátka se počítá ze vzorce — není vstupem, jen výstupem
                LabeledContent("Měsíční splátka") {
                    Text(czk(vm.monthlyPayment))
                        .foregroundStyle(.blue).fontWeight(.semibold)
                }
            } header: { Text("Hypotéka") }

            // MARK: Příjmy z nájmu
            Section {
                SliderRow("Měsíční nájem (rok 1)", $vm.monthlyRent,
                          10_000...80_000, 500, czk(vm.monthlyRent))
                // Růst nájmu modeluje inflaci nebo tržní vývoj — nájem roste geometricky
                SliderRow("Roční růst nájmu", $vm.rentGrowthPct,
                          0...8, 0.25,
                          String(format: "%.2f %%", vm.rentGrowthPct))
            } header: { Text("Příjmy z nájmu") }

            // MARK: Opravy a údržba
            Section {
                SliderRow("Roční opravy / údržba", $vm.annualRepairs,
                          0...300_000, 5_000, czk(vm.annualRepairs))
                // Velká údržba nastane v pravidelných intervalech (rok N, 2N, 3N, …)
                SliderRow("Velká údržba každých N let", $vm.largeRepairEveryNYears,
                          2...20, 1, "každých \(Int(vm.largeRepairEveryNYears)) let")
                SliderRow("Náklady velké údržby", $vm.largeRepairAmount,
                          50_000...1_000_000, 10_000, czk(vm.largeRepairAmount))
            } header: { Text("Opravy & Údržba") }

            // MARK: Mimořádné splátky
            Section {
                // Seznam existujících mimořádných splátek s togglem pro zapnutí/vypnutí
                ForEach($vm.extraPayments) { $ep in
                    HStack(spacing: 10) {
                        // Toggle umožňuje "simulovat" vliv splátky bez jejího smazání
                        Toggle("", isOn: $ep.isEnabled)
                            .labelsHidden()
                            .tint(.purple)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rok \(ep.year)")
                                .fontWeight(.semibold)
                                .foregroundStyle(ep.isEnabled ? .primary : .secondary)
                            Text(czk(ep.amount))
                                .font(.caption)
                                .foregroundStyle(ep.isEnabled ? .purple : .secondary)
                        }
                        Spacer()
                        Button {
                            vm.removeExtraPayment(id: ep.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Formulář pro přidání nové mimořádné splátky
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rok:")
                            .foregroundStyle(.secondary)
                        Stepper("\(vm.newExtraYear)", value: $vm.newExtraYear,
                                in: 1...max(1, Int(vm.mortgageYears)))
                    }
                    SliderRow("Částka", $vm.newExtraAmount,
                              10_000...3_000_000, 10_000, czk(vm.newExtraAmount))
                    Button {
                        vm.addExtraPayment()
                    } label: {
                        Label("Přidat mimořádnou splátku", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            } header: { Text("Mimořádné splátky jistiny") }

            // MARK: Celkový výsledek
            Section {
                // Zobrazí se jen pokud mimořádné splátky zkrátí hypotéku
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

/// Znovupoužitelný řádek se sliderovou kontrolou a popiskem.
/// Zobrazuje label, aktuální hodnotu napravo a slider pod tím.
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

/// Pravý panel s detailním přehledem. Horní část = SnapshotHeader se sliderem roku,
/// dolní část = přepínač Graf / Tabulka.
struct DetailPanel: View {
    @Bindable var vm: MortgageViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            SnapshotHeader(vm: vm)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            Picker("", selection: $selectedTab) {
                Text("Graf").tag(0)
                Text("Tabulka").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedTab == 0 {
                ChartPanel(vm: vm)
            } else {
                YearTable(vm: vm)
            }
        }
    }
}

// MARK: - Snapshot Header

/// Horní část detailního panelu: slider pro výběr roku a dvě sady karet
/// s kumulativními hodnotami k tomuto roku.
///
/// Dvě sady karet:
/// 1. "Se započtením vlastního kapitálu" — zahrnuje −downPayment jako startovní náklad
/// 2. "Bez vlastního kapitálu" — čistě tok peněz (nájem vs. splátky)
struct SnapshotHeader: View {
    @Bindable var vm: MortgageViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Rok \(vm.snapYear) z \(Int(vm.mortgageYears))")
                    .font(.headline)
                Spacer()
                Text("Kumulativní přehled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Hlavní slider časové osy — indigo barva odlišuje od ostatních sliderů
            Slider(value: $vm.selectedYear, in: 1...vm.mortgageYears, step: 1)
                .tint(.indigo)

            // Sada 1: pohled investora (zahrnuje počáteční vklad)
            Text("Se započtením vlastního kapitálu")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                SnapCard("Splátky celkem",     vm.snapCumPayments,   .blue)
                SnapCard("z toho úroky",       vm.snapCumInterest,   .red)
                SnapCard("Zbývající dluh",     vm.snapRemainingDebt, .orange)
                SnapCard("Příjmy z nájmu",     vm.snapCumRent,       .green)
                SnapCard("Čistý výsledek",     vm.snapNet,
                         vm.snapNet >= 0 ? .green : .red)
            }

            Divider()

            // Sada 2: cashflow pohled (bez počátečního vkladu)
            Text("Bez vlastního kapitálu — čistý tok peněz")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 10) {
                SnapCard("Zaplaceno na splátkách", vm.snapCumPayments,  .blue)
                SnapCard("Příjmy z nájmu",         vm.snapCumRent,      .green)
                SnapCard("Nájem − splátky",        vm.snapCashflow,
                         vm.snapCashflow >= 0 ? .green : .red)
            }
        }
    }
}

/// Informační karta v SnapshotHeader.
/// Zobrazuje nadpis, velkou hodnotu v Kč (kompaktní formát) a barevné pozadí.
struct SnapCard: View {
    let title: String
    let value: Double
    let color: Color

    init(_ title: String, _ value: Double, _ color: Color) {
        self.title = title; self.value = value; self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(czk(value, compact: true))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Charts

/// Grafický panel se čtyřmi grafy seřazenými vertikálně v ScrollView.
/// Každý graf obsahuje indigo svislou čáru na pozici zvoleného roku (snapYear).
struct ChartPanel: View {
    var vm: MortgageViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: Graf 1 — Kumulativní čistý výsledek
                // Plocha + linie ukazuje, jak se investice "zaplatí" v čase.
                // Červená = v mínusu (stále vracíte víc, než přišlo), zelená = v plusu.
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.cumulativeNet)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.green.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.cumulativeNet)
                        )
                        .foregroundStyle(d.cumulativeNet >= 0 ? Color.green : Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        // Vertikální ukazatel zvoleného roku
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 5)) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let y = v.as(Int.self) { Text("rok \(y)") }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let val = v.as(Double.self) {
                                    Text(czk(val, compact: true)).font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: 260)
                    .padding(.top, 4)
                } label: {
                    Label("Kumulativní čistý výsledek", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                }

                // MARK: Graf 2 — Amortizace (složení splátky)
                // Normalizované sloupce (100 %) ukazují poměr jistina:úroky každý rok.
                // Na začátku hypotéky tvoří úroky většinu splátky, ke konci naopak.
                // Toto je klíčový "aha moment" pro pochopení nákladů hypotéky.
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.principalPaid),
                            stacking: .normalized
                        )
                        .foregroundStyle(Color.blue.opacity(0.75))
                        BarMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.interestPaid),
                            stacking: .normalized
                        )
                        .foregroundStyle(Color.red.opacity(0.75))
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 5)) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let y = v.as(Int.self) { Text("rok \(y)") }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let val = v.as(Double.self) {
                                    Text("\(Int(val * 100)) %").font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.top, 4)

                    HStack(spacing: 20) {
                        Label("Jistina (splácíš dluh)", systemImage: "rectangle.fill").foregroundStyle(.blue)
                        Label("Úroky (náklad navíc)", systemImage: "rectangle.fill").foregroundStyle(.red)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                } label: {
                    Label("Složení splátky: jistina vs. úroky", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                }

                // MARK: Graf 3 — Zbývající dluh vs. kumulativní úroky
                // Dvě oddělené série (series: parametr zabraňuje spojení čar do zubatého vzoru).
                // Barvy přiřazeny přes chartForegroundStyleScale pro správnou legendu.
                // Průsečík říká: "od tohoto roku jsi na úrocích zaplatil víc, než ještě dlužíš."
                GroupBox {
                    Chart(vm.schedule) { d in
                        AreaMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.remainingBalance),
                            series: .value("Typ", "Zbývající dluh")
                        )
                        .foregroundStyle(by: .value("Typ", "Zbývající dluh"))
                        .opacity(0.12)

                        LineMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.remainingBalance),
                            series: .value("Typ", "Zbývající dluh")
                        )
                        .foregroundStyle(by: .value("Typ", "Zbývající dluh"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.cumulativeInterest),
                            series: .value("Typ", "Kumulativní úroky")
                        )
                        .foregroundStyle(by: .value("Typ", "Kumulativní úroky"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartForegroundStyleScale([
                        "Zbývající dluh":    Color.blue,
                        "Kumulativní úroky": Color.red
                    ])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 5)) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let y = v.as(Int.self) { Text("rok \(y)") }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let val = v.as(Double.self) {
                                    Text(czk(val, compact: true)).font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .padding(.top, 4)
                } label: {
                    Label("Zbývající dluh a celkové úroky", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                }

                // MARK: Graf 4 — Čistý roční výsledek
                // Sloupce: zelené = příjmy z nájmu překryly úroky i opravy,
                // červené = v tomto roce jsi dopláceli z vlastní kapsy.
                // Ikonka klíče označuje roky velké údržby.
                GroupBox {
                    Chart(vm.schedule) { d in
                        BarMark(
                            x: .value("Rok", d.year),
                            y: .value("Kč", d.netYear)
                        )
                        .foregroundStyle(d.netYear >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                        .cornerRadius(3)
                        .annotation(position: d.isLargeRepairYear ? .top : .overlay) {
                            if d.isLargeRepairYear {
                                Image(systemName: "wrench.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            }
                        }
                        RuleMark(x: .value("Rok", vm.snapYear))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let val = v.as(Double.self) {
                                    Text(czk(val, compact: true)).font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.top, 4)

                    HStack {
                        Image(systemName: "wrench.fill").foregroundStyle(.orange)
                        Text("= rok velké údržby").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Čistý výsledek po letech (nájem − úroky − opravy)", systemImage: "chart.bar.fill")
                        .font(.headline)
                }
            }
            .padding()
        }
    }
}

// MARK: - Table

/// Tabulkový pohled na amortizační harmonogram (rok po roku).
/// Roky velké údržby jsou označeny ikonkou klíče v sloupci Rok.
/// Mimořádné splátky jsou zobrazeny fialově; v ostatních letech je pomlčka.
struct YearTable: View {
    var vm: MortgageViewModel

    var body: some View {
        Table(vm.schedule) {
            TableColumn("Rok") { d in
                HStack(spacing: 4) {
                    Text("\(d.year).").fontWeight(.semibold)
                    if d.isLargeRepairYear {
                        Image(systemName: "wrench.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
                .monospacedDigit()
            }
            .width(70)

            TableColumn("Úroky") { d in
                Text(czk(d.interestPaid)).foregroundStyle(.red).monospacedDigit()
            }
            .width(min: 145)

            /// Sloupec pro mimořádné splátky — zobrazuje jen roky, kde byla splátka zadána a aktivní
            TableColumn("Mim. splátka") { d in
                if d.extraPayment > 0 {
                    Text(czk(d.extraPayment)).foregroundStyle(.purple).fontWeight(.semibold).monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.quaternary)
                }
            }
            .width(min: 130)

            TableColumn("Jistina") { d in
                Text(czk(d.principalPaid)).monospacedDigit()
            }
            .width(min: 135)

            TableColumn("Zbývající dluh") { d in
                Text(czk(d.remainingBalance)).foregroundStyle(.orange).monospacedDigit()
            }
            .width(min: 145)

            TableColumn("Příjmy z nájmu") { d in
                Text(czk(d.rentalIncome)).foregroundStyle(.green).monospacedDigit()
            }
            .width(min: 140)

            TableColumn("Opravy") { d in
                // Rok velké údržby je zvýrazněn tučně a oranžově
                Text(czk(d.repairCost)).foregroundStyle(d.isLargeRepairYear ? .orange : .secondary)
                    .fontWeight(d.isLargeRepairYear ? .semibold : .regular)
                    .monospacedDigit()
            }
            .width(min: 130)

            TableColumn("Čistý rok") { d in
                Text(czk(d.netYear))
                    .foregroundStyle(d.netYear >= 0 ? .green : .red)
                    .fontWeight(.semibold).monospacedDigit()
            }
            .width(min: 130)

            TableColumn("Kumulativní") { d in
                Text(czk(d.cumulativeNet))
                    .foregroundStyle(d.cumulativeNet >= 0 ? .green : .red)
                    .fontWeight(.bold).monospacedDigit()
            }
            .width(min: 145)
        }
        .scrollContentBackground(.hidden)
    }
}
