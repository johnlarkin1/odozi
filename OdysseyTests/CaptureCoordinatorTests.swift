import os
@testable import Odyssey
import XCTest

/// A fake capture that stays "in flight" until the test opens it.
@MainActor
private final class Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class Counter {
    var value = 0
}

@MainActor
final class CaptureCoordinatorTests: XCTestCase {
    private var coordinator: CaptureCoordinator!
    private var runs: Counter!
    private var gate: Gate!

    override func setUp() async throws {
        coordinator = CaptureCoordinator()
        runs = Counter()
        gate = Gate()
    }

    /// Starts a run that blocks on the gate and waits until the coordinator reports it in flight.
    private func startBlockedRun(force: Bool) async -> Task<CaptureCoordinator.Outcome, Never> {
        let coordinator: CaptureCoordinator = self.coordinator
        let runs: Counter = self.runs
        let gate: Gate = self.gate
        let task = Task { @MainActor in
            await coordinator.run(force: force, isDebounced: { false }, operation: {
                runs.value += 1
                await gate.wait()
            })
        }
        for _ in 0 ..< 1000 where !coordinator.isRunning {
            await Task.yield()
        }
        XCTAssertTrue(coordinator.isRunning, "the blocked run should be in flight")
        return task
    }

    /// Starts a caller that should join the run in flight, and lets it reach the join.
    private func startJoiner(force: Bool) async -> Task<CaptureCoordinator.Outcome, Never> {
        let coordinator: CaptureCoordinator = self.coordinator
        let runs: Counter = self.runs
        let task = Task { @MainActor in
            await coordinator.run(force: force, isDebounced: { false }, operation: {
                runs.value += 1
            })
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        return task
    }

    func testBackgroundJoinerDoesNotRunAgain() async {
        let owner = await startBlockedRun(force: false)
        let joiner = await startJoiner(force: false)

        gate.open()

        let ownerOutcome = await owner.value
        let joinerOutcome = await joiner.value
        XCTAssertEqual(ownerOutcome, .ran)
        XCTAssertEqual(joinerOutcome, .joined)
        XCTAssertEqual(runs.value, 1)
        XCTAssertFalse(coordinator.isRunning)
    }

    /// The foreground (forced) capture must not settle for a background-triggered run — e.g. a
    /// HealthKit observer firing at launch before the scene was active.
    func testForcedJoinerRunsAgainAfterBackgroundRun() async {
        let owner = await startBlockedRun(force: false)
        let joiner = await startJoiner(force: true)

        gate.open()

        let ownerOutcome = await owner.value
        let joinerOutcome = await joiner.value
        XCTAssertEqual(ownerOutcome, .ran)
        XCTAssertEqual(joinerOutcome, .ran, "a forced joiner re-runs after a background run")
        XCTAssertEqual(runs.value, 2)
    }

    func testForcedJoinerAcceptsForcedRun() async {
        let owner = await startBlockedRun(force: true)
        let joiner = await startJoiner(force: true)

        gate.open()

        let ownerOutcome = await owner.value
        let joinerOutcome = await joiner.value
        XCTAssertEqual(ownerOutcome, .ran)
        XCTAssertEqual(joinerOutcome, .joined)
        XCTAssertEqual(runs.value, 1)
    }

    /// A BGTask expiring cancels the run it owns; a forced caller that joined it must not be left
    /// with the partial capture.
    func testForcedJoinerRunsAgainAfterCancelledRun() async {
        let owner = await startBlockedRun(force: true)
        let joiner = await startJoiner(force: true)

        owner.cancel()
        gate.open()

        _ = await owner.value
        let joinerOutcome = await joiner.value
        XCTAssertEqual(joinerOutcome, .ran, "a forced joiner re-runs after a cancelled run")
        XCTAssertEqual(runs.value, 2)
    }

    func testDebounceSkipsOnlyBackgroundCallers() async {
        let counter: Counter = runs
        let background = await coordinator.run(force: false, isDebounced: { true }, operation: {
            counter.value += 1
        })
        XCTAssertEqual(background, .debounced)
        XCTAssertEqual(runs.value, 0)

        let forced = await coordinator.run(force: true, isDebounced: { true }, operation: {
            counter.value += 1
        })
        XCTAssertEqual(forced, .ran, "forced callers ignore the debounce")
        XCTAssertEqual(runs.value, 1)
    }

    func testSlotIsFreeOnceTheRunEnds() async {
        let counter: Counter = runs
        _ = await coordinator.run(force: true, isDebounced: { false }, operation: { counter.value += 1 })
        XCTAssertFalse(coordinator.isRunning)
        _ = await coordinator.run(force: false, isDebounced: { false }, operation: { counter.value += 1 })
        XCTAssertEqual(runs.value, 2, "sequential callers each run")
    }
}

final class CaptureDebounceStampTests: XCTestCase {
    func testOnlyCompleteRunsStampTheDebounce() {
        XCTAssertTrue(BackgroundSnapshotService.shouldStampDebounce(healthSkippedLocked: false, wasCancelled: false))
        XCTAssertFalse(BackgroundSnapshotService.shouldStampDebounce(healthSkippedLocked: true, wasCancelled: false),
                       "a locked-phone run must not debounce the unlock retry")
        XCTAssertFalse(BackgroundSnapshotService.shouldStampDebounce(healthSkippedLocked: false, wasCancelled: true),
                       "a run cut short by BGTask expiry must not debounce the next trigger")
    }
}

final class OneShotCompletionTests: XCTestCase {
    func testDeliversExactlyOnceUnderConcurrentCalls() {
        let delivered = OSAllocatedUnfairLock(initialState: [Bool]())
        let completion = OneShotCompletion { success in
            delivered.withLock { $0.append(success) }
        }
        let winners = OSAllocatedUnfairLock(initialState: 0)

        DispatchQueue.concurrentPerform(iterations: 200) { index in
            if completion.complete(success: index.isMultiple(of: 2)) {
                winners.withLock { $0 += 1 }
            }
        }

        XCTAssertEqual(delivered.withLock { $0.count }, 1)
        XCTAssertEqual(winners.withLock { $0 }, 1)
    }

    func testFirstCallerWins() {
        let delivered = OSAllocatedUnfairLock(initialState: [Bool]())
        let completion = OneShotCompletion { success in
            delivered.withLock { $0.append(success) }
        }

        XCTAssertTrue(completion.complete(success: true))
        XCTAssertFalse(completion.complete(success: false), "expiry after the work finished is a no-op")
        XCTAssertEqual(delivered.withLock { $0 }, [true])
    }
}
