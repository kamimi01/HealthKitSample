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
    // Published という変数が他で定義されている影響なのか、「'Published' is ambiguous for type lookup in this context」のエラーが発生したので、 @SwiftUI を冒頭につけて回避
    // - seealso: https://www.reddit.com/r/iOSProgramming/comments/1070i8z/comment/j3jxr6m/?utm_source=share&utm_medium=web2x&context=3
    @SwiftUI.Published var isShowingError = false
    @SwiftUI.Published private(set) var errorMessage = ""
    /// 毎日の歩数
    @SwiftUI.Published private(set) var hourlySteps: [HealthDataTypeValue] = []
    @SwiftUI.Published private(set) var weeklySteps: [HealthDataTypeValue] = []
    @SwiftUI.Published private(set) var monthlySteps: [HealthDataTypeValue] = []
    @SwiftUI.Published private(set) var everySixMonthsSteps: [HealthDataTypeValue] = []
    @SwiftUI.Published private(set) var yearlySteps: [HealthDataTypeValue] = []

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
            calculateStepCount(frequency: .hourly)
            calculateStepCount(frequency: .weekly)
            calculateStepCount(frequency: .monthly)
            calculateStepCount(frequency: .everySixMonths)
            calculateStepCount(frequency: .yearly)
        }
    }

    /// 読み込みアクセスのリクエスト
    private func requestWriteAccessToHealthData() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータへのアクセスに失敗しました。😢"
            return
        }

        // async/await バージョン
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
        switch frequency {
        case .hourly: calculateStepCountDaily()
        case .weekly: calculateStepCountWeekly()
        case .monthly: calculateStepCountMonthly()
        case .everySixMonths: calculateStepCountEverySixMonths()
        case .yearly: calculateStepCountYealy()
        }
    }

    /// 日ごと
    private func calculateStepCountDaily() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        var endOfDay: Date {
            var components = DateComponents()
            components.day = 1
            components.second = -1
            return Calendar.current.date(byAdding: components, to: startOfDay)!
        }
        let hourly = DateComponents(hour: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startOfDay,
            intervalComponents: hourly
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .hourly, startDate: startOfDay, endDate: endOfDay)
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .hourly, startDate: startOfDay, endDate: endOfDay)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    /// 週ごと
    private func calculateStepCountWeekly() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        let daily = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startDate,
            intervalComponents: daily
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .weekly, startDate: startDate, endDate: endDate)
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .weekly, startDate: startDate, endDate: endDate)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    /// 月ごと
    private func calculateStepCountMonthly() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let endDate = Date()
        let daily = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startDate,
            intervalComponents: daily
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .monthly, startDate: startDate, endDate: endDate)
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .monthly, startDate: startDate, endDate: endDate)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    /// 6ヶ月ごと
    private func calculateStepCountEverySixMonths() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -30 * 6, to: Date())!
        let endDate = Date()
        let monthly = DateComponents(month: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startDate,
            intervalComponents: monthly
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .everySixMonths, startDate: startDate, endDate: endDate)
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .everySixMonths, startDate: startDate, endDate: endDate)
            }
        }

        healthStore?.execute(query)
        self.query = query
    }

    /// 年ごと
    private func calculateStepCountYealy() {
        guard let stepType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            isShowingError = true
            errorMessage = "ヘルスデータの読み込みに失敗しました。😢"
            return
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -30 * 12, to: Date())!
        let endDate = Date()
        let monthly = DateComponents(month: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: startDate,
            intervalComponents: monthly
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .yearly, startDate: startDate, endDate: endDate)
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
                self.updateUIFromStatistics(statisticsCollection, frequency: .yearly, startDate: startDate, endDate: endDate)
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
