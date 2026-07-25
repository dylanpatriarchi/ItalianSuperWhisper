import AppKit
import Carbon
import Combine
import Foundation
import KeyboardShortcuts
import SwiftUI
import FluidAudio

class SettingsViewModel: ObservableObject {
    @Published var selectedEngine: String {
        didSet {
            AppPreferences.shared.selectedEngine = selectedEngine
            if selectedEngine == "whisper" {
                loadAvailableModels()
            } else {
                initializeFluidAudioModels()
            }
            resetLanguageIfUnsupported()
            Task { @MainActor in
                TranscriptionService.shared.reloadEngine()
            }
        }
    }
    
    @Published var fluidAudioModelVersion: String {
        didSet {
            AppPreferences.shared.fluidAudioModelVersion = fluidAudioModelVersion
            if selectedEngine == "fluidaudio" {
                Task { @MainActor in
                    TranscriptionService.shared.reloadEngine()
                }
            }
            initializeFluidAudioModels()
            resetLanguageIfUnsupported()
        }
    }
    
    var supportedLanguages: [String] {
        LanguageUtil.supportedLanguages(engine: selectedEngine, fluidAudioModelVersion: fluidAudioModelVersion)
    }
    
    private func resetLanguageIfUnsupported() {
        if !supportedLanguages.contains(selectedLanguage) {
            selectedLanguage = LanguageUtil.fallbackLanguage(engine: selectedEngine)
        } else {
            NotificationCenter.default.post(name: .appPreferencesLanguageChanged, object: nil)
        }
    }
    
    @Published var selectedModelURL: URL? {
        didSet {
            if let url = selectedModelURL {
                AppPreferences.shared.selectedWhisperModelPath = url.path
            }
        }
    }

    /// User-initiated model selection. Persists the model and, if the model declares a
    /// preferred language (e.g. the ivrit.ai Hebrew model), switches the language to it.
    /// Do not call from init/restore — only in response to an explicit user action.
    func selectModel(_ url: URL) {
        selectedModelURL = url
        if let lang = SettingsDownloadableModels.preferredLanguage(forFilename: url.lastPathComponent),
           selectedLanguage != lang {
            selectedLanguage = lang
        }
    }

    @Published var availableModels: [URL] = []
    
    @Published var downloadableModels: [SettingsDownloadableModel] = []
    @Published var downloadableFluidAudioModels: [SettingsFluidAudioModel] = []
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModelName: String?
    private var downloadTask: Task<Void, Error>?
    
    @Published var selectedLanguage: String {
        didSet {
            AppPreferences.shared.whisperLanguage = selectedLanguage
            NotificationCenter.default.post(name: .appPreferencesLanguageChanged, object: nil)
        }
    }

    @Published var suppressBlankAudio: Bool {
        didSet {
            AppPreferences.shared.suppressBlankAudio = suppressBlankAudio
        }
    }

    @Published var showTimestamps: Bool {
        didSet {
            AppPreferences.shared.showTimestamps = showTimestamps
        }
    }
    
    @Published var temperature: Double {
        didSet {
            AppPreferences.shared.temperature = temperature
        }
    }

    @Published var noSpeechThreshold: Double {
        didSet {
            AppPreferences.shared.noSpeechThreshold = noSpeechThreshold
        }
    }

    @Published var initialPrompt: String {
        didSet {
            AppPreferences.shared.initialPrompt = initialPrompt
        }
    }

    @Published var useBeamSearch: Bool {
        didSet {
            AppPreferences.shared.useBeamSearch = useBeamSearch
        }
    }

    @Published var beamSize: Int {
        didSet {
            AppPreferences.shared.beamSize = beamSize
        }
    }

    @Published var debugMode: Bool {
        didSet {
            AppPreferences.shared.debugMode = debugMode
        }
    }
    
    @Published var playSoundOnRecordStart: Bool {
        didSet {
            AppPreferences.shared.playSoundOnRecordStart = playSoundOnRecordStart
        }
    }
    
    @Published var modifierOnlyHotkey: ModifierKey {
        didSet {
            AppPreferences.shared.modifierOnlyHotkey = modifierOnlyHotkey.rawValue
            if modifierOnlyHotkey != .none {
                AppPreferences.shared.lastModifierOnlyHotkey = modifierOnlyHotkey.rawValue
            }
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    @Published var mouseButtonHotkey: MouseButton {
        didSet {
            AppPreferences.shared.mouseButtonHotkey = mouseButtonHotkey.rawValue
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }
    
    @Published var holdToRecord: Bool {
        didSet {
            AppPreferences.shared.holdToRecord = holdToRecord
        }
    }

    @Published var doublePressToTrigger: Bool {
        didSet {
            AppPreferences.shared.doublePressToTrigger = doublePressToTrigger
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }
    
    @Published var escCancelWithoutConfirmation: Bool {
        didSet {
            AppPreferences.shared.escCancelWithoutConfirmation = escCancelWithoutConfirmation
        }
    }

    @Published var startHiddenInMenuBar: Bool {
        didSet {
            AppPreferences.shared.startHiddenInMenuBar = startHiddenInMenuBar
        }
    }
    
    @Published var addSpaceAfterSentence: Bool {
        didSet {
            AppPreferences.shared.addSpaceAfterSentence = addSpaceAfterSentence
        }
    }

    @Published var reformulationEnabled: Bool {
        didSet {
            AppPreferences.shared.reformulationEnabled = reformulationEnabled
        }
    }

    @Published var autoCopyToClipboard: Bool {
        didSet {
            AppPreferences.shared.autoCopyToClipboard = autoCopyToClipboard
        }
    }

    @Published var autoPasteTranscription: Bool {
        didSet {
            AppPreferences.shared.autoPasteTranscription = autoPasteTranscription
        }
    }

    init() {
        let prefs = AppPreferences.shared
        self.selectedEngine = prefs.selectedEngine
        self.fluidAudioModelVersion = prefs.fluidAudioModelVersion
        self.selectedLanguage = prefs.whisperLanguage
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.showTimestamps = prefs.showTimestamps
        self.temperature = prefs.temperature
        self.noSpeechThreshold = prefs.noSpeechThreshold
        self.initialPrompt = prefs.initialPrompt
        self.useBeamSearch = prefs.useBeamSearch
        self.beamSize = prefs.beamSize
        self.debugMode = prefs.debugMode
        self.playSoundOnRecordStart = prefs.playSoundOnRecordStart
        self.modifierOnlyHotkey = ModifierKey(rawValue: prefs.modifierOnlyHotkey) ?? .none
        self.mouseButtonHotkey = MouseButton(rawValue: prefs.mouseButtonHotkey) ?? .none
        self.holdToRecord = prefs.holdToRecord
        self.doublePressToTrigger = prefs.doublePressToTrigger
        self.escCancelWithoutConfirmation = prefs.escCancelWithoutConfirmation
        self.startHiddenInMenuBar = prefs.startHiddenInMenuBar
        self.addSpaceAfterSentence = prefs.addSpaceAfterSentence
        self.reformulationEnabled = prefs.reformulationEnabled
        self.autoCopyToClipboard = prefs.autoCopyToClipboard
        self.autoPasteTranscription = prefs.autoPasteTranscription

        if let savedPath = prefs.selectedWhisperModelPath ?? prefs.selectedModelPath {
            self.selectedModelURL = URL(fileURLWithPath: savedPath)
        }
        loadAvailableModels()
        initializeDownloadableModels()
        initializeFluidAudioModels()
        
        if !supportedLanguages.contains(selectedLanguage) {
            let fallback = LanguageUtil.fallbackLanguage(engine: selectedEngine)
            selectedLanguage = fallback
            AppPreferences.shared.whisperLanguage = fallback
            NotificationCenter.default.post(name: .appPreferencesLanguageChanged, object: nil)
        }
    }
    
    func initializeFluidAudioModels() {
        downloadableFluidAudioModels = SettingsFluidAudioModels.availableModels.map { model in
            var updatedModel = model
            updatedModel.isDownloaded = isFluidAudioModelDownloaded(version: model.version)
            return updatedModel
        }
    }
    
    func isFluidAudioModelDownloaded(version: String) -> Bool {
        let asrVersion: AsrModelVersion = version == "v2" ? .v2 : .v3
        
        // Используем правильный путь к кэшу согласно документации:
        // ~/Library/Application Support/FluidAudio/Models/<version-folder>/
        let cacheDirectory = AsrModels.defaultCacheDirectory(for: asrVersion)
        
        // Проверяем наличие всех необходимых файлов модели
        return AsrModels.modelsExist(at: cacheDirectory, version: asrVersion)
    }
    
    func initializeDownloadableModels() {
        let modelManager = WhisperModelManager.shared
        downloadableModels = SettingsDownloadableModels.availableModels.map { model in
            var updatedModel = model
            let filename = model.filename
            updatedModel.isDownloaded = modelManager.isModelDownloaded(name: filename)
            return updatedModel
        }
    }
    
    func loadAvailableModels() {
        availableModels = WhisperModelManager.shared.getAvailableModels()
        if selectedModelURL == nil {
            selectedModelURL = availableModels.first
        }
        initializeDownloadableModels()
    }
    
    @MainActor
    func downloadModel(_ model: SettingsDownloadableModel) async throws {
        guard !isDownloading else { return }
        try DiskSpaceUtil.ensureEnoughFreeSpaceForModelDownload()
        
        isDownloading = true
        downloadingModelName = model.name
        downloadProgress = 0.0
        
        downloadTask = Task {
            do {
                let filename = model.filename
                
                try await WhisperModelManager.shared.downloadModel(url: model.url, name: filename) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        guard let task = self.downloadTask, !task.isCancelled else { return }
                        
                        self.downloadProgress = progress
                        if let index = self.downloadableModels.firstIndex(where: { $0.name == model.name }) {
                            self.downloadableModels[index].downloadProgress = progress
                            if progress >= 1.0 {
                                self.downloadableModels[index].isDownloaded = true
                            }
                        }
                    }
                }
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.downloadableModels.firstIndex(where: { $0.name == model.name }) {
                            self.downloadableModels[index].downloadProgress = 0.0
                        }
                    }
                    return
                }
                
                await MainActor.run {
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].isDownloaded = true
                        downloadableModels[index].downloadProgress = 0.0
                    }
                    loadAvailableModels()
                    let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(filename).path
                    selectModel(URL(fileURLWithPath: modelPath))
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    
                    Task { @MainActor in
                        TranscriptionService.shared.reloadModel(with: modelPath)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].downloadProgress = 0.0
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = downloadableModels.firstIndex(where: { $0.name == model.name }) {
                        downloadableModels[index].downloadProgress = 0.0
                    }
                }
                throw error
            }
        }
        
        try await downloadTask?.value
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        if let modelName = downloadingModelName {
            if selectedEngine == "whisper", let model = downloadableModels.first(where: { $0.name == modelName }) {
                let filename = model.filename
                WhisperModelManager.shared.cancelDownload(name: filename)
            }
            // Reset progress for the downloading model
            if let index = downloadableModels.firstIndex(where: { $0.name == modelName }) {
                downloadableModels[index].downloadProgress = 0.0
            }
            if let index = downloadableFluidAudioModels.firstIndex(where: { $0.name == modelName }) {
                downloadableFluidAudioModels[index].downloadProgress = 0.0
            }
        }
        isDownloading = false
        downloadingModelName = nil
        downloadProgress = 0.0
    }
    
    @MainActor
    func downloadFluidAudioModel(_ model: SettingsFluidAudioModel) async throws {
        guard !isDownloading else { return }
        try DiskSpaceUtil.ensureEnoughFreeSpaceForModelDownload()
        
        isDownloading = true
        downloadingModelName = model.name
        downloadProgress = 0.0
        
        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
            downloadableFluidAudioModels[index].downloadProgress = 0.0
        }
        
        var wasCancelled = false
        
        downloadTask = Task {
            do {
                let version: AsrModelVersion = model.version == "v2" ? .v2 : .v3
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                let modelId = model.id
                let models = try await AsrModels.downloadAndLoad(version: version) { [weak self] progress in
                    print("[ParakeetProgress] fraction=\(progress.fractionCompleted) phase=\(progress.phase)")
                    Task { @MainActor [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        guard let task = self.downloadTask, !task.isCancelled else { return }
                        self.downloadProgress = progress.fractionCompleted
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == modelId }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = progress.fractionCompleted
                        }
                    }
                }
                
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                        if let index = self.downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            self.downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw CancellationError()
                }
                
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                
                await MainActor.run {
                    if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                        downloadableFluidAudioModels[index].isDownloaded = true
                        downloadableFluidAudioModels[index].downloadProgress = 1.0
                    }
                    fluidAudioModelVersion = model.version
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 1.0
                    
                    Task { @MainActor in
                        TranscriptionService.shared.reloadEngine()
                    }
                }
            } catch is CancellationError {
                wasCancelled = true
                await MainActor.run {
                    isDownloading = false
                    downloadingModelName = nil
                    downloadProgress = 0.0
                    if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                        downloadableFluidAudioModels[index].downloadProgress = 0.0
                    }
                }
                // Don't re-throw CancellationError - it's a manual cancellation
            } catch {
                // Check if we were cancelled before the error occurred
                if Task.isCancelled {
                    wasCancelled = true
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                } else {
                    await MainActor.run {
                        isDownloading = false
                        downloadingModelName = nil
                        downloadProgress = 0.0
                        if let index = downloadableFluidAudioModels.firstIndex(where: { $0.id == model.id }) {
                            downloadableFluidAudioModels[index].downloadProgress = 0.0
                        }
                    }
                    throw error
                }
            }
        }
        
        // Handle cancellation gracefully - don't throw if cancelled
        do {
            try await downloadTask?.value
        } catch is CancellationError {
            // Already handled in catch block above, just consume the error
            wasCancelled = true
        } catch {
            // If we were cancelled, don't throw
            if !wasCancelled {
                throw error
            }
        }
    }
    
    @MainActor
    func downloadFluidAudioModel() async throws {
        let versionString = AppPreferences.shared.fluidAudioModelVersion
        if let model = downloadableFluidAudioModels.first(where: { $0.version == versionString }) {
            try await downloadFluidAudioModel(model)
        }
    }
}

struct SettingsDownloadableModel: Identifiable {
    let id = UUID()
    let name: String
    var isDownloaded: Bool
    let url: URL
    let size: Int
    let description: String
    var downloadProgress: Double = 0.0
    let filename: String
    let preferredLanguage: String?

    var sizeString: String {
        formatModelSize(megabytes: size)
    }

    var huggingFacePageURL: URL? {
        makeHuggingFacePageURL(fromDownloadURL: url)
    }

    init(name: String, isDownloaded: Bool, url: URL, size: Int, description: String,
         filename: String? = nil, preferredLanguage: String? = nil) {
        self.name = name
        self.isDownloaded = isDownloaded
        self.url = url
        self.size = size
        self.description = description
        self.filename = filename ?? url.lastPathComponent
        self.preferredLanguage = preferredLanguage
    }
}

struct SettingsDownloadableModels {
    static let availableModels = [
        SettingsDownloadableModel(
            name: "Turbo V3 large",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
            size: 1624,
            description: "Massima accuratezza, qualità migliore"
        ),
        SettingsDownloadableModel(
            name: "Turbo V3 medium",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin?download=true")!,
            size: 874,
            description: "Equilibrio tra velocità e accuratezza"
        ),
        SettingsDownloadableModel(
            name: "Turbo V3 small",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true")!,
            size: 574,
            description: "Elaborazione più veloce"
        ),
        SettingsDownloadableModel(
            name: "Turbo V3 Hebrew",
            isDownloaded: false,
            url: URL(string: "https://huggingface.co/ivrit-ai/whisper-large-v3-turbo-ggml/resolve/main/ggml-model.bin?download=true")!,
            size: 1624,
            description: "Turbo V3 ottimizzato per l'ebraico da ivrit.ai. Imposta la lingua su ebraico.",
            filename: "ggml-ivrit-large-v3-turbo.bin",
            preferredLanguage: "he"
        )
    ]

    static func preferredLanguage(forFilename filename: String) -> String? {
        availableModels.first { $0.filename == filename }?.preferredLanguage
    }

    static func isVisible(_ model: SettingsDownloadableModel,
                          selectedLanguage: String,
                          systemLanguage: String) -> Bool {
        guard let lang = model.preferredLanguage else { return true }
        if model.isDownloaded { return true }
        return selectedLanguage == lang || systemLanguage == lang
    }
}

func countLabel(_ count: Int, singular: String, plural: String) -> String {
    count == 1 ? "\(count) \(singular)" : "\(count) \(plural)"
}

func formatModelSize(megabytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: Int64(megabytes) * 1000000)
}

func makeHuggingFacePageURL(fromDownloadURL url: URL) -> URL? {
    let absoluteString = url.absoluteString
    guard let range = absoluteString.range(of: "/resolve/") else { return nil }
    return URL(string: String(absoluteString[..<range.lowerBound]))
}

/// The Hugging Face owner (user / organization) from a model page URL,
/// e.g. https://huggingface.co/ivrit-ai/whisper-... -> "ivrit-ai".
func huggingFaceOwner(fromPageURL url: URL) -> String? {
    url.pathComponents.first { $0 != "/" }
}

struct Settings {
    var selectedLanguage: String
    var suppressBlankAudio: Bool
    var showTimestamps: Bool
    var temperature: Double
    var noSpeechThreshold: Double
    var initialPrompt: String
    var useBeamSearch: Bool
    var beamSize: Int
    
    /// Italian-only deterministic corrections. Gated on an explicit "it": with
    /// "auto" the language is not known here, and these rules must never run on
    /// another language.
    var shouldApplyItalianCorrections: Bool {
        selectedLanguage == "it"
    }
    
    init() {
        let prefs = AppPreferences.shared
        self.selectedLanguage = prefs.whisperLanguage
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.showTimestamps = prefs.showTimestamps
        self.temperature = prefs.temperature
        self.noSpeechThreshold = prefs.noSpeechThreshold
        self.initialPrompt = prefs.initialPrompt
        self.useBeamSearch = prefs.useBeamSearch
        self.beamSize = prefs.beamSize
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var permissionsManager = PermissionsManager()
    @Environment(\.dismiss) var dismiss
    @State private var isRecordingNewShortcut = false
    @State private var selectedTab = 0
    @State private var previousModelURL: URL?
    
    private var sheetSize: CGSize {
        let visibleFrame = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        let width = min(550, visibleFrame.width - 40)
        let height = min(500, visibleFrame.height - 60)
        return CGSize(width: width, height: height)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {

             // Shortcut Settings
            shortcutSettings
                .tabItem {
                    Label("Scorciatoie", systemImage: "command")
                }
                .tag(0)
            // Model Settings
            modelSettings
                .tabItem {
                    Label("Modello", systemImage: "cpu")
                }
                .tag(1)
            
            // Transcription Settings
            transcriptionSettings
                .tabItem {
                    Label("Trascrizione", systemImage: "text.bubble")
                }
                .tag(2)
            
            // Advanced Settings
            advancedSettings
                .tabItem {
                    Label("Avanzate", systemImage: "gear")
                }
                .tag(3)
            }
        .padding()
        .frame(width: sheetSize.width, height: sheetSize.height)
        .background(Color(.windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Fine") {
                    if viewModel.selectedEngine == "whisper" {
                        if viewModel.selectedModelURL != previousModelURL, let modelPath = viewModel.selectedModelURL?.path {
                            TranscriptionService.shared.reloadModel(with: modelPath)
                        }
                    }
                    dismiss()
                }
                .glassProminentButton()
                .controlSize(.regular)
                
                Spacer()
                
                Link(destination: URL(string: "https://github.com/dylanpatriarchi/ItalianSuperWhisper")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "star")
                            .font(.system(size: 10))
                        Text("GitHub")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .onAppear {
            previousModelURL = viewModel.selectedModelURL
            if viewModel.selectedEngine == "fluidaudio" {
                viewModel.initializeFluidAudioModels()
            }
        }
        .onChange(of: viewModel.selectedEngine) { _, newEngine in
            if newEngine == "fluidaudio" {
                viewModel.initializeFluidAudioModels()
            }
        }
        .onChange(of: viewModel.fluidAudioModelVersion) { _, _ in
            Task { @MainActor in
                TranscriptionService.shared.reloadEngine()
            }
        }
        .onChange(of: viewModel.selectedModelURL) { _, newURL in
            if viewModel.selectedEngine == "whisper", let modelPath = newURL?.path {
                Task { @MainActor in
                    TranscriptionService.shared.reloadModel(with: modelPath)
                }
            }
        }
    }
    
    private var modelSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Motore di riconoscimento vocale")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Motore", selection: $viewModel.selectedEngine) {
                    Text("Parakeet").tag("fluidaudio")
                    Text("Whisper").tag("whisper")
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)
                
                if viewModel.selectedEngine == "whisper" {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Modello Whisper")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Scarica modelli")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        VStack(spacing: 12) {
                            ForEach($viewModel.downloadableModels) { $model in
                                if SettingsDownloadableModels.isVisible(model,
                                        selectedLanguage: viewModel.selectedLanguage,
                                        systemLanguage: LanguageUtil.getSystemLanguage()) {
                                    ModelDownloadItemView(model: $model, viewModel: viewModel)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cartella dei modelli:")
                                    .font(.subheadline)
                                Button(action: {
                                    NSWorkspace.shared.open(WhisperModelManager.shared.modelsDirectory)
                                }) {
                                    Label("Apri cartella", systemImage: "folder")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                                .help("Apri la cartella dei modelli")
                            }
                            Text(WhisperModelManager.shared.modelsDirectory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Modello Parakeet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Scarica modelli")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        VStack(spacing: 12) {
                            ForEach($viewModel.downloadableFluidAudioModels) { $model in
                                FluidAudioModelDownloadItemView(model: $model, viewModel: viewModel)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cartella dei modelli:")
                                    .font(.subheadline)
                                Button(action: {
                                    let cacheDir = AsrModels.defaultCacheDirectory(for: .v3)
                                    let parentDir = cacheDir.deletingLastPathComponent()
                                    NSWorkspace.shared.open(parentDir)
                                }) {
                                    Label("Apri cartella", systemImage: "folder")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                                .help("Apri la cartella dei modelli")
                            }
                            Text(AsrModels.defaultCacheDirectory(for: .v3).deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: 12)
        }
        .padding()
    }
    
    private var transcriptionSettings: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Language Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lingua")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lingua della trascrizione")
                            .font(.subheadline)
                        
                        Picker("Lingua", selection: $viewModel.selectedLanguage) {
                            ForEach(viewModel.supportedLanguages, id: \.self) { code in
                                Text(LanguageUtil.languageNames[code] ?? code)
                                    .tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                // Output Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Opzioni di output")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Mostra i timestamp")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $viewModel.showTimestamps)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Ignora l'audio vuoto")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $viewModel.suppressBlankAudio)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aggiungi uno spazio dopo la frase")
                                    .font(.subheadline)
                                Text("Aggiunge uno spazio quando la trascrizione finisce con un segno di punteggiatura")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.addSpaceAfterSentence)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)

                // Reformulation
                VStack(alignment: .leading, spacing: 16) {
                    Text("Riformulazione")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Riformula la dettatura")
                                    .font(.subheadline)
                                Text("Rimuove le autocorrezioni del parlato con un modello locale. Il testo grezzo resta salvato.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.reformulationEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }

                        if viewModel.reformulationEnabled {
                            Text("Alla prima dettatura viene scaricato un modello di alcuni GB. Ogni dettatura richiede qualche secondo in più.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)

                // Clipboard & Paste
                VStack(alignment: .leading, spacing: 16) {
                    Text("Appunti e incolla")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copia negli appunti")
                                    .font(.subheadline)
                                Text("Mantiene la trascrizione negli appunti dopo la registrazione")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.autoCopyToClipboard)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Incolla automaticamente")
                                    .font(.subheadline)
                                Text("Incolla la trascrizione nell'app in primo piano")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.autoPasteTranscription)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)

                // Initial Prompt
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prompt iniziale")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $viewModel.initialPrompt)
                            .frame(height: 60)
                            .padding(6)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Testo facoltativo per guidare il modello: nomi propri, termini tecnici, anglicismi che usi spesso")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                // Transcriptions Directory
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cartella delle trascrizioni")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cartella:")
                                .font(.subheadline)
                            Spacer()
                            Button(action: {
                                NSWorkspace.shared.open(Recording.recordingsDirectory)
                            }) {
                                Label("Apri cartella", systemImage: "folder")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderless)
                            .help("Apri la cartella delle trascrizioni")
                        }
                        
                        Text(Recording.recordingsDirectory.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.textBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                RecordingStorageSettingsView()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(cornerRadius: 12)
            }
            .padding()
        }
    }
    
    private var advancedSettings: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Decoding Strategy
                VStack(alignment: .leading, spacing: 16) {
                    Text("Strategia di decodifica")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Usa la beam search")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $viewModel.useBeamSearch)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                                .help("La beam search può dare risultati migliori ma è più lenta")
                        }
                        
                        if viewModel.useBeamSearch {
                            HStack {
                                Text("Ampiezza del beam:")
                                    .font(.subheadline)
                                Spacer()
                                Stepper("\(viewModel.beamSize)", value: $viewModel.beamSize, in: 1...10)
                                    .help("Numero di beam usati nella beam search")
                                    .frame(width: 120)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                // Model Parameters
                VStack(alignment: .leading, spacing: 16) {
                    Text("Parametri del modello")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Temperatura:")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", viewModel.temperature))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $viewModel.temperature, in: 0.0...1.0, step: 0.1)
                                .help("Valori più alti rendono l'output più casuale")
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Soglia di assenza di parlato:")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", viewModel.noSpeechThreshold))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $viewModel.noSpeechThreshold, in: 0.0...1.0, step: 0.1)
                                .help("Soglia per distinguere il parlato dal silenzio")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                // Debug Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Opzioni di debug")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Modalità debug")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: $viewModel.debugMode)
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .labelsHidden()
                            .help("Attiva log e informazioni di debug aggiuntive")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
            }
            .padding()
        }
    }
    
    private enum TriggerMode: Hashable {
        case keyCombo
        case modifier
        case mouse
    }

    @ViewBuilder
    private func permissionWarning(message: String, isGranted: Bool, grantAction: @escaping () -> Void) -> some View {
        if permissionsManager.hasCompletedInitialCheck && !isGranted {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Button("Concedi il permesso") {
                    grantAction()
                }
                .glassButton()
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }

    private var triggerMode: TriggerMode {
        if viewModel.mouseButtonHotkey != .none { return .mouse }
        if viewModel.modifierOnlyHotkey != .none { return .modifier }
        return .keyCombo
    }
    
    private var shortcutSettings: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recording Trigger
                VStack(alignment: .leading, spacing: 16) {
                    Text("Attivazione della registrazione")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("", selection: Binding(
                            get: { triggerMode },
                            set: { newMode in
                                switch newMode {
                                case .keyCombo:
                                    viewModel.mouseButtonHotkey = .none
                                    viewModel.modifierOnlyHotkey = .none
                                case .modifier:
                                    viewModel.mouseButtonHotkey = .none
                                    if viewModel.modifierOnlyHotkey == .none {
                                        viewModel.modifierOnlyHotkey =
                                            ModifierKey(rawValue: AppPreferences.shared.lastModifierOnlyHotkey) ?? .leftCommand
                                    }
                                case .mouse:
                                    viewModel.modifierOnlyHotkey = .none
                                    if viewModel.mouseButtonHotkey == .none {
                                        viewModel.mouseButtonHotkey = .middle
                                    }
                                }
                            }
                        )) {
                            Text("Combinazione di tasti").tag(TriggerMode.keyCombo)
                            Text("Singolo tasto modificatore").tag(TriggerMode.modifier)
                            Text("Pulsante del mouse").tag(TriggerMode.mouse)
                        }
                        .pickerStyle(.segmented)

                        switch triggerMode {
                        case .modifier:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Tasto modificatore")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("", selection: $viewModel.modifierOnlyHotkey) {
                                        ForEach(ModifierKey.allCases.filter { $0 != .none }) { key in
                                            Text(key.displayName).tag(key)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 200)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(8)

                                Text(viewModel.doublePressToTrigger
                                     ? "Double-tap to toggle recording"
                                     : "One-tap to toggle recording")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Doppio tocco per attivare")
                                            .font(.subheadline)
                                        Text("Richiede due tocchi rapidi per evitare attivazioni accidentali")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $viewModel.doublePressToTrigger)
                                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(8)

                                permissionWarning(
                                    message: "⚠️ This mode requires Input Monitoring permission. macOS requires this to detect single modifier key presses globally. Only modifier key events (⌘, ⌥, ⇧, ⌃, Fn) are monitored — no regular keystrokes are captured.",
                                    isGranted: permissionsManager.isInputMonitoringPermissionGranted
                                ) {
                                    permissionsManager.requestInputMonitoringPermissionOrOpenSystemPreferences()
                                }
                            }
                        case .mouse:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Pulsante del mouse")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("", selection: $viewModel.mouseButtonHotkey) {
                                        ForEach(MouseButton.allCases.filter { $0 != .none }) { button in
                                            Text(button.displayName).tag(button)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 200)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(8)

                                Text("Un clic avvia e ferma la registrazione; se \"Tieni premuto per registrare\" è attivo, si registra finché lo tieni premuto. I pulsanti destro e sinistro sono riservati — scegli il centrale o un pulsante extra (del pollice).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                permissionWarning(
                                    message: "⚠️ This mode requires Accessibility permission so the button can be detected globally and used only as a recording trigger. Only the selected mouse button is intercepted — no other clicks or keystrokes are captured.",
                                    isGranted: permissionsManager.isAccessibilityPermissionGranted
                                ) {
                                    permissionsManager.requestAccessibilityPermissionOrOpenSystemPreferences()
                                }
                            }
                        case .keyCombo:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Scorciatoia")
                                        .font(.subheadline)
                                    Spacer()
                                    KeyboardShortcuts.Recorder("", name: .toggleRecord)
                                        .frame(width: 150)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.textBackgroundColor).opacity(0.5))
                                .cornerRadius(8)

                                if isRecordingNewShortcut {
                                    Text("Premi la nuova combinazione di tasti...")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
                
                // Recording Behavior
                VStack(alignment: .leading, spacing: 16) {
                    Text("Comportamento della registrazione")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tieni premuto per registrare")
                                    .font(.subheadline)
                                Text("Tieni premuta la scorciatoia per registrare, rilascia per fermare")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.holdToRecord)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Riproduci un suono all'avvio della registrazione")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $viewModel.playSoundOnRecordStart)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                                .help("Riproduce un suono di notifica quando parte la registrazione")
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Annulla senza conferma")
                                    .font(.subheadline)
                                Text("Salta la conferma con doppio Esc per le registrazioni oltre i 10 secondi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $viewModel.escCancelWithoutConfirmation)
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .labelsHidden()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)

                // Application
                VStack(alignment: .leading, spacing: 16) {
                    Text("Applicazione")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avvia nascosto nella barra dei menu")
                                .font(.subheadline)
                            Text("Si avvia senza aprire la finestra principale; usa l'icona nella barra dei menu per aprirla")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.startHiddenInMenuBar)
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .labelsHidden()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 12)
            }
            .padding()
        }
    }
}

struct SettingsFluidAudioModel: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    var isDownloaded: Bool
    let description: String
    let size: Int
    var downloadProgress: Double = 0.0

    var sizeString: String {
        formatModelSize(megabytes: size)
    }
}

struct SettingsFluidAudioModels {
    static let availableModels = [
        SettingsFluidAudioModel(
            name: "Parakeet v3",
            version: "v3",
            isDownloaded: false,
            description: "Multilingua, 25 lingue",
            size: 483
        ),
        SettingsFluidAudioModel(
            name: "Parakeet v2",
            version: "v2",
            isDownloaded: false,
            description: "Solo inglese, recall più alto",
            size: 464
        )
    ]
}

enum OnboardingModelType {
    case whisper(url: URL, size: Int)
    case parakeet(version: String)
}

struct OnboardingUnifiedModel: Identifiable {
    let id = UUID()
    let name: String
    var isDownloaded: Bool
    let description: String
    let type: OnboardingModelType
    var downloadProgress: Double = 0.0

    var huggingFacePageURL: URL? {
        switch type {
        case .whisper(let url, _):
            return makeHuggingFacePageURL(fromDownloadURL: url)
        case .parakeet(let version):
            let repo = version == "v2" ? "parakeet-tdt-0.6b-v2-coreml" : "parakeet-tdt-0.6b-v3-coreml"
            return URL(string: "https://huggingface.co/FluidInference/\(repo)")
        }
    }
}

struct OnboardingUnifiedModels {
    static let availableModels = [
        OnboardingUnifiedModel(
            name: "Whisper Turbo V3 large",
            isDownloaded: false,
            description: "Massima accuratezza, qualità migliore",
            type: .whisper(
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
                size: 1624
            )
        ),
        OnboardingUnifiedModel(
            name: "Parakeet v3",
            isDownloaded: false,
            description: "Veloce e accurato",
            type: .parakeet(version: "v3")
        ),
        OnboardingUnifiedModel(
            name: "Parakeet v2",
            isDownloaded: false,
            description: "Molto veloce, solo inglese, recall più alto",
            type: .parakeet(version: "v2")
        ),
        OnboardingUnifiedModel(
            name: "Whisper Turbo V3 medium (q8)",
            isDownloaded: false,
            description: "Equilibrio tra velocità e accuratezza",
            type: .whisper(
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin?download=true")!,
                size: 874
            )
        ),
        OnboardingUnifiedModel(
            name: "Whisper Turbo V3 small (q5)",
            isDownloaded: false,
            description: "Very fast processing",
            type: .whisper(
                url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true")!,
                size: 574
            )
        )
    ]
}

struct FluidAudioModelDownloadItemView: View {
    @Binding var model: SettingsFluidAudioModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isSelected: Bool {
        viewModel.fluidAudioModelVersion == model.version
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                Button("Annulla") {
                    viewModel.cancelDownload()
                }
                .glassButton()
                .controlSize(.small)
            } else if model.isDownloaded {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    Button(action: {
                        viewModel.fluidAudioModelVersion = model.version
                    }) {
                        Text("Seleziona")
                    }
                    .glassProminentButton()
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Text(model.sizeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task {
                            do {
                                try await viewModel.downloadFluidAudioModel(model)
                            } catch is CancellationError {
                                // Don't show error for manual cancellation
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }) {
                        Label("Scarica", systemImage: "arrow.down.circle")
                    }
                    .glassButton()
                    .controlSize(.small)
                    .disabled(viewModel.isDownloading)
                }
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8, tint: isSelected ? .accentColor : nil, interactive: true)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded && !isSelected {
                viewModel.fluidAudioModelVersion = model.version
            }
        }
        .alert("Errore di download", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

struct RecordingStorageSettingsView: View {
    @State private var autoDeleteEnabled = AppPreferences.shared.autoDeleteRecordingsEnabled
    @State private var retentionDays = AppPreferences.shared.autoDeleteRecordingsAfterDays
    @State private var diskUsage: Int64 = 0
    @State private var showConfirmation = false
    @State private var pendingDays = 0
    @State private var pendingCount = 0
    @State private var pendingOldestDate: Date?

    private let dayOptions = [1, 7, 14, 30, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Archivio della cronologia")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Registrazioni su disco:")
                        .font(.subheadline)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: diskUsage, countStyle: .file))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Elimina le registrazioni più vecchie di")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { retentionDays },
                        set: { newValue in
                            if autoDeleteEnabled {
                                requestAutoDelete(days: newValue)
                            } else {
                                retentionDays = newValue
                                AppPreferences.shared.autoDeleteRecordingsAfterDays = newValue
                            }
                        }
                    )) {
                        ForEach(dayOptions, id: \.self) { days in
                            Text(countLabel(days, singular: "giorno", plural: "giorni")).tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Elimina automaticamente le registrazioni vecchie")
                            .font(.subheadline)
                        Text("Rimuove dalla cronologia sia i file audio sia le relative trascrizioni")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { autoDeleteEnabled },
                        set: { newValue in
                            if newValue {
                                requestAutoDelete(days: retentionDays)
                            } else {
                                autoDeleteEnabled = false
                                AppPreferences.shared.autoDeleteRecordingsEnabled = false
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                    .labelsHidden()
                    .help("Elimina automaticamente le registrazioni e le trascrizioni più vecchie del numero di giorni scelto")
                }
            }
        }
        .onAppear {
            refreshDiskUsage()
        }
        .alert("Eliminare le registrazioni vecchie?", isPresented: $showConfirmation) {
            Button("Elimina", role: .destructive) {
                confirmAutoDelete()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Verranno eliminate \(countLabel(pendingCount, singular: "registrazione", plural: "registrazioni")) con \(pendingCount == 1 ? "la relativa trascrizione" : "le relative trascrizioni"), a partire dal \(formattedDate(pendingOldestDate)).")
        }
    }

    private func requestAutoDelete(days: Int) {
        Task { @MainActor in
            let result: (count: Int, oldestDate: Date?) = (try? await RecordingStore.shared.recordingsOlderThan(days: days)) ?? (count: 0, oldestDate: nil)
            if result.count > 0 {
                pendingDays = days
                pendingCount = result.count
                pendingOldestDate = result.oldestDate
                showConfirmation = true
            } else {
                applyAutoDelete(days: days)
            }
        }
    }

    private func confirmAutoDelete() {
        applyAutoDelete(days: pendingDays)
    }

    private func applyAutoDelete(days: Int) {
        retentionDays = days
        autoDeleteEnabled = true
        AppPreferences.shared.autoDeleteRecordingsAfterDays = days
        AppPreferences.shared.autoDeleteRecordingsEnabled = true
        Task { @MainActor in
            try? await RecordingStore.shared.deleteRecordings(olderThanDays: days)
            refreshDiskUsage()
        }
    }

    private func refreshDiskUsage() {
        Task.detached {
            let usage = RecordingStore.recordingsDiskUsage()
            await MainActor.run {
                diskUsage = usage
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct ModelDownloadItemView: View {
    @Binding var model: SettingsDownloadableModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isSelected: Bool {
        if let selectedURL = viewModel.selectedModelURL {
            let filename = model.filename
            return selectedURL.lastPathComponent == filename
        }
        return false
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let pageURL = model.huggingFacePageURL,
                       let owner = huggingFaceOwner(fromPageURL: pageURL) {
                        Link(owner, destination: pageURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Apri su Hugging Face")
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            if viewModel.isDownloading && viewModel.downloadingModelName == model.name {
                Button("Annulla") {
                    viewModel.cancelDownload()
                }
                .glassButton()
                .controlSize(.small)
            } else if model.isDownloaded {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.large)
                } else {
                    Button(action: {
                        let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(model.filename).path
                        viewModel.selectModel(URL(fileURLWithPath: modelPath))
                    }) {
                        Text("Seleziona")
                    }
                    .glassProminentButton()
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Text(model.sizeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task {
                            do {
                                try await viewModel.downloadModel(model)
                            } catch is CancellationError {
                                // Don't show error for manual cancellation
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }) {
                        Label("Scarica", systemImage: "arrow.down.circle")
                    }
                    .glassButton()
                    .controlSize(.small)
                    .disabled(viewModel.isDownloading)
                }
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8, tint: isSelected ? .accentColor : nil, interactive: true)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded && !isSelected {
                let modelPath = WhisperModelManager.shared.modelsDirectory.appendingPathComponent(model.filename).path
                viewModel.selectModel(URL(fileURLWithPath: modelPath))
            }
        }
        .alert("Errore di download", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

