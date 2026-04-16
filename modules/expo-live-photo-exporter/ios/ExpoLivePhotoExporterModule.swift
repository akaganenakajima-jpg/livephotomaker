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

    // (A) Still JPEG with MakerApple content identifier
    let taggedStillURL = try writeTaggedStill(source: stillURL, contentIdentifier: contentIdentifier)
    devLog("tagged still written -> \(taggedStillURL.lastPathComponent)")

    // --- Stage 1: Trim to 3 seconds using the proven AVAssetExportSession API
    // This isolates the trimming failure class from the metadata-injection
    // failure class. The earlier pipeline fused reader.timeRange + passthrough +
    // requestMediaDataWhenReady + DispatchSemaphore, and any one of them could
    // silently hang the whole pipeline (rs=1 ws=1 we=nil). Splitting the work
    // lets us see precisely which stage is failing.
    let clipURL = try await generateClip(
      source: movURL,
      startSeconds: startSeconds,
      endSeconds: endSeconds
    )
    devLog("stage1 clip generated -> \(clipURL.lastPathComponent)")

    // --- Stage 2: Tag the already-trimmed clip with Live Photo metadata (B)(C).
    // Input is now a clean MOV produced by AVAssetExportSession, so the
    // reader/writer here never needs to seek or re-trim — it just drains the
    // whole file and injects metadata.
    let taggedMovURL = try await writeTaggedMovie(
      source: clipURL,
      contentIdentifier: contentIdentifier
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

  // MARK: - Stage 1: generate a 3-second clip
  //
  // AVAssetExportSession is Apple's high-level trim/transcode API. Unlike the
  // AVAssetReader + AVAssetWriter + requestMediaDataWhenReady dance, it
  // exposes a simple completion-handler callback (`exportAsynchronously`) and
  // handles format negotiation, codec selection, and timing internally.
  //
  // Why this replaces our earlier trim strategy:
  //   - reader.timeRange was blocking copyNextSampleBuffer() for 20+ seconds.
  //   - removing reader.timeRange exposed a deeper issue (passthrough hint).
  //   - AVAssetExportSession sidesteps both: it owns its internal pump and
  //     has been iteratively hardened by Apple across every iOS release.
  //
  // Output: an H.264 .mov with the requested time range, ready for Stage 2.
  private static let stage1TimeoutSeconds: Double = 15

  static func generateClip(
    source: URL,
    startSeconds: Double,
    endSeconds: Double
  ) async throws -> URL {
    let asset = AVURLAsset(url: source)

    // Clamp to actual duration. Passing a timeRange beyond the asset's own
    // duration causes AVAssetExportSession to fail with -11800.
    let assetDuration = (try? await asset.load(.duration)) ?? .zero
    let totalSeconds = assetDuration.seconds.isFinite ? assetDuration.seconds : endSeconds
    let start = max(0, startSeconds)
    let end   = min(totalSeconds, max(start + 0.1, endSeconds))
    devLog("stage1 source duration=\(totalSeconds)s clip=[\(start), \(end)]s")

    // Prefer the passthrough preset so we don't waste time re-encoding a
    // source that's already H.264/HEVC. AVAssetExportPresetHighestQuality
    // forces re-encode; AVAssetExportPresetPassthrough keeps original samples.
    let preset = AVAssetExportPresetPassthrough
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      devLog("stage1 AVAssetExportSession init failed")
      throw LivePhotoExporterError.movieWriterCreateFailed
    }

    let destURL = temporaryURL(extension: "mov")
    session.outputURL = destURL
    session.outputFileType = .mov
    session.shouldOptimizeForNetworkUse = true
    session.timeRange = CMTimeRange(
      start: CMTime(seconds: start, preferredTimescale: 600),
      end:   CMTime(seconds: end,   preferredTimescale: 600)
    )

    devLog("stage1 export starting preset=\(preset) -> \(destURL.lastPathComponent)")

    // Wrap the old-style completion-handler API in Swift concurrency.
    // Also arm a safety timeout in case export never completes.
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      let sessionBox = ExportSessionBox(session: session)
      let resumed = AtomicFlag()

      // Safety timeout
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + stage1TimeoutSeconds) {
        if resumed.setIfFalse() {
          sessionBox.session.cancelExport()
          let msg = "stage1_export_timeout status=\(sessionBox.session.status.rawValue)"
          devLog(msg)
          cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -30,
                                        userInfo: [NSLocalizedDescriptionKey: msg]))
        }
      }

      sessionBox.session.exportAsynchronously {
        guard resumed.setIfFalse() else { return }
        let s = sessionBox.session
        switch s.status {
        case .completed:
          devLog("stage1 export completed status=2")
          cont.resume(returning: ())
        case .failed:
          let msg = "stage1_export_failed: \(s.error?.localizedDescription ?? "nil")"
          devLog(msg)
          cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -31,
                                        userInfo: [NSLocalizedDescriptionKey: msg]))
        case .cancelled:
          let msg = "stage1_export_cancelled"
          devLog(msg)
          cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -32,
                                        userInfo: [NSLocalizedDescriptionKey: msg]))
        default:
          let msg = "stage1_export_unexpected_status=\(s.status.rawValue)"
          devLog(msg)
          cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -33,
                                        userInfo: [NSLocalizedDescriptionKey: msg]))
        }
      }
    }

    return destURL
  }

  // MARK: - Stage 2: tag the clip with Live Photo metadata — 条件 (B)(C)
  //
  // Input is a pre-trimmed MOV from Stage 1. This dramatically simplifies
  // the work here:
  //   - no time range juggling (the file is already the right length)
  //   - no HEVC seek (AVAssetExportSession already produced a clean MOV)
  //   - passthrough reader/writer is safe because format descriptions are
  //     standard and well-formed
  //
  // Pump simplification:
  //   - NO requestMediaDataWhenReady, NO DispatchSemaphore.
  //   - A single GCD worker polls `isReadyForMoreMediaData` with a 5ms sleep
  //     and pulls sample buffers in a straight loop.
  //   - Completion, failure, and timeout all resume the continuation exactly
  //     once from inside the polling loop — no callback-vs-wait race.
  static func writeTaggedMovie(
    source: URL,
    contentIdentifier: String
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
    devLog("stage2 video naturalSize=\(naturalSize) transform=\(transform)")

    // Source format description is required for passthrough to work —
    // without it the writer input stays stuck in "not ready" forever.
    let sourceFormat = (try? await sourceVideoTrack.load(.formatDescriptions))?.first
    if sourceFormat == nil {
      devLog("stage2 WARN: formatDescriptions is empty, passthrough may fail")
    }

    // ---- Reader (passthrough — input is a clean MOV from Stage 1) ----
    guard let reader = try? AVAssetReader(asset: asset) else {
      devLog("AVAssetReader init failed")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }

    let videoOutput = AVAssetReaderTrackOutput(track: sourceVideoTrack, outputSettings: nil)
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

    // Passthrough writer input with sourceFormatHint — this is the critical
    // fix that was missing before. Without a format hint, an AVAssetWriterInput
    // with outputSettings=nil has no idea what codec / dimensions to expect,
    // and isReadyForMoreMediaData stays false indefinitely.
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: nil,
      sourceFormatHint: sourceFormat
    )
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
      devLog("stage2 writer.startWriting failed: \(writer.error?.localizedDescription ?? "nil")")
      throw LivePhotoExporterError.movieStartWritingFailed
    }
    guard reader.startReading() else {
      devLog("stage2 reader.startReading failed: \(reader.error?.localizedDescription ?? "nil") status=\(reader.status.rawValue)")
      throw LivePhotoExporterError.movieReaderCreateFailed
    }
    devLog("stage2 reader/writer started")
    writer.startSession(atSourceTime: .zero)

    // (C) still-image-time: 1 sample, value 0, duration 1/30s.
    let stillItem = makeStillImageTimeMetadataItem()
    let stillGroup = AVTimedMetadataGroup(
      items: [stillItem],
      timeRange: CMTimeRangeMake(start: .zero, duration: CMTimeMake(value: 1, timescale: 30))
    )
    metadataAdaptor.append(stillGroup)
    metadataAdaptor.assetWriterInput.markAsFinished()
    devLog("stage2 still-image-time appended")

    // ---- Simple polling pump ----
    devLog("stage2 pump start")
    try await drainSamples(
      input: videoInput,
      from: videoOutput,
      reader: reader,
      writer: writer,
      label: "stage2"
    )
    devLog("stage2 pump done")
    videoInput.markAsFinished()

    // ---- Finish ----
    devLog("stage2 writer.finishWriting start")
    await writer.finishWriting()
    devLog("stage2 writer.finishWriting done status=\(writer.status.rawValue)")
    if writer.status != .completed {
      devLog("stage2 writer finish status=\(writer.status.rawValue) error=\(writer.error?.localizedDescription ?? "nil")")
      throw LivePhotoExporterError.movieFinishWritingFailed
    }
    return destURL
  }

  // MARK: - drainSamples
  //
  // Simple polling pump. Replaces the earlier requestMediaDataWhenReady +
  // DispatchSemaphore design, which hung with rs=1 ws=1 we=nil because the
  // GCD callback was never invoked.
  //
  // Design:
  //   - Runs on a dedicated serial queue via DispatchQueue.async.
  //   - Tight loop: check writer ready → pull next sample → append → repeat.
  //   - When writer.isReadyForMoreMediaData is false, yields via Thread.sleep
  //     (5ms) instead of blocking another queue.
  //   - 15-second hard timeout — shorter than the old 20s so we see failures
  //     before the upstream JS timeout fires.
  //   - Continuation is resumed exactly once, at any of the four exit paths
  //     (success / append failure / writer terminal / timeout).
  private static let drainTimeoutSeconds: Double = 15

  static func drainSamples(
    input: AVAssetWriterInput,
    from output: AVAssetReaderTrackOutput,
    reader: AVAssetReader,
    writer: AVAssetWriter,
    label: String
  ) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      let queue = DispatchQueue(label: "lp-drain-\(label)-\(UUID().uuidString)", qos: .userInitiated)
      queue.async {
        let start = Date()
        var samples = 0
        while true {
          // Safety timeout.
          if Date().timeIntervalSince(start) > drainTimeoutSeconds {
            let rs = reader.status.rawValue
            let ws = writer.status.rawValue
            let we = writer.error?.localizedDescription ?? "nil"
            let re = reader.error?.localizedDescription ?? "nil"
            let msg = "\(label)_drain_timeout samples=\(samples) rs=\(rs) ws=\(ws) we=\(we) re=\(re)"
            devLog(msg)
            cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto",
                                          code: Int(rs * 10 + ws),
                                          userInfo: [NSLocalizedDescriptionKey: msg]))
            return
          }
          // Writer terminal?
          if writer.status == .failed || writer.status == .cancelled {
            let msg = "\(label)_writer_terminal status=\(writer.status.rawValue) err=\(writer.error?.localizedDescription ?? "nil") samples=\(samples)"
            devLog(msg)
            cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -21,
                                          userInfo: [NSLocalizedDescriptionKey: msg]))
            return
          }
          // Writer not ready — back off and retry.
          if !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
            continue
          }
          // Pull next sample.
          guard let buffer = output.copyNextSampleBuffer() else {
            if reader.status == .failed {
              let msg = "\(label)_reader_failed err=\(reader.error?.localizedDescription ?? "nil") samples=\(samples)"
              devLog(msg)
              cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -22,
                                            userInfo: [NSLocalizedDescriptionKey: msg]))
              return
            }
            devLog("\(label) EOS samples=\(samples)")
            cont.resume(returning: ())
            return
          }
          // Append.
          if !input.append(buffer) {
            let msg = "\(label)_append_failed samples=\(samples) writerErr=\(writer.error?.localizedDescription ?? "nil")"
            devLog(msg)
            cont.resume(throwing: NSError(domain: "com.gen.videotolivephoto", code: -23,
                                          userInfo: [NSLocalizedDescriptionKey: msg]))
            return
          }
          samples += 1
        }
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

// MARK: - ExportSessionBox
//
// Holds an AVAssetExportSession so it can be captured across a
// `withCheckedThrowingContinuation` boundary (closures there are @Sendable but
// AVAssetExportSession is not Sendable-annotated).
private final class ExportSessionBox: @unchecked Sendable {
  let session: AVAssetExportSession
  init(session: AVAssetExportSession) { self.session = session }
}

// MARK: - AtomicFlag
//
// Minimal one-shot flag used to ensure a continuation is resumed exactly once
// when either the AVAssetExportSession completion handler or the safety
// timeout fires first.
private final class AtomicFlag: @unchecked Sendable {
  private var flag = false
  private let lock = NSLock()
  /// Atomically sets the flag to true; returns true iff this was the caller
  /// that flipped it. Subsequent callers get false.
  func setIfFalse() -> Bool {
    lock.lock(); defer { lock.unlock() }
    if flag { return false }
    flag = true
    return true
  }
}
