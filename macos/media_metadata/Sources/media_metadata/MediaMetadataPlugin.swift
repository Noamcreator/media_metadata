import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import FlutterMacOS

public class MediaMetadataPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let channel = FlutterMethodChannel(
            name: "media_metadata",
            binaryMessenger: registrar.messenger()
        )
        #else
        let channel = FlutterMethodChannel(
            name: "media_metadata",
            binaryMessenger: registrar.messenger
        )
        #endif
        let instance = MediaMetadataPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "filePath is required", details: nil))
            return
        }

        if call.method == "readMetadata" {
            DispatchQueue.global(qos: .userInitiated).async {
                let metadata = self.readMetadata(filePath: filePath)
                DispatchQueue.main.async {
                    result(metadata)
                }
            }
        } else if call.method == "writeMetadata" {
            guard let metadataMap = args["metadata"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "metadata map is required", details: nil))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.writeMetadata(filePath: filePath, metadata: metadataMap)
                DispatchQueue.main.async {
                    result(success)
                }
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Lecture des Métadonnées
    private func readMetadata(filePath: String) -> [String: Any?] {
        let url = URL(fileURLWithPath: filePath)
        let ext = url.pathExtension.lowercased()
        
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "gif"]
        if imageExtensions.contains(ext) {
            return readImageMetadata(url: url)
        } else {
            return readAudioVideoMetadata(url: url)
        }
    }

    private func readAudioVideoMetadata(url: URL) -> [String: Any?] {
        var result: [String: Any?] = [
            "title": nil, "duration": nil, "artist": nil, "album": nil,
            "albumArtist": nil, "trackNumber": nil, "trackTotal": nil,
            "discNumber": nil, "discTotal": nil, "year": nil, "genre": nil,
            "imageData": nil, "fileSize": nil
        ]

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            result["fileSize"] = size
        }

        let asset = AVAsset(url: url)
        let duration = asset.duration
        if duration.isNumeric && duration.value > 0 {
            result["duration"] = Int64(CMTimeGetSeconds(duration) * 1000)
        }

        let formats = asset.availableMetadataFormats
        for format in formats {
            let items = asset.metadata(forFormat: format)
            for item in items {
                guard let key = item.commonKey?.rawValue ?? item.key?.description else { continue }
                
                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue, "title", "©nam":
                    result["title"] = item.stringValue
                case AVMetadataKey.commonKeyArtist.rawValue, "artist", "©ART":
                    result["artist"] = item.stringValue
                case AVMetadataKey.commonKeyAlbumName.rawValue, "album", "©alb":
                    result["album"] = item.stringValue
                case "albumArtist", "aART":
                    result["albumArtist"] = item.stringValue
                case AVMetadataKey.commonKeyType.rawValue, "genre", "©gen", "gnre":
                    result["genre"] = item.stringValue
                case AVMetadataKey.commonKeyCreationDate.rawValue, "year", "©day", "tyer":
                    if let dateStr = item.stringValue {
                        result["year"] = parseYear(dateStr)
                    }
                case "trkn", "trackNumber":
                    if let data = item.dataValue {
                        let (num, total) = parseITunesTrackGroup(data)
                        result["trackNumber"] = num
                        result["trackTotal"] = total
                    } else if let str = item.stringValue {
                        let (num, total) = parseTrackDiscString(str)
                        result["trackNumber"] = num
                        result["trackTotal"] = total
                    }
                case "disk", "discNumber":
                    if let data = item.dataValue {
                        let (num, total) = parseITunesTrackGroup(data)
                        result["discNumber"] = num
                        result["discTotal"] = total
                    } else if let str = item.stringValue {
                        let (num, total) = parseTrackDiscString(str)
                        result["discNumber"] = num
                        result["discTotal"] = total
                    }
                case AVMetadataKey.commonKeyArtwork.rawValue, "covr":
                    if let data = item.dataValue {
                        result["imageData"] = FlutterStandardTypedData(bytes: data)
                    }
                default:
                    break
                }
            }
        }
        return result
    }

    private func readImageMetadata(url: URL) -> [String: Any?] {
        var result: [String: Any?] = [
            "title": nil, "duration": nil, "artist": nil, "album": nil,
            "albumArtist": nil, "trackNumber": nil, "trackTotal": nil,
            "discNumber": nil, "discTotal": nil, "year": nil, "genre": nil,
            "imageData": nil, "fileSize": nil
        ]

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            result["fileSize"] = size
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return result
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            result["title"] = tiff[kCGImagePropertyTIFFImageDescription as String] as? String
            result["artist"] = tiff[kCGImagePropertyTIFFArtist as String] as? String
            if let dateStr = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
                result["year"] = parseYear(dateStr)
            }
        }

        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            if result["title"] == nil { result["title"] = iptc[kCGImagePropertyIPTCObjectName as String] as? String }
            if result["artist"] == nil { result["artist"] = iptc[kCGImagePropertyIPTCByline as String] as? String }
            result["genre"] = iptc[kCGImagePropertyIPTCCategory as String] as? String
        }

        return result
    }

    // MARK: - Écriture des Métadonnées
    private func writeMetadata(filePath: String, metadata: [String: Any]) -> Bool {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            return false
        }
        
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
        exportSession.outputURL = tempUrl
        exportSession.outputFileType = AVFileType.fromExtension(url.pathExtension)
        exportSession.shouldOptimizeForNetworkUse = true
        
        var newMetadata: [AVMetadataItem] = []
        
        let mappings: [(String, AVMetadataKey, String)] = [
            ("title", .commonKeyTitle, "©nam"),
            ("artist", .commonKeyArtist, "©ART"),
            ("album", .commonKeyAlbumName, "©alb"),
            ("albumArtist", .mainITunesKey("aART"), "aART"),
            ("genre", .commonKeyType, "©gen")
        ]
        
        for (mapKey, commonKey, legacyKey) in mappings {
            if let val = metadata[mapKey] as? String {
                let item = AVMutableMetadataItem()
                item.keySpace = .common
                item.key = commonKey.rawValue as NSCopying & NSObjectProtocol
                item.value = val as NSString
                newMetadata.append(item)
                
                let iTunesItem = AVMutableMetadataItem()
                iTunesItem.keySpace = .iTunes
                iTunesItem.key = legacyKey as NSCopying & NSObjectProtocol
                iTunesItem.value = val as NSString
                newMetadata.append(iTunesItem)
            }
        }
        
        if let year = metadata["year"] as? Int {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyCreationDate.rawValue as NSCopying & NSObjectProtocol
            item.value = String(year) as NSString
            newMetadata.append(item)
        }
        
        // Track Number
        if let trackNum = metadata["trackNumber"] as? Int {
            let trackTotal = metadata["trackTotal"] as? Int ?? 0
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = "trkn" as NSCopying & NSObjectProtocol
            item.value = buildITunesTrackGroupData(num: trackNum, total: trackTotal) as NSData
            newMetadata.append(item)
        }
        
        // Disc Number
        if let discNum = metadata["discNumber"] as? Int {
            let discTotal = metadata["discTotal"] as? Int ?? 0
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = "disk" as NSCopying & NSObjectProtocol
            item.value = buildITunesTrackGroupData(num: discNum, total: discTotal) as NSData
            newMetadata.append(item)
        }
        
        // Artwork (covr)
        if let flutterData = metadata["imageData"] as? FlutterStandardTypedData {
            let imgData = flutterData.data
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyArtwork.rawValue as NSCopying & NSObjectProtocol
            item.value = imgData as NSData
            newMetadata.append(item)
            
            let iTunesItem = AVMutableMetadataItem()
            iTunesItem.keySpace = .iTunes
            iTunesItem.key = "covr" as NSCopying & NSObjectProtocol
            iTunesItem.value = imgData as NSData
            newMetadata.append(iTunesItem)
        }
        
        exportSession.metadata = newMetadata
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                success = true
            } else {
                print("[MediaMetadata] Export failed: \(String(describing: exportSession.error))")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if success {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.moveItem(at: tempUrl, to: url)
                return true
            } catch {
                print("[MediaMetadata] File replacement error: \(error)")
                return false
            }
        }
        return false
    }

    // MARK: - Parseurs & Helpers Réutilisables
    private func parseTrackDiscString(_ raw: String) -> (Int?, Int?) {
        let parts = raw.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let num = parts.first.flatMap { Int($0) }
        let total = parts.count > 1 ? Int(parts[1]) : nil
        return (num, total)
    }

    private func parseITunesTrackGroup(_ data: Data) -> (Int?, Int?) {
        guard data.count >= 6 else { return (nil, nil) }
        let num = Int(data[2]) << 8 | Int(data[3])
        let total = Int(data[4]) << 8 | Int(data[5])
        return (num > 0 ? num : nil, total > 0 ? total : nil)
    }
    
    private func buildITunesTrackGroupData(num: Int, total: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: 8)
        bytes[2] = UInt8((num >> 8) & 0xFF)
        bytes[3] = UInt8(num & 0xFF)
        bytes[4] = UInt8((total >> 8) & 0xFF)
        bytes[5] = UInt8(total & 0xFF)
        return Data(bytes)
    }

    private func parseYear(_ raw: String) -> Int? {
        let pattern = #"\b(\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: raw, options: [], range: NSRange(raw.startIndex..., in: raw)),
              let range = Range(match.range(at: 1), in: raw) else {
            return nil
        }
        return Int(raw[range])
    }
}

extension AVMetadataKey {
    static func mainITunesKey(_ key: String) -> AVMetadataKey {
        return AVMetadataKey(rawValue: key)
    }
}

extension AVFileType {
    static func fromExtension(_ ext: String) -> AVFileType {
        switch ext.lowercased() {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "mov": return .mov
        case "mkv": return .mov
        default: return .mp4
        }
    }
}