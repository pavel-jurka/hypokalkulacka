/// SnapshotHeader.swift — Slider roku + kumulativní karty

import SwiftUI

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
