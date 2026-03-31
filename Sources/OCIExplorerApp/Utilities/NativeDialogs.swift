import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum NativeDialogs {
    static func choosePrivateKeyFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Selecionar chave privada PEM"
        panel.prompt = "Usar chave"
        panel.allowedContentTypes = [.data]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Selecionar arquivos para upload"
        panel.prompt = "Selecionar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func chooseDirectory(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.prompt = "Selecionar"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    @discardableResult
    static func confirm(title: String, message: String, primary: String = "Confirmar", secondary: String = "Cancelar") -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primary)
        alert.addButton(withTitle: secondary)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func resolveDownloadDestination(fileName: String, destinationDirectory: URL) -> URL? {
        let fileManager = FileManager.default
        var candidate = destinationDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Conflito de nome"
        alert.informativeText = "O arquivo \(fileName) já existe no destino."
        alert.addButton(withTitle: "Sobrescrever")
        alert.addButton(withTitle: "Renomear")
        alert.addButton(withTitle: "Pular")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return candidate
        case .alertSecondButtonReturn:
            let baseName = candidate.deletingPathExtension().lastPathComponent
            let ext = candidate.pathExtension
            var index = 1
            repeat {
                let newName = ext.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(ext)"
                candidate = destinationDirectory.appendingPathComponent(newName)
                index += 1
            } while fileManager.fileExists(atPath: candidate.path)
            return candidate
        default:
            return nil
        }
    }

    static func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
