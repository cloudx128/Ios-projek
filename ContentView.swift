import SwiftUI
import UniformTypeIdentifiers
import Foundation
import WebKit

struct IPAFile: FileDocument {
    static var readableContentTypes: [UTType] = [.archive]
    var fileURL: URL
    
    init(url: URL) {
        self.fileURL = url
    }
    
    init(configuration: ReadConfiguration) throws {
        throw URLError(.dataNotAllowed)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: fileURL, options: .immediate)
    }
}

func generateIPA() async throws -> URL {
    let bundleURL = Bundle.main.bundleURL
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let payloadDir = tempDir.appendingPathComponent("Payload")
    
    try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true, attributes: nil)
    
    let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "App"
    let appURL = payloadDir.appendingPathComponent("\(appName).app")
    let ipaURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(appName).ipa")
    
    try FileManager.default.copyItem(at: bundleURL, to: appURL)
    
    let coordinator = NSFileCoordinator()
    var coordError: NSError?
    var taskError: Error?
    
    coordinator.coordinate(readingItemAt: payloadDir, options: [.forUploading], error: &coordError) { zippedURL in
        do {
            if FileManager.default.fileExists(atPath: ipaURL.path) {
                try FileManager.default.removeItem(at: ipaURL)
            }
            try FileManager.default.moveItem(at: zippedURL, to: ipaURL)
        } catch {
            taskError = error
        }
    }
    
    if let finalError = taskError ?? coordError {
        throw finalError
    }
    
    try? FileManager.default.removeItem(at: tempDir)
    
    return ipaURL
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ContentView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var isExporting = false
    @State private var ipaFile: IPAFile?
    @FocusState private var isInputFocused: Bool
    @State private var showExportMenu = false
    
    let apiKey = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if showExportMenu {
                        HStack {
                            Spacer()
                            Button(action: {
                                Task {
                                    if let url = try? await generateIPA() {
                                        ipaFile = IPAFile(url: url)
                                        isExporting = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export IPA")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                }
                                
                                if isTyping {
                                    HStack {
                                        Text("Gemini sedang berpikir...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .id("typingIndicator")
                                }
                            }
                            .padding()
                            .frame(maxWidth: 800)
                        }
                        .onChange(of: messages.count) { _ in
                            withAnimation {
                                proxy.scrollTo(messages.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: isTyping) { _ in
                            if isTyping {
                                withAnimation {
                                    proxy.scrollTo("typingIndicator", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    VStack {
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            
                            TextField("Tanya sesuatu...", text: $inputText)
                                .font(.system(size: 16))
                                .focused($isInputFocused)
                            
                            Button(action: sendMessage) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                                    .clipShape(Circle())
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isTyping)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 800)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("IPAW AI")
                        .font(.headline)
                        .onLongPressGesture(minimumDuration: 1.5) {
                            withAnimation {
                                showExportMenu.toggle()
                            }
                        }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: ipaFile,
                contentType: .archive,
                defaultFilename: "AIChat.ipa"
            ) { _ in }
        }
        .navigationViewStyle(.stack)
    }
    
    func sendMessage() {
        let userText = inputText.trimmingCharacters(in: .whitespaces)
        guard !userText.isEmpty else { return }
        
        isInputFocused = false
        let userMessage = ChatMessage(text: userText, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isTyping = true
        
        Task {
            await fetchGeminiResponse(for: userText)
        }
    }
    
    func fetchGeminiResponse(for text: String) async {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorDict = json["error"] as? [String: Any], let errorMessage = errorDict["message"] as? String {
                    DispatchQueue.main.async {
                        let botMessage = ChatMessage(text: "Error: \(errorMessage)", isUser: false)
                        self.messages.append(botMessage)
                        self.isTyping = false
                    }
                    return
                }
                
                if let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let responseText = firstPart["text"] as? String {
                    
                    DispatchQueue.main.async {
                        let botMessage = ChatMessage(text: responseText, isUser: false)
                        self.messages.append(botMessage)
                        self.isTyping = false
                    }
                } else {
                    DispatchQueue.main.async {
                        let botMessage = ChatMessage(text: "Format respons tidak dikenali.", isUser: false)
                        self.messages.append(botMessage)
                        self.isTyping = false
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                let errorMessage = ChatMessage(text: "Gagal terhubung: \(error.localizedDescription)", isUser: false)
                self.messages.append(errorMessage)
                self.isTyping = false
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            if message.isUser {
                Text(message.text)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20, corners: [.topLeft, .topRight, .bottomLeft])
                    .frame(maxWidth: 600, alignment: .trailing)
            } else {
                CustomMarkdownView(text: message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
                    .frame(maxWidth: 600, alignment: .leading)
            }
            
            if !message.isUser { Spacer() }
        }
    }
}

enum MessageBlock: Hashable {
    case text(String)
    case table([[String]])
}

struct CustomMarkdownView: View {
    let text: String
    
    var body: some View {
        let blocks = parseMessageBlocks(text)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<blocks.count, id: \.self) { index in
                switch blocks[index] {
                case .text(let content):
                    VStack(alignment: .leading, spacing: 6) {
                        let lines = content.components(separatedBy: "\n")
                        ForEach(0..<lines.count, id: \.self) { lIndex in
                            let line = lines[lIndex]
                            if let list = parseListItem(line) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(list.symbol)
                                        .font(.system(size: 16, weight: list.symbol == "•" ? .bold : .medium))
                                    if let attrString = try? AttributedString(markdown: list.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                        Text(attrString)
                                            .font(.system(size: 16))
                                            .lineSpacing(4)
                                    } else {
                                        Text(list.text)
                                            .font(.system(size: 16))
                                            .lineSpacing(4)
                                    }
                                }
                                .padding(.leading, CGFloat(list.indentSpaces) * 6)
                            } else {
                                if let attrString = try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attrString)
                                        .font(.system(size: 16))
                                        .lineSpacing(4)
                                } else {
                                    Text(line)
                                        .font(.system(size: 16))
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                case .table(let rows):
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(0..<rows.count, id: \.self) { rIndex in
                                HStack(spacing: 1) {
                                    ForEach(0..<rows[rIndex].count, id: \.self) { cIndex in
                                        let cellText = rows[rIndex][cIndex]
                                        let cellView = Group {
                                            if let attrString = try? AttributedString(markdown: cellText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                                Text(attrString)
                                            } else {
                                                Text(cellText)
                                            }
                                        }
                                        
                                        cellView
                                            .font(.system(size: 14, weight: rIndex == 0 ? .semibold : .regular))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            // fixedSize memastikan tulisan yang kepanjangan membungkus ke baris baru, bukan menghilang (...)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 250, maxHeight: .infinity, alignment: .topLeading)
                                            .background(Color(.systemBackground))
                                    }
                                }
                            }
                        }
                        .background(Color.gray.opacity(0.3))
                        .overlay(Rectangle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }
    
    struct ListItem {
        let symbol: String
        let text: String
        let indentSpaces: Int
    }
    
    func parseListItem(_ line: String) -> ListItem? {
        var spaces = 0
        for char in line {
            if char == " " || char == "\t" { spaces += 1 } else { break }
        }
        
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
            let textIdx = trimmed.index(trimmed.startIndex, offsetBy: 2)
            return ListItem(symbol: "•", text: String(trimmed[textIdx...]), indentSpaces: spaces)
        }
        
        if let spaceIdx = trimmed.firstIndex(of: " ") {
            let prefix = String(trimmed[..<spaceIdx])
            if prefix.hasSuffix(".") && Int(prefix.dropLast()) != nil {
                let text = String(trimmed[trimmed.index(after: spaceIdx)...])
                return ListItem(symbol: prefix, text: text, indentSpaces: spaces)
            }
        }
        return nil
    }
    
    func parseMessageBlocks(_ text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentText = ""
        var currentTable: [[String]] = []
        var isParsingTable = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 1 {
                if !isParsingTable {
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentText = ""
                    }
                    isParsingTable = true
                }
                
                let noSpaces = trimmed.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                if noSpaces.isEmpty { continue }
                
                var columns = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if columns.first == "" { columns.removeFirst() }
                if columns.last == "" { columns.removeLast() }
                currentTable.append(columns)
            } else {
                if isParsingTable {
                    blocks.append(.table(currentTable))
                    currentTable = []
                    isParsingTable = false
                }
                currentText += line + "\n"
            }
        }
        
        if isParsingTable {
            blocks.append(.table(currentTable))
        } else if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return blocks
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
