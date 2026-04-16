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

  // Parses a URI string into a filesystem URL.
  //
  // Handles three input shapes:
  //   1. `file:///path/to/file.mov`              → URL(fileURLWithPath:)
  //   2. `/absolute/path/to/file.mov`            → URL(fileURLWithPath:)
  //   3. `file:///path/to/file.mp4#test`         → fragment stripped, then (1)
  //
  // Case 3 happens when test-mode / dev fixtures pass URIs with an anchor to
  // tag the origin. AVFoundation rejects URLs with fragments, so we must strip
  // them before handing to AVURLAsset.
  static func fileURL(from uri: String) -> URL? {
    if uri.isEmpty { return nil }

    // Strip fragment (#...) and query (?...) — AVFoundation rejects them.
    var clean = uri
    if let hashIdx = clean.firstIndex(of: "#") {
      clean = String(clean[..<hashIdx])
    }
    if let queryIdx = clean.firstIndex(of: "?") {
      clean = String(clean[..<queryIdx])
    }
    if clean.isEmpty { return nil }

    if clean.hasPrefix("file://") {
      // Parse through URL(string:) so percent-encoded path segments decode.
      if let url = URL(string: clean) {
        return URL(fileURLWithPath: url.path)
      }
      return nil
    }
    return URL(fileURLWithPath: clean)
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
  // Re-encoding pipeline (H.264). Abandoned passthrough (`outputSettings: nil`)
  // because it required a `sourceFormatHint` that we were not providing — the
  // writer input ended up stuck in "not ready" state and the pump callback was
  // never invoked, producing rs=1 ws=1 we=nil timeouts on Windows dev builds.
  //
  // Pipeline:
  //   reader: HEVC/H.264 source → decoded BGRA pixel buffers
  //   writer: BGRA → H.264 encoded MOV (6 Mbps) + Live Photo metadata
  //
  // Why this is safe:
  //   - Explicit AVVideoCompressionProperties → writer always knows format
  //     up-front, so `isReadyForMoreMediaData` flips true immediately.
  //   - No seek (no reader.timeRange). Trim is enforced by PTS in the pump.
  //   - Audio is dropped — Live Photos are silent on Apple hardware when
  //     rendered as wallpapers, and dropping audio removes a whole class of
  //     failure modes (audio codec mismatch, audio pump starvation).
  //   - DispatchSemaphore is gone. The pump is a
  //     `withCheckedThrowingContinuation` that resumes exactly once from the
  //     `requestMediaDataWhenReady` callback.
  static func writeTaggedMovie(
    source: URL,
    contentIdentifier: String,
    startSeconds: Double = 0.0,
    endSeconds: Double = 3.0
  ) async throws -> URL {
    let asset = AVURLAsset(url: source)
    let destURL = temporaryURL(extension: "mov")

    // ---- Load video track + properties ----
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

    let naturalSize = (try? await sourceVideoTrack.load(.naturalSize)) ?? CGSize(width: 1080, height: 1920)
    let transform   = (try? await sourceVideoTrack.load(.preferredTransform)) ?? .identity
    devLog("source video naturalSize=\(naturalSize) transform=\(transform)")

    // ---- Reader (HEVC/H.264 → BGRA) ----
    guard let reader = try? AVAssetReader(asset: asset) else {
      devLog("AVAssetReader init failed")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }

    let clipDuration = max(0.1, endSeconds - startSeconds)
    devLog("clip target: \(clipDuration)s (PTS-based trim, re-encode to H.264)")

    // Decode settings: BGRA (widely supported by VideoToolbox encoder).
    let readerVideoSettings: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ]
    let videoOutput = AVAssetReaderTrackOutput(track: sourceVideoTrack, outputSettings: readerVideoSettings)
    videoOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(videoOutput) else {
      devLog("reader cannot add video output")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }
    reader.add(videoOutput)

    // ---- Writer ----
    guard let writer = try? AVAssetWriter(outputURL: destURL, fileType: .mov) else {
      devLog("AVAssetWriter init failed")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }
    writer.shouldOptimizeForNetworkUse = true
    // (B) top-level content identifier
    writer.metadata = [makeContentIdentifierItem(contentIdentifier)]

    // Encode settings: H.264 @ 6 Mbps, same resolution as source.
    let writerVideoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(abs(naturalSize.width)),
      AVVideoHeightKey: Int(abs(naturalSize.height)),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 30,
      ] as [String: Any],
    ]
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
    videoInput.expectsMediaDataInRealTime = false
    videoInput.transform = transform
    guard writer.canAdd(videoInput) else {
      devLog("writer cannot add video input")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }
    writer.add(videoInput)

    // (C) metadata track: still-image-time
    let metadataAdaptor = makeStillImageTimeMetadataAdaptor()
    guard writer.canAdd(metadataAdaptor.assetWriterInput) else {
      devLog("writer cannot add metadata input (still-image-time)")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }
    writer.add(metadataAdaptor.assetWriterInput)

    // ---- Start ----
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

    // (C) still-image-time: 1 sample, value 0, duration 1/30s. Must be
    // appended before the metadata input is marked finished.
    let stillItem = makeStillImageTimeMetadataItem()
    let stillGroup = AVTimedMetadataGroup(
      items: [stillItem],
      timeRange: CMTimeRangeMake(start: .zero, duration: CMTimeMake(value: 1, timescale: 30))
    )
    metadataAdaptor.append(stillGroup)
    devLog("still-image-time metadata appended")

    // ---- Video pump ----
    devLog("pump video start (re-encode H.264)")
    try await pump(
      input: videoInput,
      from: videoOutput,
      reader: reader,
      writer: writer,
      clipDuration: clipDuration,
      label: "video"
    )
    devLog("pump video done")
    videoInput.markAsFinished()
    metadataAdaptor.assetWriterInput.markAsFinished()

    // ---- Finish ----
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
  // Continuation-based drain of sample buffers. The block registered via
  // `requestMediaDataWhenReady` resumes the continuation exactly once
  // (success, failure, or timeout). No DispatchSemaphore — the previous
  // implementation blocked a global dispatch worker for 20s and was
  // suspected of contributing to thread starvation.
  //
  // Stops on:
  //   - end-of-stream (copyNextSampleBuffer returns nil)
  //   - elapsed PTS >= clipDuration (PTS-based trim)
  //   - writer append failure
  //   - writer terminal state (failed / cancelled)
  //   - 20 second safety timeout
  private static let pumpTimeoutSeconds: Double = 20

  static func pump(
    input: AVAssetWriterInput,
    from output: AVAssetReaderTrackOutput,
    reader: AVAssetReader,
    writer: AVAssetWriter,
    clipDuration: Double,
    label: String
  ) async throws {
    let pumpQueue = DispatchQueue(label: "lp-pump-\(label)-\(UUID().uuidString)", qos: .userInitiated)

    // Box for mutable state shared between continuation and GCD callback.
    // @unchecked Sendable is safe because all access happens on pumpQueue.
    final class State: @unchecked Sendable {
      var firstPTS: Double? = nil
      var sampleCount: Int = 0
      var resumed: Bool = false
    }
    let state = State()

    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      let resumeOnce: (Result<Void, Error>) -> Void = { result in
        pumpQueue.async {
          guard !state.resumed else { return }
          state.resumed = true
          switch result {
          case .success:
            cont.resume(returning: ())
          case .failure(let error):
            cont.resume(throwing: error)
          }
        }
      }

      // Hard safety timeout so we never hang forever.
      pumpQueue.asyncAfter(deadline: .now() + pumpTimeoutSeconds) {
        let rs = reader.status.rawValue
        let ws = writer.status.rawValue
        let we = writer.error?.localizedDescription ?? "nil"
        let msg = "pump_\(label)_timeout rs=\(rs) ws=\(ws) we=\(we) samples=\(state.sampleCount)"
        devLog("PUMP TIMEOUT: \(msg)")
        resumeOnce(.failure(NSError(
          domain: "com.gen.videotolivephoto",
          code: Int(rs * 10 + ws),
          userInfo: [NSLocalizedDescriptionKey: msg]
        )))
      }

      input.requestMediaDataWhenReady(on: pumpQueue) {
        if state.resumed { return }
        while input.isReadyForMoreMediaData {
          // Writer went terminal → fail immediately.
          if writer.status == .failed || writer.status == .cancelled {
            let msg = "pump_\(label)_writer_terminal status=\(writer.status.rawValue) err=\(writer.error?.localizedDescription ?? "nil")"
            devLog(msg)
            resumeOnce(.failure(NSError(domain: "com.gen.videotolivephoto", code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: msg])))
            return
          }

          guard let buffer = output.copyNextSampleBuffer() else {
            // End-of-stream. If reader failed, surface the error.
            if reader.status == .failed {
              let msg = "pump_\(label)_reader_failed err=\(reader.error?.localizedDescription ?? "nil")"
              devLog(msg)
              resumeOnce(.failure(NSError(domain: "com.gen.videotolivephoto", code: -1,
                                          userInfo: [NSLocalizedDescriptionKey: msg])))
              return
            }
            devLog("pump(\(label)) end-of-stream samples=\(state.sampleCount)")
            resumeOnce(.success(()))
            return
          }

          // PTS-based clip boundary check.
          let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
          if pts.isValid {
            if state.firstPTS == nil { state.firstPTS = pts.seconds }
            let elapsed = pts.seconds - (state.firstPTS ?? pts.seconds)
            if elapsed >= clipDuration {
              devLog("pump(\(label)) clipDuration reached samples=\(state.sampleCount) elapsed=\(String(format: "%.3f", elapsed))s")
              resumeOnce(.success(()))
              return
            }
          }

          if !input.append(buffer) {
            let msg = "pump_\(label)_append_failed samples=\(state.sampleCount) writerErr=\(writer.error?.localizedDescription ?? "nil")"
            devLog(msg)
            resumeOnce(.failure(NSError(domain: "com.gen.videotolivephoto", code: -3,
                                        userInfo: [NSLocalizedDescriptionKey: msg])))
            return
          }
          state.sampleCount += 1
        }
        // isReadyForMoreMediaData went false → system will re-invoke this block.
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
