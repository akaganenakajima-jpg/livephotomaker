import AVFoundation
import ExpoModulesCore
import ImageIO
import MobileCoreServices
import Photos
import UIKit
import UniformTypeIdentifiers

// MARK: - Errors
//
// Each raw value is the `code` field surfaced to JavaScript via `promise.reject`.
// The JS bridge in `src/services/NativeLivePhotoBridge.ts` maps each code into
// a typed `AppError` so the UI can render a localized message.
//
// NEVER remove or rename existing codes without also updating the JS mapping —
// doing so would silently collapse failures into the generic "exportFailed"
// bucket and make real diagnosis impossible.
enum LivePhotoExporterError: String, Error {
  case photoPermissionDenied    = "ERR_PHOTO_PERMISSION_DENIED"
  case invalidSourceUri         = "ERR_INVALID_SOURCE_URI"

  // Still (JPEG) pipeline
  case stillLoadFailed          = "ERR_STILL_LOAD_FAILED"
  case stillWriteFailed         = "ERR_STILL_WRITE_FAILED"
  case stillFinalizeFailed      = "ERR_STILL_FINALIZE_FAILED"

  // Movie (MOV) pipeline
  case movieTrackLoadFailed     = "ERR_MOVIE_TRACK_LOAD_FAILED"
  case movieVideoTrackMissing   = "ERR_MOVIE_VIDEO_TRACK_MISSING"
  case movieReaderCreateFailed  = "ERR_MOVIE_READER_CREATE_FAILED"
  case movieWriterCreateFailed  = "ERR_MOVIE_WRITER_CREATE_FAILED"
  case movieStartWritingFailed  = "ERR_MOVIE_START_WRITING_FAILED"
  case movieVideoAppendFailed   = "ERR_MOVIE_VIDEO_APPEND_FAILED"
  case movieFinishWritingFailed = "ERR_MOVIE_FINISH_WRITING_FAILED"

  // Photos save
  case assetCreationFailed      = "ERR_ASSET_CREATION_FAILED"
}

// MARK: - Dev-only log
//
// Compiled out of release builds so we never leak file URIs or UUIDs to
// end users. Visible in the Metro terminal (`npx expo start --dev-client`)
// when running a Development Build on a tethered iPhone — no Mac / Xcode /
// Console.app required. Critical failures are also surfaced to the JS side
// via `promise.reject` and mirrored into the in-app Debug screen by
// `src/services/NativeLivePhotoBridge.ts`, so Windows-only operators can
// read every diagnostic without touching Apple tooling.
@inline(__always)
private func devLog(_ message: @autoclosure () -> String) {
  #if DEBUG
  NSLog("[ExpoLivePhotoExporter] " + message())
  #endif
}

// MARK: - Module

public class ExpoLivePhotoExporterModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoLivePhotoExporter")

    // Capture params and promise as locals so Task{} closes over value-type
    // locals only — no `self` capture needed since all pipeline work is static.
    AsyncFunction("saveLivePhotoToLibrary") { (params: SaveParams, promise: Promise) in
      let movUri   = params.movUri
      let stillUri = params.stillUri
      Task {
        do {
          let result = try await LivePhotoExportPipeline.performSave(
            movUri: movUri,
            stillUri: stillUri
          )
          promise.resolve([
            "localIdentifier": result.localIdentifier,
            "contentIdentifier": result.contentIdentifier,
          ])
        } catch let error as LivePhotoExporterError {
          devLog("saveLivePhotoToLibrary rejected code=\(error.rawValue)")
          promise.reject(error.rawValue, String(describing: error))
        } catch {
          devLog("saveLivePhotoToLibrary rejected unknown: \(error.localizedDescription)")
          promise.reject("ERR_LIVE_PHOTO_EXPORT_FAILED", error.localizedDescription)
        }
      }
    }
  }

  // MARK: - Parameters

  struct SaveParams: Record {
    @Field var movUri: String = ""
    @Field var stillUri: String = ""
  }
}

// MARK: - Result

struct LivePhotoSaveResult {
  let localIdentifier: String
  let contentIdentifier: String
}

// MARK: - Pipeline (separate type — no `self` from Module ever needed)
//
// Keeping the pipeline in a standalone enum (namespace) ensures that Swift
// concurrency can never implicitly capture the Module instance.
enum LivePhotoExportPipeline {

  // MARK: Top-level entry point
  //
  // Live Photo が iOS 側で "Live" として扱われるための 4 条件:
  //
  //   (A) JPEG の MakerApple 辞書 key "17" (AssetIdentifier) に contentIdentifier
  //       を UTF-8 文字列で格納する
  //   (B) MOV の top-level QuickTime メタデータに
  //       mdta/com.apple.quicktime.content.identifier = 同 contentIdentifier を格納
  //   (C) MOV に独立した metadata track を追加し、
  //       mdta/com.apple.quicktime.still-image-time を 1 サンプル挿入
  //       (値は int8 で 0、timeRange は極短区間)
  //   (D) PHAssetCreationRequest.forAsset() に .photo と .pairedVideo の両リソースを
  //       同一 request で add する (別々の request に分けると単なる 2 資産になる)
  static func performSave(movUri: String, stillUri: String) async throws -> LivePhotoSaveResult {
    guard let movURL = fileURL(from: movUri),
          let stillURL = fileURL(from: stillUri) else {
      devLog("invalid source uris mov=\(movUri) still=\(stillUri)")
      throw LivePhotoExporterError.invalidSourceUri
    }

    devLog("performSave start mov=\(movURL.lastPathComponent) still=\(stillURL.lastPathComponent)")

    try await ensurePhotoPermission()

    let contentIdentifier = UUID().uuidString
    devLog("assigned contentIdentifier=\(contentIdentifier)")

    let taggedStillURL = try writeTaggedStill(source: stillURL, contentIdentifier: contentIdentifier)
    devLog("tagged still written -> \(taggedStillURL.lastPathComponent)")

    let taggedMovURL = try await writeTaggedMovie(source: movURL, contentIdentifier: contentIdentifier)
    devLog("tagged movie written -> \(taggedMovURL.lastPathComponent)")

    let localIdentifier = try await createLivePhotoAsset(photoURL: taggedStillURL, videoURL: taggedMovURL)
    devLog("asset created localIdentifier=\(localIdentifier)")

    return LivePhotoSaveResult(localIdentifier: localIdentifier, contentIdentifier: contentIdentifier)
  }

  // MARK: - Permission

  static func ensurePhotoPermission() async throws {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    switch status {
    case .authorized, .limited:
      return
    case .notDetermined:
      let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      if newStatus == .authorized || newStatus == .limited { return }
      throw LivePhotoExporterError.photoPermissionDenied
    default:
      throw LivePhotoExporterError.photoPermissionDenied
    }
  }

  // MARK: - URI helpers

  static func fileURL(from uri: String) -> URL? {
    if uri.isEmpty { return nil }
    if uri.hasPrefix("file://") {
      return URL(string: uri)
    }
    return URL(fileURLWithPath: uri)
  }

  static func temporaryURL(extension ext: String) -> URL {
    let name = "live_photo_\(UUID().uuidString).\(ext)"
    return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
  }

  // MARK: - Still (JPEG) tagging — 条件 (A)
  //
  // 実装手順:
  //   1. CGImageSourceCreateWithURL で既存 JPEG を開く
  //   2. 既存 properties をそのままコピー (向き / カラープロファイルを保持)
  //   3. kCGImagePropertyMakerAppleDictionary["17"] = contentIdentifier を上書き
  //   4. CGImageDestination に 1 画像で書き出して Finalize
  //
  // 注意:
  //   - key は数値ではなく文字列 "17". ここを間違えると Apple の内部マッチャーが
  //     無反応になる (Crash はしないがペアにならない)。
  //   - UTI は source のものをそのまま使う (HEIC 由来なら HEIC で書き出されるが、
  //     Photos の Live Photo 対応は両対応なので問題ない)。
  static func writeTaggedStill(source: URL, contentIdentifier: String) throws -> URL {
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let uti = CGImageSourceGetType(imageSource) else {
      devLog("CGImageSourceCreateWithURL failed for \(source.lastPathComponent)")
      throw LivePhotoExporterError.stillLoadFailed
    }

    let destURL = temporaryURL(extension: "jpg")
    guard let destination = CGImageDestinationCreateWithURL(destURL as CFURL, uti, 1, nil) else {
      devLog("CGImageDestinationCreateWithURL failed")
      throw LivePhotoExporterError.stillWriteFailed
    }

    let existingProps = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] ?? [:]
    var mutableProps = existingProps

    var makerApple = (mutableProps[kCGImagePropertyMakerAppleDictionary] as? [String: Any]) ?? [:]
    makerApple["17"] = contentIdentifier
    mutableProps[kCGImagePropertyMakerAppleDictionary] = makerApple

    CGImageDestinationAddImageFromSource(destination, imageSource, 0, mutableProps as CFDictionary)

    if !CGImageDestinationFinalize(destination) {
      devLog("CGImageDestinationFinalize failed")
      throw LivePhotoExporterError.stillFinalizeFailed
    }
    return destURL
  }

  // MARK: - Movie (MOV) tagging — 条件 (B)(C)
  //
  // passthrough reader/writer を組んで、元のビデオ/音声トラックを再圧縮せずに
  // コピーしつつ以下を差し込む:
  //
  //   - top-level: writer.metadata に mdta/content.identifier (条件 B)
  //   - metadata track: mdta/still-image-time を 1 サンプル (条件 C)
  //
  // 既存 MOV を直接 mutate するのではなく、一時ディレクトリへ新しいファイルを
  // 書き出し、そのパスを返す。
  static func writeTaggedMovie(source: URL, contentIdentifier: String) async throws -> URL {
    let asset = AVURLAsset(url: source)
    let destURL = temporaryURL(extension: "mov")

    guard let reader = try? AVAssetReader(asset: asset) else {
      devLog("AVAssetReader init failed")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }
    guard let writer = try? AVAssetWriter(outputURL: destURL, fileType: .mov) else {
      devLog("AVAssetWriter init failed")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }

    // (B) top-level content identifier
    writer.metadata = [makeContentIdentifierItem(contentIdentifier)]

    // --- video track (passthrough) ---
    let videoTracks: [AVAssetTrack]
    do {
      videoTracks = try await asset.loadTracks(withMediaType: .video)
    } catch {
      devLog("asset.loadTracks(video) failed: \(error.localizedDescription)")
      throw LivePhotoExporterError.movieTrackLoadFailed
    }
    guard let sourceVideoTrack = videoTracks.first else {
      devLog("no video track in source MOV")
      throw LivePhotoExporterError.movieVideoTrackMissing
    }

    let videoOutput = AVAssetReaderTrackOutput(track: sourceVideoTrack, outputSettings: nil)
    videoOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(videoOutput) else {
      devLog("reader cannot add video output")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }
    reader.add(videoOutput)

    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    videoInput.expectsMediaDataInRealTime = false
    if let transform = try? await sourceVideoTrack.load(.preferredTransform) {
      videoInput.transform = transform
    }
    guard writer.canAdd(videoInput) else {
      devLog("writer cannot add video input")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }
    writer.add(videoInput)

    // --- audio track (optional passthrough) ---
    var audioInput: AVAssetWriterInput? = nil
    var audioOutput: AVAssetReaderTrackOutput? = nil
    if let sourceAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
      let out = AVAssetReaderTrackOutput(track: sourceAudioTrack, outputSettings: nil)
      out.alwaysCopiesSampleData = false
      let inp = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
      inp.expectsMediaDataInRealTime = false
      if reader.canAdd(out) && writer.canAdd(inp) {
        reader.add(out)
        writer.add(inp)
        audioInput = inp
        audioOutput = out
      } else {
        devLog("audio passthrough skipped (canAdd returned false)")
      }
    }

    // (C) metadata track: still-image-time
    let metadataAdaptor = makeStillImageTimeMetadataAdaptor()
    guard writer.canAdd(metadataAdaptor.assetWriterInput) else {
      devLog("writer cannot add metadata input (still-image-time)")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }
    writer.add(metadataAdaptor.assetWriterInput)

    guard writer.startWriting() else {
      devLog("writer.startWriting failed: \(writer.error?.localizedDescription ?? "nil")")
      throw LivePhotoExporterError.movieStartWritingFailed
    }
    reader.startReading()
    writer.startSession(atSourceTime: .zero)

    // (C) still-image-time を 1 サンプルだけ差し込む。Apple のサンプル実装に倣い
    // 値 0 / duration 1/30 秒の短い区間。key photo がどの時刻に相当するかを示す。
    let stillItem = makeStillImageTimeMetadataItem()
    let stillGroup = AVTimedMetadataGroup(
      items: [stillItem],
      timeRange: CMTimeRangeMake(start: .zero, duration: CMTimeMake(value: 1, timescale: 30))
    )
    metadataAdaptor.append(stillGroup)
    metadataAdaptor.assetWriterInput.markAsFinished()
    devLog("still-image-time metadata appended")

    try await pump(input: videoInput, from: videoOutput, label: "video")
    videoInput.markAsFinished()

    if let aIn = audioInput, let aOut = audioOutput {
      try await pump(input: aIn, from: aOut, label: "audio")
      aIn.markAsFinished()
    }

    await writer.finishWriting()
    if writer.status != .completed {
      devLog("writer finish status=\(writer.status.rawValue) error=\(writer.error?.localizedDescription ?? "nil")")
      throw LivePhotoExporterError.movieFinishWritingFailed
    }
    return destURL
  }

  // MARK: - pump
  //
  // Drains sample buffers from a reader output into a writer input.
  //
  // `requestMediaDataWhenReady` may invoke its block multiple times until
  // `markAsFinished()` is called. We use a completion handler bridge instead
  // of `withCheckedContinuation` to avoid the @Sendable capture constraints
  // that withCheckedContinuation imposes in strict concurrency mode.
  //
  // The DispatchSemaphore approach ensures we wait for the pump to complete
  // without bridging non-Sendable AVFoundation types across @Sendable closures.
  static func pump(
    input: AVAssetWriterInput,
    from output: AVAssetReaderTrackOutput,
    label: String
  ) async throws {
    // Bridge the callback-based API to async/await using a semaphore.
    // Both input and output are used only on the dedicated DispatchQueue —
    // no cross-thread sharing occurs.
    let semaphore = DispatchSemaphore(value: 0)
    let queue = DispatchQueue(label: "live-photo-exporter.pump.\(label).\(UUID().uuidString)")
    input.requestMediaDataWhenReady(on: queue) {
      while input.isReadyForMoreMediaData {
        if let buffer = output.copyNextSampleBuffer() {
          if !input.append(buffer) {
            devLog("pump(\(label)) append failed")
            semaphore.signal()
            return
          }
        } else {
          semaphore.signal()
          return
        }
      }
    }
    // Block the current thread (inside a detached Task / cooperative pool
    // thread) until the pump completes. The pump queue and this thread are
    // different, so there is no deadlock risk.
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.global().async {
        semaphore.wait()
        continuation.resume()
      }
    }
  }

  // MARK: - Metadata factories

  private static let kKeyContentIdentifier = "com.apple.quicktime.content.identifier"
  private static let kKeyStillImageTime    = "com.apple.quicktime.still-image-time"
  private static let kKeyspaceQuickTime    = "mdta"

  static func makeContentIdentifierItem(_ value: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.keySpace = AVMetadataKeySpace(rawValue: kKeyspaceQuickTime)
    item.key = kKeyContentIdentifier as NSString
    item.value = value as NSString
    item.dataType = "com.apple.metadata.datatype.UTF-8"
    return item
  }

  static func makeStillImageTimeMetadataItem() -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.keySpace = AVMetadataKeySpace(rawValue: kKeyspaceQuickTime)
    item.key = kKeyStillImageTime as NSString
    item.value = 0 as NSNumber
    item.dataType = "com.apple.metadata.datatype.int8"
    return item
  }

  static func makeStillImageTimeMetadataAdaptor() -> AVAssetWriterInputMetadataAdaptor {
    let spec: [String: Any] = [
      kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
        "\(kKeyspaceQuickTime)/\(kKeyStillImageTime)",
      kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
        "com.apple.metadata.datatype.int8"
    ]
    var desc: CMFormatDescription?
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
      allocator: kCFAllocatorDefault,
      metadataType: kCMMetadataFormatType_Boxed,
      metadataSpecifications: [spec] as CFArray,
      formatDescriptionOut: &desc
    )
    let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: desc)
    return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
  }

  // MARK: - Photos library save — 条件 (D)
  //
  // 必ず同一 PHAssetCreationRequest に .photo と .pairedVideo を add する。
  // 別々の request にすると Photos は 2 つの独立 asset として扱い、Live Photo に
  // ならない。
  //
  // IdentifierBox (@unchecked Sendable) carries the localIdentifier out of the
  // @Sendable performChanges block without using a bare `var`.
  static func createLivePhotoAsset(photoURL: URL, videoURL: URL) async throws -> String {
    let box = IdentifierBox()
    try await PHPhotoLibrary.shared().performChanges {
      let request = PHAssetCreationRequest.forAsset()

      let photoOptions = PHAssetResourceCreationOptions()
      photoOptions.shouldMoveFile = true
      request.addResource(with: .photo, fileURL: photoURL, options: photoOptions)

      let videoOptions = PHAssetResourceCreationOptions()
      videoOptions.shouldMoveFile = true
      request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)

      if let placeholder = request.placeholderForCreatedAsset {
        box.value = placeholder.localIdentifier
      }
    }
    guard !box.value.isEmpty else {
      throw LivePhotoExporterError.assetCreationFailed
    }
    return box.value
  }
}

// MARK: - IdentifierBox
//
// A trivially @unchecked Sendable box used to carry the localIdentifier out of the
// PHPhotoLibrary.performChanges `@Sendable` change block without capturing a bare
// `var` (which Swift 5.10 rejects as a potential data race). The caller reads
// `value` only after `await performChanges` returns, guaranteeing serial access.
private final class IdentifierBox: @unchecked Sendable {
  var value: String = ""
}
