enum ExtractionScope: String, CaseIterable, Identifiable {
    case all = "all"
    case documents = "documents"
    case photos = "photos"
    case videos = "videos"
    case audio = "audio"
    case archives = "archives"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All files"
        case .documents:
            return "Documents"
        case .photos:
            return "Photos"
        case .videos:
            return "Videos"
        case .audio:
            return "Audio"
        case .archives:
            return "Archives"
        }
    }
}
