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
      let startSeconds = params.startSeconds
      let endSeconds   = params.endSeconds
      Task {
        do {
          let result = try await LivePhotoExportPipeline.performSave(
            movUri: movUri,
            stillUri: stillUri,
            startSeconds: startSeconds,
            endSeconds: endSeconds
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
    /// Trim start in seconds (default 0).
    @Field var startSeconds: Double = 0.0
    /// Trim end in seconds. Clamped to asset duration on the native side.
    @Field var endSeconds: Double = 3.0
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
  static func performSave(
    movUri: String,
    stillUri: String,
    startSeconds: Double = 0.0,
    endSeconds: Double = 3.0
  ) async throws -> LivePhotoSaveResult {
    guard let movURL = fileURL(from: movUri),
          let stillURL = fileURL(from: stillUri) else {
      devLog("invalid source uris mov=\(movUri) still=\(stillUri)")
      throw LivePhotoExporterError.invalidSourceUri
    }

    devLog("performSave start mov=\(movURL.lastPathComponent) still=\(stillURL.lastPathComponent) trim=[\(startSeconds), \(endSeconds)]s")

    try await ensurePhotoPermission()

    let contentIdentifier = UUID().uuidString
    devLog("assigned contentIdentifier=\(contentIdentifier)")

    let taggedStillURL = try writeTaggedStill(source: stillURL, contentIdentifier: contentIdentifier)
    devLog("tagged still written -> \(taggedStillURL.lastPathComponent)")

    let taggedMovURL = try await writeTaggedMovie(
      source: movURL,
      contentIdentifier: contentIdentifier,
      startSeconds: startSeconds,
      endSeconds: endSeconds
    )
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
  static func writeTaggedMovie(
    source: URL,
    contentIdentifier: String,
    startSeconds: Double = 0.0,
    endSeconds: Double = 3.0
  ) async throws -> URL {
    let asset = AVURLAsset(url: source)
    let destURL = temporaryURL(extension: "mov")

    guard let reader = try? AVAssetReader(asset: asset) else {
      devLog("AVAssetReader init failed")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }

    // PTS-based trimming: read from the beginning of the file (no seek) and
    // stop inside pump() once elapsed PTS >= clipDuration. This avoids the
    // 20+ second block that reader.timeRange causes when seeking in a compressed
    // HEVC stream using passthrough (outputSettings: nil).
    let clipDuration = max(0.1, endSeconds - startSeconds)
    devLog("clip target: \(clipDuration)s (enforced via PTS in pump — no reader.timeRange seek)")

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
    guard reader.startReading() else {
      devLog("reader.startReading failed: \(reader.error?.localizedDescription ?? "nil") status=\(reader.status.rawValue)")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }
    devLog("reader.startReading ok, beginning session")
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

    devLog("pump video start")
    try await pump(input: videoInput, from: videoOutput, reader: reader, writer: writer, clipDuration: clipDuration, label: "video")
    devLog("pump video done")
    videoInput.markAsFinished()

    if let aIn = audioInput, let aOut = audioOutput {
      devLog("pump audio start")
      try await pump(input: aIn, from: aOut, reader: reader, writer: writer, clipDuration: clipDuration, label: "audio")
      devLog("pump audio done")
      aIn.markAsFinished()
    }

    devLog("writer.finishWriting start")
    await writer.finishWriting()
    devLog("writer.finishWriting done status=\(writer.status.rawValue)")
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
  // Design notes:
  //   - `requestMediaDataWhenReady` calls the block whenever the writer input
  //     is ready to accept more data. The block runs until it signals `semaphore`
  //     (end-of-stream, clip duration reached, append failure, or writer failure).
  //   - clipDuration enforces the trim in PTS-space: the first valid PTS is
  //     recorded as `firstPTS`, and the block stops once
  //     (currentPTS - firstPTS) >= clipDuration. This avoids reader.timeRange,
  //     which causes copyNextSampleBuffer() to block for 20+ seconds while
  //     seeking in a compressed HEVC passthrough stream.
  //   - We use DispatchSemaphore + semaphore.wait(timeout:) so a broken writer
  //     (isReadyForMoreMediaData stuck false) cannot hang indefinitely.
  //   - On timeout the error message includes reader/writer status codes visible
  //     in the in-app Debug screen (NativeLivePhotoBridge.ts → lastError.message).
  private static let pumpTimeoutSeconds: Double = 20

  static func pump(
    input: AVAssetWriterInput,
    from output: AVAssetReaderTrackOutput,
    reader: AVAssetReader,
    writer: AVAssetWriter,
    clipDuration: Double,
    label: String
  ) async throws {
    let semaphore = DispatchSemaphore(value: 0)
    let pumpQueue = DispatchQueue(label: "lp-pump-\(label)-\(UUID().uuidString)", qos: .userInitiated)

    var firstPTS: Double? = nil

    input.requestMediaDataWhenReady(on: pumpQueue) {
      while input.isReadyForMoreMediaData {
        // Bail out immediately if the writer has entered a terminal state.
        if writer.status == .failed || writer.status == .cancelled {
          devLog("pump(\(label)) writer terminal status=\(writer.status.rawValue) err=\(writer.error?.localizedDescription ?? "nil")")
          semaphore.signal()
          return
        }
        guard let buffer = output.copyNextSampleBuffer() else {
          devLog("pump(\(label)) end-of-stream reader.status=\(reader.status.rawValue)")
          semaphore.signal()
          return
        }
        // PTS-based clip boundary check (replaces reader.timeRange seek).
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        if pts.isValid {
          if firstPTS == nil { firstPTS = pts.seconds }
          let elapsed = pts.seconds - (firstPTS ?? pts.seconds)
          if elapsed >= clipDuration {
            devLog("pump(\(label)) clipDuration reached elapsed=\(String(format: "%.3f", elapsed))s >= \(clipDuration)s")
            semaphore.signal()
            return
          }
        }
        if !input.append(buffer) {
          devLog("pump(\(label)) append failed")
          semaphore.signal()
          return
        }
      }
      // isReadyForMoreMediaData became false → requestMediaDataWhenReady will
      // call this block again when the writer is ready for more data.
    }

    // Wait with a hard timeout so a permanently-stuck writer cannot hang
    // the entire export pipeline forever.
    let timedOut = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      DispatchQueue.global().async {
        let result = semaphore.wait(timeout: .now() + pumpTimeoutSeconds)
        cont.resume(returning: result == .timedOut)
      }
    }

    if timedOut {
      let rs = reader.status.rawValue
      let ws = writer.status.rawValue
      let we = writer.error?.localizedDescription ?? "nil"
      // Embed rs/ws into the message so it surfaces in the in-app Debug screen
      // (lastError.message) — the only Swift diagnostic visible on Windows.
      let msg = "pump_\(label)_timeout rs=\(rs) ws=\(ws) we=\(we)"
      devLog("PUMP TIMEOUT: \(msg)")
      throw NSError(
        domain: "com.gen.videotolivephoto",
        code: Int(rs * 10 + ws),
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }

    // Post-pump: surface any silent reader/writer failures that occurred
    // after the semaphore was signalled (e.g. writer failed on the last write).
    if reader.status == .failed {
      let msg = "pump_\(label)_reader_failed: \(reader.error?.localizedDescription ?? "nil")"
      devLog(msg)
      throw NSError(domain: "com.gen.videotolivephoto", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: msg])
    }
    if writer.status == .failed {
      let msg = "pump_\(label)_writer_failed: \(writer.error?.localizedDescription ?? "nil")"
      devLog(msg)
      throw NSError(domain: "com.gen.videotolivephoto", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: msg])
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
