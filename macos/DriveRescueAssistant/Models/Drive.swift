import Foundation

struct Drive: Identifiable, Hashable, Decodable {
    let name: String
    let mountPath: String?
    let deviceID: String?
    let filesystem: String?
    let sizeBytes: Int64?
    let freeBytes: Int64?
    let isExternal: Bool?
    let isRemovable: Bool?
    let isWritable: Bool?
    let isTimeMachine: Bool
    let isEncrypted: Bool?
    let warnings: [String]

    var id: String {
        deviceID ?? mountPath ?? name
    }

    enum CodingKeys: String, CodingKey {
        case name
        case mountPath = "mount_path"
        case deviceID = "device_id"
        case filesystem
        case sizeBytes = "size_bytes"
        case freeBytes = "free_bytes"
        case isExternal = "is_external"
        case isRemovable = "is_removable"
        case isWritable = "is_writable"
        case isTimeMachine = "is_time_machine"
        case isEncrypted = "is_encrypted"
        case warnings
    }
}
