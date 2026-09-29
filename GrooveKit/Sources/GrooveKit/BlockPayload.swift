import Foundation

/// What a notification carries so "Done" can log without recomputing anything.
public struct BlockPayload: Codable, Equatable, Sendable {
    public let blockId: String
    public let items: [PlannedItem]

    public init(blockId: String, items: [PlannedItem]) {
        self.blockId = blockId
        self.items = items
    }

    public init(block: PlannedBlock) {
        self.init(blockId: block.id, items: block.items)
    }

    public var userInfo: [String: Any] {
        ["blockId": blockId,
         "items": items.map { ["exerciseId": $0.exerciseId.uuidString, "reps": $0.reps] as [String: Any] }]
    }

    public init?(userInfo: [AnyHashable: Any]) {
        guard let blockId = userInfo["blockId"] as? String,
              let raw = userInfo["items"] as? [[String: Any]], !raw.isEmpty else { return nil }
        var items: [PlannedItem] = []
        for entry in raw {
            guard let idString = entry["exerciseId"] as? String, let id = UUID(uuidString: idString),
                  let reps = (entry["reps"] as? NSNumber)?.intValue ?? entry["reps"] as? Int else { return nil }
            items.append(PlannedItem(exerciseId: id, reps: reps))
        }
        self.init(blockId: blockId, items: items)
    }
}
