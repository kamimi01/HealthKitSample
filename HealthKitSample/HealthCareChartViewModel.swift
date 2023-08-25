//
//  HealthCareChartViewModel.swift
//  HealthKitSample
//
//  Created by mikaurakawa on 2023/08/25.
//

import Foundation
import SwiftUI
import HealthKit

@MainActor
class HealthCareChartViewModel: ObservableObject {
    @Published var isShowingError = false
    @Published private(set) var errorMessage = ""
    /// 毎日の歩数
    @Published private(set) var hourlySteps: [HealthDataTypeValue] = []
    @Published private(set) var weeklySteps: [HealthDataTypeValue] = []
    @Published private(set) var monthlySteps: [HealthDataTypeValue] = []
    @Published private(set) var everySixMonthsSteps: [HealthDataTypeValue] = []
    @Published private(set) var yearlySteps: [HealthDataTypeValue] = []

    @SwiftUI.Published var selectedFrequency: Frequency = .hourly

    private var healthStore: HKHealthStore?
    private var query: HKStatisticsCollectionQuery?

    func onAppear() {
        setupHealthKit()
    }

    private func setupHealthKit() {
        if HKHealthStore.isHealthDataAvailable() == false {
            isShowingError = true
            errorMessage = "ヘルスデータが利用できません。😢"
            return
        }

        healthStore = HKHealthStore()

        Task {
            await requestWriteAccessToHealthData()
            _ = Frequency.allCases.map { calculateStepCount(frequency: $0) }
        }
    }

    /// 読み込みアクセスのリクエスト
    private func requestWriteAccessToHealthData() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータへのアクセスに失敗しました。😢"
            return
        }

        do {
            try await healthStore?.requestAuthorization(toShare: [], read: [stepType])
        } catch {
            self.isShowingError = true
            self.errorMessage = error.localizedDescription
            return
        }
    }

    /// ヘルスデータの読み込み
    func calculateStepCount(frequency: Frequency) {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        var startDate: Date {
            switch frequency {
            case .hourly:
                return Calendar.current.startOfDay(for: Date())
            case .weekly:
                return Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            case .monthly:
                return Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            case .everySixMonths:
                return Calendar.current.date(byAdding: .day, value: -30 * 6, to: Date())!
            case .yearly:
                return Calendar.current.date(byAdding: .day, value: -30 * 12, to: Date())!
            }
        }
        var endDate: Date {
            switch frequency {
            case .hourly:
                var components = DateComponents()
                components.day = 1
                components.second = -1
                return Calendar.current.date(byAdding: components, to: startDate)!
            case .weekly, .monthly, .everySixMonths, .yearly:
                return Date()
            }
        }
        var interval: DateComponents {
            switch frequency {
            case .hourly:
                return DateComponents(hour: 1)
            case .weekly, .monthly:
                return DateComponents(day: 1)
            case .everySixMonths, .yearly:
                return DateComponents(month: 1)
            }
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] query, statisticsCollection, error in
            guard let self else { return }

            if statisticsCollection == nil || error != nil {
                DispatchQueue.main.async {
                    self.isShowingError = true
                    self.errorMessage = error?.localizedDescription ?? "予測できないエラーが発生しました。😢"
                }
                return
            }

            if let statisticsCollection {
                self.updateUIFromStatistics(statisticsCollection, frequency: frequency, startDate: startDate, endDate: endDate)
            }
        }

        /// バックグラウンドで更新されてもデータを取得できるように
        query.statisticsUpdateHandler = { [weak self] query, statistics, statisticsCollection, error in
            guard let self else { return }

            if statisticsCollection == nil || error != nil {
                DispatchQueue.main.async {
                    self.isShowingError = true
                    self.errorMessage = error?.localizedDescription ?? "予測できないエラーが発生しました。😢"
                }
                return
            }

            if let statisticsCollection {
                self.updateUIFromStatistics(statisticsCollection, frequency: frequency, startDate: startDate, endDate: endDate)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    private func updateUIFromStatistics(_ statisticsCollection: HKStatisticsCollection, frequency: Frequency, startDate: Date, endDate: Date) {

        statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { [weak self] statistics, stop in
            guard let self else { return }

            var dataValue = HealthDataTypeValue(
                startDate: statistics.startDate,
                endDate: statistics.endDate,
                value: 0
            )

            // 取得した8つ目のデータが nil になる
            guard let quantity = statistics.sumQuantity() else { return }
            let unit: HKUnit = .count()
            dataValue.value = quantity.doubleValue(for: unit)

            DispatchQueue.main.async {
                switch frequency {
                case .hourly:
                    self.hourlySteps.append(dataValue)
                case .weekly:
                    self.weeklySteps.append(dataValue)
                case .monthly:
                    self.monthlySteps.append(dataValue)
                case .everySixMonths:
                    self.everySixMonthsSteps.append(dataValue)
                case .yearly:
                    print("dataだよ１：", dataValue)
                    self.yearlySteps.append(dataValue)
                }
            }
        }
    }

    func onDisappear() {
        if let query {
            healthStore?.stop(query)
        }
    }
}
