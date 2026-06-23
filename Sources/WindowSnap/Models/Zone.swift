import Foundation

/// A named region within a display, stored as a fractional rect so it scales to
/// any display size.
struct Zone: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var rect: FracRect

    init(id: UUID = UUID(), name: String, rect: FracRect) {
        self.id = id
        self.name = name
        self.rect = rect
    }
}

/// A named collection of zones the user can switch between. Built-in layouts have
/// stable IDs and are not persisted (they are regenerated at launch); user
/// layouts are saved to disk.
struct Layout: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var zones: [Zone]
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, zones: [Zone], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.zones = zones
        self.isBuiltIn = isBuiltIn
    }
}
