import Foundation

struct BattleBalance: Equatable, Sendable {
    let baseHP: Int
    let defenseToHPDivisor: Int
    let minimumEnergy: Int
    let maximumEnergy: Int
    let energyToMaximumDivisor: Int
    let attackEnergyCost: Int
    let defenseEnergyCost: Int
    let chargeRecoveryByTiming: [TimingResult: Int]
    let baseAttackDamage: Int
    let powerToDamageDivisor: Int
    let baseDefenseReductionPercent: Int
    let defenseToReductionDivisor: Int
    let maximumBaseDefenseReductionPercent: Int
    let maximumDefenseReductionPercent: Int
    let defenseTimingPercent: [TimingResult: Int]
    let attackTimingPercent: [TimingResult: Int]
    let perfectTimingHalfWidth: Double
    let baseGoodTimingHalfWidth: Double
    let agilityToGoodTimingWidthDivisor: Int
    let maximumGoodTimingHalfWidth: Double
    let cpuActionWeights: [BattleAction: Int]
    let cpuTimingWeights: [TimingResult: Int]
    let cpuLowHPThresholdPercent: Int
    let cpuLowHPDefenseWeightBonus: Int
    let cpuOpponentNoEnergyAttackWeightBonus: Int
    let cpuLowEnergyChargeWeightBonus: Int
    let cpuLowEnergyThreshold: Int

    static let standard = BattleBalance(
        baseHP: 80,
        defenseToHPDivisor: 1,
        minimumEnergy: 3,
        maximumEnergy: 6,
        energyToMaximumDivisor: 25,
        attackEnergyCost: 1,
        defenseEnergyCost: 1,
        chargeRecoveryByTiming: [.miss: 1, .good: 2, .perfect: 3],
        baseAttackDamage: 8,
        powerToDamageDivisor: 5,
        baseDefenseReductionPercent: 20,
        defenseToReductionDivisor: 5,
        maximumBaseDefenseReductionPercent: 50,
        maximumDefenseReductionPercent: 70,
        defenseTimingPercent: [.miss: 50, .good: 100, .perfect: 125],
        attackTimingPercent: [.miss: 75, .good: 100, .perfect: 125],
        perfectTimingHalfWidth: 0.04,
        baseGoodTimingHalfWidth: 0.12,
        agilityToGoodTimingWidthDivisor: 500,
        maximumGoodTimingHalfWidth: 0.20,
        cpuActionWeights: [.attack: 45, .defend: 25, .charge: 30],
        cpuTimingWeights: [.miss: 10, .good: 70, .perfect: 20],
        cpuLowHPThresholdPercent: 35,
        cpuLowHPDefenseWeightBonus: 30,
        cpuOpponentNoEnergyAttackWeightBonus: 30,
        cpuLowEnergyChargeWeightBonus: 30,
        cpuLowEnergyThreshold: 1
    )

    func maximumHP(for creature: Creature) -> Int {
        baseHP + creature.stats.defense / max(1, defenseToHPDivisor)
    }

    func maximumEnergy(for creature: Creature) -> Int {
        let calculated = 2 + creature.stats.energy / max(1, energyToMaximumDivisor)
        return min(maximumEnergy, max(minimumEnergy, calculated))
    }

    func attackDamage(for creature: Creature, timing: TimingResult) -> Int {
        let baseDamage = baseAttackDamage + creature.stats.power / max(1, powerToDamageDivisor)
        return applyingPercent(baseDamage, percent: attackTimingPercent[timing] ?? 100)
    }

    func defenseReductionPercent(for creature: Creature, timing: TimingResult) -> Int {
        let baseReduction = min(
            maximumBaseDefenseReductionPercent,
            baseDefenseReductionPercent + creature.stats.defense / max(1, defenseToReductionDivisor)
        )
        return min(
            maximumDefenseReductionPercent,
            applyingPercent(baseReduction, percent: defenseTimingPercent[timing] ?? 100)
        )
    }

    func chargeRecovery(for timing: TimingResult) -> Int {
        chargeRecoveryByTiming[timing] ?? 0
    }

    func goodTimingHalfWidth(for agility: Int) -> Double {
        min(
            maximumGoodTimingHalfWidth,
            baseGoodTimingHalfWidth + Double(max(0, agility)) / Double(max(1, agilityToGoodTimingWidthDivisor))
        )
    }

    func applyingPercent(_ value: Int, percent: Int) -> Int {
        value * max(0, percent) / 100
    }
}
