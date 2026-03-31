import CryptoKit
import Foundation
import OCIExplorerCore
import Security

public protocol OCIRequestSignerProtocol: Sendable {
    func sign(_ request: URLRequest, bodyData: Data?, auth: OCIAuthenticationConfig) throws -> URLRequest
}

public struct OCIRequestSigner: OCIRequestSignerProtocol {
    public init() {}

    public func sign(_ request: URLRequest, bodyData: Data?, auth: OCIAuthenticationConfig) throws -> URLRequest {
        guard let url = request.url else {
            throw AppError.configuration("A requisição não possui URL válida.")
        }

        var signedRequest = request
        signedRequest.setValue(url.host ?? auth.objectStorageHost, forHTTPHeaderField: "host")
        signedRequest.setValue(httpDateString(), forHTTPHeaderField: "x-date")

        let method = signedRequest.httpMethod?.uppercased() ?? "GET"
        var signedHeaders = ["(request-target)", "host", "x-date"]

        if let bodyData, ["POST", "PUT"].contains(method) {
            let contentSHA = Data(SHA256.hash(data: bodyData)).base64EncodedString()
            signedRequest.setValue(contentSHA, forHTTPHeaderField: "x-content-sha256")
            signedRequest.setValue(String(bodyData.count), forHTTPHeaderField: "content-length")
            if signedRequest.value(forHTTPHeaderField: "content-type") == nil {
                signedRequest.setValue("application/json", forHTTPHeaderField: "content-type")
            }
            signedHeaders.append(contentsOf: ["x-content-sha256", "content-type", "content-length"])
        }

        let signingLines = try signedHeaders.map { header in
            switch header {
            case "(request-target)":
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let encodedPath = components?.percentEncodedPath ?? url.path
                let path = encodedPath.isEmpty ? "/" : encodedPath
                let querySuffix = components?.percentEncodedQuery.map { "?\($0)" } ?? ""
                return "(request-target): \(method.lowercased()) \(path)\(querySuffix)"
            default:
                guard let value = signedRequest.value(forHTTPHeaderField: header) else {
                    throw AppError.configuration("Cabeçalho obrigatório ausente para assinatura: \(header)")
                }
                return "\(header): \(value)"
            }
        }

        let stringToSign = signingLines.joined(separator: "\n")
        let signature = try signRSA(message: Data(stringToSign.utf8), auth: auth)
        let authorization = """
        Signature version="1",keyId="\(auth.keyID)",algorithm="rsa-sha256",headers="\(signedHeaders.joined(separator: " "))",signature="\(signature)"
        """
        signedRequest.setValue(authorization, forHTTPHeaderField: "authorization")
        return signedRequest
    }

    private func httpDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        return formatter.string(from: .now)
    }

    private func signRSA(message: Data, auth: OCIAuthenticationConfig) throws -> String {
        let pemBlock = try decodePEM(auth.privateKeyPEM, passphrase: auth.passphrase)
        let key = try importPrivateKey(from: pemBlock)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, &error) as Data? else {
            let description = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "Falha desconhecida ao assinar a requisição."
            throw AppError.authentication("Não foi possível assinar a requisição para o OCI. \(description)")
        }
        return signature.base64EncodedString()
    }

    private func importPrivateKey(from pemBlock: PEMBlock) throws -> SecKey {
        var attemptedPayloads = [pemBlock.derData]
        if pemBlock.kind == .privateKey, let rsaPKCS1 = try? unwrapPKCS8PrivateKeyToPKCS1(pemBlock.derData) {
            attemptedPayloads.insert(rsaPKCS1, at: 0)
        }
        if pemBlock.kind == .rsaPrivateKey {
            attemptedPayloads.append(wrapPKCS1RSAPrivateKeyAsPKCS8(pemBlock.derData))
        }

        var lastDescription = "Falha desconhecida ao carregar a chave."
        for payload in attemptedPayloads {
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: max(2048, payload.count * 8)
            ]
            var error: Unmanaged<CFError>?
            if let key = SecKeyCreateWithData(payload as CFData, attributes as CFDictionary, &error) {
                return key
            }
            lastDescription = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? lastDescription
        }

        throw AppError.authentication("Não foi possível importar a chave privada PEM. Verifique se ela é uma chave RSA válida do OCI em formato PKCS#8 ou PKCS#1. Detalhe: \(lastDescription)")
    }

    private func decodePEM(_ pem: String, passphrase: String?) throws -> PEMBlock {
        let lines = pem
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let beginLine = lines.first(where: { $0.hasPrefix("-----BEGIN ") && $0.hasSuffix("-----") }) else {
            throw AppError.parsing("A chave privada PEM não contém um cabeçalho BEGIN válido.")
        }

        let header = beginLine
            .replacingOccurrences(of: "-----BEGIN ", with: "")
            .replacingOccurrences(of: "-----", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let isEncryptedPEM = header == "ENCRYPTED PRIVATE KEY" || lines.contains(where: { $0.hasPrefix("Proc-Type:") || $0.hasPrefix("DEK-Info:") })
        if isEncryptedPEM {
            if passphrase?.isEmpty == false {
                throw AppError.notImplemented("Esta chave PEM está criptografada. O app ainda não importa PEM criptografado automaticamente. Converta para uma chave PEM RSA não criptografada para usar no OCI Explorer.")
            }
            throw AppError.authentication("A chave privada informada está criptografada. Informe uma chave PEM RSA não criptografada ou converta a chave antes de conectar.")
        }

        if header == "OPENSSH PRIVATE KEY" {
            throw AppError.authentication("O formato OPENSSH PRIVATE KEY não é aceito pelo OCI Explorer. Exporte a chave em PEM RSA para uso com a API Key do OCI.")
        }

        let base64Payload = lines
            .filter { !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") }
            .filter { !$0.contains(":") }
            .joined()
            .replacingOccurrences(of: " ", with: "")

        guard let derData = Data(base64Encoded: base64Payload, options: [.ignoreUnknownCharacters]), !derData.isEmpty else {
            throw AppError.parsing("A chave privada PEM não pôde ser convertida para DER. Verifique se o conteúdo do arquivo PEM está íntegro e em formato RSA/PKCS válido.")
        }

        let kind: PEMBlockKind
        switch header {
        case "PRIVATE KEY":
            kind = .privateKey
        case "RSA PRIVATE KEY":
            kind = .rsaPrivateKey
        default:
            throw AppError.authentication("Formato de chave não suportado: \(header). Use uma chave PEM RSA do OCI.")
        }

        return PEMBlock(kind: kind, derData: derData)
    }

    private func wrapPKCS1RSAPrivateKeyAsPKCS8(_ pkcs1Data: Data) -> Data {
        let versionInteger = Data([0x02, 0x01, 0x00])
        let rsaAlgorithmIdentifier: Data = Data([
            0x30, 0x0D,
            0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
            0x05, 0x00
        ])
        let privateKeyOctetString = asn1(tag: 0x04, content: pkcs1Data)
        return asn1(tag: 0x30, content: versionInteger + rsaAlgorithmIdentifier + privateKeyOctetString)
    }

    private func asn1(tag: UInt8, content: Data) -> Data {
        Data([tag]) + derLength(content.count) + content
    }

    private func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var value = length
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)]) + Data(bytes)
    }

    private func unwrapPKCS8PrivateKeyToPKCS1(_ pkcs8Data: Data) throws -> Data {
        var cursor = 0
        let topSequence = try readASN1Element(expectedTag: 0x30, from: pkcs8Data, cursor: &cursor)

        var innerCursor = 0
        _ = try readASN1Element(expectedTag: 0x02, from: topSequence, cursor: &innerCursor)
        let algorithmIdentifier = try readASN1Element(expectedTag: 0x30, from: topSequence, cursor: &innerCursor)
        let privateKeyOctetString = try readASN1Element(expectedTag: 0x04, from: topSequence, cursor: &innerCursor)

        guard isRSAAlgorithmIdentifier(algorithmIdentifier) else {
            throw AppError.authentication("A chave PKCS#8 informada não é uma chave RSA.")
        }

        return privateKeyOctetString
    }

    private func isRSAAlgorithmIdentifier(_ data: Data) -> Bool {
        let rsaOID = Data([0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01])
        return data.range(of: rsaOID) != nil
    }

    private func readASN1Element(expectedTag: UInt8, from data: Data, cursor: inout Int) throws -> Data {
        guard cursor < data.count else {
            throw AppError.parsing("DER inválido: fim inesperado dos dados.")
        }
        let tag = data[cursor]
        guard tag == expectedTag else {
            throw AppError.parsing("DER inválido: tag ASN.1 inesperada.")
        }
        cursor += 1

        let length = try readASN1Length(from: data, cursor: &cursor)
        let end = cursor + length
        guard end <= data.count else {
            throw AppError.parsing("DER inválido: comprimento ASN.1 fora dos limites.")
        }

        let elementData = data[cursor ..< end]
        cursor = end
        return Data(elementData)
    }

    private func readASN1Length(from data: Data, cursor: inout Int) throws -> Int {
        guard cursor < data.count else {
            throw AppError.parsing("DER inválido: comprimento ASN.1 ausente.")
        }

        let firstByte = data[cursor]
        cursor += 1

        if firstByte & 0x80 == 0 {
            return Int(firstByte)
        }

        let byteCount = Int(firstByte & 0x7F)
        guard byteCount > 0, cursor + byteCount <= data.count else {
            throw AppError.parsing("DER inválido: comprimento ASN.1 malformado.")
        }

        var length = 0
        for _ in 0 ..< byteCount {
            length = (length << 8) | Int(data[cursor])
            cursor += 1
        }
        return length
    }
}

private struct PEMBlock {
    let kind: PEMBlockKind
    let derData: Data
}

private enum PEMBlockKind {
    case privateKey
    case rsaPrivateKey
}
