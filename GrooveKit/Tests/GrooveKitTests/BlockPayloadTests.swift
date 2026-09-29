import Foundation
import Testing
@testable import GrooveKit

@Suite struct BlockPayloadTests {
    @Test func roundTripThroughUserInfo() {
        let payload = BlockPayload(blockId: "2026-09-26-1430", items: [
            PlannedItem(exerciseId: UUID(), reps: 5), PlannedItem(exerciseId: UUID(), reps: 12),
        ])
        let userInfo = payload.userInfo as [AnyHashable: Any]
        #expect(BlockPayload(userInfo: userInfo) == payload)
    }

    @Test func acceptsNSNumberReps() {
        let id = UUID()
        let info: [AnyHashable: Any] = ["blockId": "x", "items": [["exerciseId": id.uuidString, "reps": NSNumber(value: 7)]]]
        #expect(BlockPayload(userInfo: info)?.items == [PlannedItem(exerciseId: id, reps: 7)])
    }

    @Test func rejectsGarbage() {
        #expect(BlockPayload(userInfo: [:]) == nil)
        #expect(BlockPayload(userInfo: ["blockId": "x", "items": []]) == nil)
        #expect(BlockPayload(userInfo: ["blockId": "x", "items": [["exerciseId": "nope", "reps": 3]]]) == nil)
    }

    @Test func fromBlock() {
        let block = PlannedBlock(id: "b", date: .now, items: [PlannedItem(exerciseId: UUID(), reps: 3)])
        #expect(BlockPayload(block: block) == BlockPayload(blockId: "b", items: block.items))
    }
}
