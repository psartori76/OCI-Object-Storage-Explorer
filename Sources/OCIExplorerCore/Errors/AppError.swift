import Foundation

public enum AppError: LocalizedError, Equatable, Sendable {
    case validation(String)
    case authentication(String)
    case network(String)
    case storage(String)
    case parsing(String)
    case configuration(String)
    case notImplemented(String)
    case cancelled
    case wrapped(String)

    public var errorDescription: String? {
        switch self {
        case let .validation(message),
             let .authentication(message),
             let .network(message),
             let .storage(message),
             let .parsing(message),
             let .configuration(message),
             let .notImplemented(message),
             let .wrapped(message):
            return message
        case .cancelled:
            return L10n.string("error.cancelled")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .validation:
            return L10n.string("error.validation.recovery")
        case .authentication:
            return L10n.string("error.authentication.recovery")
        case .network:
            return L10n.string("error.network.recovery")
        case .storage:
            return L10n.string("error.storage.recovery")
        case .parsing:
            return L10n.string("error.parsing.recovery")
        case .configuration:
            return L10n.string("error.configuration.recovery")
        case .notImplemented:
            return L10n.string("error.not_implemented.recovery")
        case .cancelled:
            return nil
        case .wrapped:
            return nil
        }
    }
}

public extension AppError {
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return .cancelled
            }
            return .network(urlError.localizedDescription)
        }

        return .wrapped(error.localizedDescription)
    }
}
