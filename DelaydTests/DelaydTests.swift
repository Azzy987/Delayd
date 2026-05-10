//
//  DelaydTests.swift
//  DelaydTests
//
//  Created by Azam on 16/04/26.
//

import Foundation
import Testing
@testable import Delayd

struct DelaydTests {
    @Test func netDelay_delayOnly() async throws {
        let status = NetDelayStatus.make(totalDelayDays: 9, recoveredDays: 0)
        #expect(status.delayedDays == 9)
        #expect(status.aheadDays == 0)
        #expect(status.isAhead == false)
    }

    @Test func netDelay_protectOnly() async throws {
        let status = NetDelayStatus.make(totalDelayDays: 0, recoveredDays: 5)
        #expect(status.delayedDays == 0)
        #expect(status.aheadDays == 5)
        #expect(status.isAhead)
    }

    @Test func netDelay_exactOffset() async throws {
        let status = NetDelayStatus.make(totalDelayDays: 12, recoveredDays: 12)
        #expect(status.delayedDays == 0)
        #expect(status.aheadDays == 0)
        #expect(status.isAhead == false)
    }

    @Test func netDelay_overRecovery() async throws {
        let status = NetDelayStatus.make(totalDelayDays: 8, recoveredDays: 11)
        #expect(status.delayedDays == 0)
        #expect(status.aheadDays == 3)
        #expect(status.isAhead)
    }

    @Test func recoveryUsesSameConversionAsDelay() async throws {
        let calculator = DelayCalculator()
        let delay = calculator.delayDays(forExpense: 1_500, monthlySavingsTarget: 10_000)
        let recovered = calculator.recoveredDelayDays(forProtected: 1_500, monthlySavingsTarget: 10_000)
        #expect(delay == recovered)
    }

    @Test func netDelay_multiGoalIsolation() async throws {
        let goalA = NetDelayStatus.make(totalDelayDays: 14, recoveredDays: 4)
        let goalB = NetDelayStatus.make(totalDelayDays: 3, recoveredDays: 10)
        #expect(goalA.delayedDays == 10)
        #expect(goalA.aheadDays == 0)
        #expect(goalB.delayedDays == 0)
        #expect(goalB.aheadDays == 7)
    }

}
