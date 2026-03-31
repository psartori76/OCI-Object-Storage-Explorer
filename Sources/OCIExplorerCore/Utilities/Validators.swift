import Foundation

public enum Validators {
    public static func validateRequired(_ value: String, fieldName: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.validation("O campo \(fieldName) é obrigatório.")
        }
    }

    public static func validateOCID(_ value: String, fieldName: String) throws {
        try validateRequired(value, fieldName: fieldName)
        if !value.contains("ocid1.") {
            throw AppError.validation("O campo \(fieldName) não parece ser um OCID válido.")
        }
    }
}
