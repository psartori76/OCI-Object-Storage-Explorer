import Foundation

public enum Validators {
    public static func validateRequired(_ value: String, fieldName: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.validation(L10n.string("error.validation.required", fieldName))
        }
    }

    public static func validateOCID(_ value: String, fieldName: String) throws {
        try validateRequired(value, fieldName: fieldName)
        if !value.contains("ocid1.") {
            throw AppError.validation(L10n.string("error.validation.invalid_ocid", fieldName))
        }
    }
}
