/// InputPanel.swift — Levý panel se vstupy

import SwiftUI

struct InputPanel: View {
    @Bindable var vm: MortgageViewModel
    @State private var showScenarios = false

    var body: some View {
        Form {
            // MARK: Scénáře
            Section {
                Button {
                    showScenarios = true
                } label: {
                    Label("Správa scénářů", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } header: { Text("Scénáře") }

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

                Toggle("Zhodnocení / znehodnocení nemovitosti", isOn: $vm.includeAppreciation)
                    .tint(.blue)

                if vm.includeAppreciation {
                    SliderRow("Zhodnocení", $vm.propertyAppreciationPct,
                              -5...10, 0.25,
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
        .sheet(isPresented: $showScenarios) {
            ScenarioManagerView(vm: vm)
        }
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
