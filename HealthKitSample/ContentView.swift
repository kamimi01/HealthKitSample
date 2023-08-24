//
//  HealthCareChartView.swift
//  HealthKitSample
//
//  Created by mikaurakawa on 2023/08/25.
//

import Foundation
import SwiftUI
import Charts

enum Frequency: String, CaseIterable, Identifiable {
    case hourly = "日"
    case weekly = "週"
    case monthly = "月"
    case everySixMonths = "6ヶ月ごと"
    case yearly = "年"

    var id: String { rawValue }
}

struct HealthCareChartView: View {
    @ObservedObject private var viewModel = HealthCareChartViewModel()

    var body: some View {
        VStack {
            Picker("", selection: $viewModel.selectedFrequency) {
                ForEach(Frequency.allCases) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            switch viewModel.selectedFrequency {
            case .hourly: dailyChart()
            case .weekly: weeklyChart()
            case .monthly: monthlyChart()
            case .everySixMonths: everySixMonthsChart()
            case .yearly: yearlyChart()
            }
            Spacer()
        }
        .alert(isPresented: $viewModel.isShowingError) {
            Alert(title: Text("エラー"), message: Text(viewModel.errorMessage))
        }
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

private extension HealthCareChartView {
    func dailyChart() -> some View {
        Chart {
            ForEach(viewModel.hourlySteps) { item in
                BarMark(
                    x: .value("時間", item.startDate, unit: .hour),
                    y: .value("歩数", item.value)
                )
            }
        }
    }

    func weeklyChart() -> some View {
        Chart {
            ForEach(viewModel.weeklySteps) { item in
                BarMark(
                    x: .value("日付", item.startDate, unit: .day),
                    y: .value("歩数", item.value)
                )
            }
        }
    }

    func monthlyChart() -> some View {
        Text("月")
    }

    func everySixMonthsChart() -> some View {
        Text("6ヶ月ごと")
    }

    func yearlyChart() -> some View {
        Text("年")
    }
}

struct HealthCareChartView_Previews: PreviewProvider {
    static var previews: some View {
        HealthCareChartView()
    }
}
