/// YearTable.swift — Tabulka amortizačního harmonogramu

import SwiftUI

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
