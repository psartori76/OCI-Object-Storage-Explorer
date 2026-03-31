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
            return "A operação foi cancelada."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .validation:
            return "Revise os campos destacados e tente novamente."
        case .authentication:
            return "Confira tenancy, user, fingerprint, região e chave privada."
        case .network:
            return "Verifique sua conectividade, a região informada e as permissões da conta."
        case .storage:
            return "Atualize a visualização e tente novamente. Se persistir, valide as permissões do bucket."
        case .parsing:
            return "Confira o formato dos dados retornados pela API ou da chave privada informada."
        case .configuration:
            return "Revise a configuração do perfil e salve novamente."
        case .notImplemented:
            return "Esse fluxo está preparado para evolução futura."
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
