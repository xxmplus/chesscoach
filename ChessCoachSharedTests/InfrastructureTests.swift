import XCTest
import SwiftUI
@testable import ChessCoachShared

final class InfrastructureTests: XCTestCase {

    func testModelConfigDeepSeekMetadataAndURLs_areStable() {
        let config = ModelConfig.deepseekR1_Qwen_1_5B

        XCTAssertEqual(config.repoId, "unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF")
        XCTAssertEqual(config.fileName, "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf")
        XCTAssertEqual(config.displayName, "DeepSeek-R1 Distill (1.5B)")
        XCTAssertEqual(config.bundleSizeMB, 1065)
        XCTAssertEqual(config.estimatedTokensPerSecond, 22)
        XCTAssertEqual(config.chatTemplate, "chatml")
        XCTAssertEqual(
            config.downloadURL,
            "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
        )
        XCTAssertEqual(
            config.huggingFaceRepo,
            "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/tree/main"
        )
    }

    func testAllDeviceTiersRecommendSmallBundledModel() {
        let expected = ModelConfig.deepseekR1_Qwen_1_5B
        XCTAssertEqual(DeviceTier.iPhone13.recommendedModel, expected)
        XCTAssertEqual(DeviceTier.iPhone14.recommendedModel, expected)
        XCTAssertEqual(DeviceTier.iPhone15ProOrLater.recommendedModel, expected)
        XCTAssertEqual(DeviceTier.other.recommendedModel, expected)
    }

    func testDeviceCapabilityDetectorReturnsUsableTier() {
        // On simulator this should be iPhone15ProOrLater; on device the exact tier depends on hardware.
        XCTAssertEqual(DeviceCapabilityDetector.detectTier().recommendedModel, .deepseekR1_Qwen_1_5B)
    }

    func testModelDownloadServiceReportsMissingModelAsNotStarted() async throws {
        let uniqueConfig = ModelConfig(
            repoId: "example/not-real",
            fileName: "unit-test-missing-\(UUID().uuidString).gguf",
            displayName: "Missing Unit Test Model",
            bundleSizeMB: 1,
            estimatedTokensPerSecond: 1,
            chatTemplate: "chatml"
        )
        let service = ModelDownloadService()

        let isDownloaded = await service.isModelDownloaded(uniqueConfig)
        let state = await service.downloadState(for: uniqueConfig)

        XCTAssertFalse(service.isBundled(uniqueConfig))
        XCTAssertFalse(isDownloaded)
        XCTAssertEqual(state, .notStarted)
        XCTAssertTrue(service.modelPath(for: uniqueConfig).path.hasSuffix("Models/\(uniqueConfig.fileName)"))
    }

    func testModelDownloadServiceDeleteModelRemovesDownloadedFile() async throws {
        let uniqueConfig = ModelConfig(
            repoId: "example/not-real",
            fileName: "unit-test-delete-\(UUID().uuidString).gguf",
            displayName: "Delete Unit Test Model",
            bundleSizeMB: 1,
            estimatedTokensPerSecond: 1,
            chatTemplate: "chatml"
        )
        let service = ModelDownloadService()
        let path = service.modelPath(for: uniqueConfig)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0, 1, 2, 3]).write(to: path)
        let existsBeforeDelete = await service.isModelDownloaded(uniqueConfig)
        XCTAssertTrue(existsBeforeDelete)

        try await service.deleteModel(uniqueConfig)

        let existsAfterDelete = await service.isModelDownloaded(uniqueConfig)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
        XCTAssertFalse(existsAfterDelete)
    }

    func testModelDownloadServiceSizeSumsFilesInModelsDirectory() async throws {
        let service = ModelDownloadService()
        let directory = service.modelsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let first = directory.appendingPathComponent("size-test-\(UUID().uuidString)-1.bin")
        let second = directory.appendingPathComponent("size-test-\(UUID().uuidString)-2.bin")
        try Data(repeating: 1, count: 7).write(to: first)
        try Data(repeating: 2, count: 11).write(to: second)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let total = await service.downloadedModelsSize()

        XCTAssertGreaterThanOrEqual(total, 18)
    }

    func testDownloadStateEquatableAndIsDownloaded() {
        XCTAssertTrue(ModelDownloadService.DownloadState.downloaded.isDownloaded)
        XCTAssertFalse(ModelDownloadService.DownloadState.notStarted.isDownloaded)
        XCTAssertFalse(ModelDownloadService.DownloadState.downloading(progress: 0.5).isDownloaded)
        XCTAssertFalse(ModelDownloadService.DownloadState.failed("nope").isDownloaded)
        XCTAssertEqual(ModelDownloadService.DownloadState.downloading(progress: 0.25), .downloading(progress: 0.25))
        XCTAssertEqual(ModelDownloadService.DownloadState.failed("x"), .failed("x"))
    }

    func testDownloadErrorDescriptions_areUserReadable() {
        XCTAssertEqual(ModelDownloadService.DownloadError.invalidURL.errorDescription, "Invalid download URL")
        XCTAssertEqual(ModelDownloadService.DownloadError.networkError(404).errorDescription, "Network error: 404")
        XCTAssertEqual(ModelDownloadService.DownloadError.writeError("disk").errorDescription, "Write error: disk")
        XCTAssertEqual(ModelDownloadService.DownloadError.insufficientStorage.errorDescription, "Not enough storage space")
        XCTAssertEqual(ModelDownloadService.DownloadError.bundleModelNotFound.errorDescription, "Bundled model not found in app bundle")
    }

    func testModelStorageInfoConvertsBytesToMegabytes() {
        let info = ModelStorageInfo(
            config: .deepseekR1_Qwen_1_5B,
            downloaded: true,
            bundled: false,
            fileSizeBytes: 3 * 1024 * 1024 + 512,
            downloadState: .downloaded
        )
        XCTAssertEqual(info.fileSizeMB, 3)

        let unknownSize = ModelStorageInfo(
            config: .deepseekR1_Qwen_1_5B,
            downloaded: false,
            bundled: false,
            fileSizeBytes: nil,
            downloadState: .notStarted
        )
        XCTAssertNil(unknownSize.fileSizeMB)
    }

    func testDatabaseManagerPersistsLessonPuzzleAndRatingBehavior() {
        let db = DatabaseManager.shared
        let lessonId = "unit-lesson-\(UUID().uuidString)"
        let puzzleId = "unit-puzzle-\(UUID().uuidString)"
        let rating = 1234 + Int.random(in: 0..<100)

        XCTAssertNil(db.getLessonProgress(id: lessonId))
        db.saveLessonProgress(id: lessonId, phase: "opening", title: "Unit Lesson", difficulty: 900, stars: 2, status: "in_progress")
        XCTAssertEqual(db.getLessonProgress(id: lessonId)?.stars, 2)
        XCTAssertEqual(db.getLessonProgress(id: lessonId)?.status, "in_progress")

        db.saveLessonProgress(id: lessonId, phase: "opening", title: "Unit Lesson", difficulty: 900, stars: 3, status: "completed")
        XCTAssertEqual(db.getAllLessonProgress()[lessonId]?.stars, 3)
        XCTAssertEqual(db.getAllLessonProgress()[lessonId]?.status, "completed")

        XCTAssertNil(db.getPuzzleStats(id: puzzleId))
        db.savePuzzleResult(id: puzzleId, rating: 1100, solved: true, hintsUsed: 1)
        let stats = db.getPuzzleStats(id: puzzleId)
        XCTAssertEqual(stats?.solved, true)
        XCTAssertEqual(stats?.attempts, 1)
        XCTAssertEqual(stats?.hintsUsed, 1)

        db.logSession(type: "unit", result: "ok")
        db.recordRating(rating)
        XCTAssertEqual(db.currentEstimatedRating(), rating)
        XCTAssertTrue(db.getRatingHistory().contains { $0.rating == rating })
    }

    func testChessThemeMidnightStudyHasExpectedNameAndColors() {
        let theme = ChessTheme.midnightStudy
        XCTAssertEqual(theme.name, "Midnight Study")
        XCTAssertNotNil(theme.background)
        XCTAssertNotNil(theme.surface)
        XCTAssertNotNil(theme.surfaceLight)
        XCTAssertNotNil(theme.primary)
        XCTAssertNotNil(theme.secondary)
        XCTAssertNotNil(theme.accent)
        XCTAssertNotNil(theme.textPrimary)
        XCTAssertNotNil(theme.textMuted)
        XCTAssertNotNil(theme.whiteSquare)
        XCTAssertNotNil(theme.blackSquare)
    }

    func testColorHexInitializerHandlesSupportedFormats() {
        XCTAssertNotNil(Color(hex: "#abc"))
        XCTAssertNotNil(Color(hex: "AABBCC"))
        XCTAssertNotNil(Color(hex: "80AABBCC"))
        XCTAssertNotNil(Color(hex: "not-hex"))
    }
}
