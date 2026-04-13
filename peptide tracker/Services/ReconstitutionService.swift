enum ReconstitutionService {
    struct Result {
        let concentrationMcgPerML: Double
        let drawVolumeML: Double
        /// Number of units to draw on a standard 100-unit insulin syringe
        let syringeUnits: Double
    }

    static func calculate(
        totalMg: Double,
        bacWaterML: Double,
        targetDoseMcg: Double
    ) -> Result {
        let concentrationMcgPerML = (totalMg * 1000) / bacWaterML
        let drawVolumeML = targetDoseMcg / concentrationMcgPerML
        let syringeUnits = drawVolumeML * 100
        return Result(
            concentrationMcgPerML: concentrationMcgPerML,
            drawVolumeML: drawVolumeML,
            syringeUnits: syringeUnits
        )
    }

    static func initialDoses(totalMg: Double, targetDoseMcg: Double) -> Int {
        Int(floor((totalMg * 1000) / targetDoseMcg))
    }
}
