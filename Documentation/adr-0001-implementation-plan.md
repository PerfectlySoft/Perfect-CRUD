# ADR-0001 Implementation Plan — PerfectCRUD Roadmap

**Status:** Reviewed — revised per expert feedback (concurrency, testing, ecosystem-compatibility)
**Date:** 2026-07-26
**Companion to:** [adr-0001-orm-roadmap-vs-rewrite.md](adr-0001-orm-roadmap-vs-rewrite.md)

## Implementation note (added after Phase 2 was built)

Phase 2's design called for overloading async methods by the same name as
their sync counterparts (`sql`, `transaction`, `first`, `insert`, `update`,
`delete`), resolved by call-site `await` presence. **Verified wrong by
direct testing against the actual toolchain**: an isolated minimal
reproduction showed that once an `async` overload exists anywhere in scope
with the same name, Swift requires `await` even for an unrelated sync call
with no `await` written — it does not reliably fall back to the sync
candidate. This would have broken every existing sync call site inside an
already-`async` closure, which is exactly what `PerfectNIOCRUD` route
handlers are (`Routes.db()`'s `call` closures are `async throws`). As
implemented, every async method with a sync counterpart is suffixed
`Async` (`sqlAsync`, `transactionAsync`, `firstAsync`, `insertAsync`,
`updateAsync`, `deleteAsync`) instead. `fetchAll()` has no sync twin, so it
keeps its plain name. See `AsyncExecution.swift`'s header comment for the
full account.

A second real bug was caught by a failing test, not by inspection:
`SQLGenDelegate.setIsolationLevelSQL` was originally added as a bare
protocol extension with no corresponding protocol requirement — meaning a
conformer's own override was silently unreachable through the `any
SQLGenDelegate` existential `Database`/`Table` actually hold (extension-only
methods dispatch statically to the declared type, not the dynamic one).
Fixed by adding it as a real requirement with a default implementation,
matching the pre-existing `getEmptyInsertSnippet()` pattern in the same
protocol. Worth flagging as a general lesson for any future protocol
extension meant to be an override point: it must be declared in the
protocol body, not just added via `extension`, or dynamic dispatch through
an existential silently no-ops.

## Review summary

Three expert passes reviewed this plan before implementation: a Swift-concurrency-correctness review, a Swift-testing-strategy review, and an ecosystem-compatibility review that verified claims against the real dependent packages. Their findings are folded in below, with the most consequential one first: **the `tableStructureCache` race isn't a Phase 5 risk — it's a live bug today**, independently flagged by both the concurrency reviewer (reasoning from the code) and the ecosystem reviewer (who found a concrete, unauthenticated, concurrently-reachable trigger in `PerfectTemplate`). Two other must-fix findings reshaped Phase 1 and Phase 2's designs; all are addressed in place below rather than kept as a separate errata list.

This document turns ADR-0001's 7 action items into a concrete, codebase-grounded implementation blueprint. Detail decreases by phase: Phases 1-3 have concrete file/type/API designs ready to build from; Phases 4-6 are lighter outlines to detail when their turn comes. Phase 7 (nested transactions/savepoints/isolation) is folded into Phase 2, per the ADR.

Grounded in a direct read of `Perfect-CRUD/Sources/PerfectCRUD/{PerfectCRUD,Database,Create,Dynamic,Table,Select,Insert,Update,Delete,Logging}.swift`, all four connector packages (`Perfect-MySQL`, `Perfect-PostgreSQL`, `Perfect-SQLite`, `Perfect-MariaDB`), `Perfect-NIO/Sources/PerfectNIOCRUD/RouteCRUD.swift`, `Perfect-NIO/Sources/PerfectAdminConsole/AdminConsoleDelegate.swift`, and `PerfectTemplate/Sources/App/DB.swift`.

Two facts drive most of the design below:

1. **`DatabaseConfigurationProtocol` conformers *are* the connection**, not a factory that hands one out. `MySQLDatabaseConfiguration`, `SQLiteDatabaseConfiguration`, `PostgresDatabaseConfiguration` each wrap exactly one live connection object, captured at `init`, all `@unchecked Sendable` (single-owner-at-a-time is an unenforced convention today). A pool is therefore a pool of `C: DatabaseConfigurationProtocol` instances, checked out exclusively.
2. **`Insert`/`Update`/`Delete`/`Create`/`Index` execute inside their `init`** — throwing struct initializers that immediately run SQL. `Select` is the one lazy exception; `SelectIterator.next()` is where SQL actually executes. This drives Phase 2's async seam design.

**Pre-existing bug surfaced while reading connector code (relevant to Phase 4):** `MySQLGenDelegate.getColumnDefinition` and MariaDB's equivalent only branch on `.primaryKey` — neither ever handles `.foreignKey`, unlike `SQLiteGenDelegate`/`PostgresGenDelegate`, which both emit real `FOREIGN KEY`/`REFERENCES` clauses. So `@ForeignKey` today would generate real constraints on SQLite/Postgres and *silently emit none* on MySQL/MariaDB. Flagged here as a real correctness gap to fix at the start of Phase 4, not a hypothetical.

---

## Phase 0 — Fix `tableStructureCache` Concurrency Hazard (live bug, not a future risk)

**Added after review.** The original draft filed this under "Phase 5 prerequisite," reasoning that `tableStructureCache` (`Create.swift:156`, a `nonisolated(unsafe)` plain `Dictionary` with no lock) was only ever populated from a single-threaded startup path. Both the concurrency reviewer and the ecosystem-compatibility reviewer independently rejected that premise:

- **Concrete live trigger**: `PerfectTemplate/Sources/App/Routes/APIRoutes.swift:95-98` registers `GET /api/dbsetup` — an unauthenticated HTTP route, not startup code — which calls `setupSchema()` → `db.create(Post.self, ...)` → `CRUDTableStructure(...)` → an unsynchronized read (`Create.swift:172`) and write (`Create.swift:213`) of the global cache. Two concurrent requests to this route race on an unsynchronized `Dictionary` write **today, on `main`, with zero PerfectCRUD changes.**
- **Why Phase 2 makes it worse, not just "also bad"**: `CRUDBlockingExecutor`'s `.concurrent` `DispatchQueue` (Phase 2, below) is the first thing in this codebase's history to give multiple real OS threads simultaneous access to this global — Phase 3's migrator calling `db.create(CRUDMigrationRecord.self, ...)` concurrently with an app's own reconciliation calls is a plausible, not hypothetical, trigger once pooling and async execution exist.

**Action**: lock-protect or actor-isolate `tableStructureCache` as a standalone fix, independent of and before every other phase. Small, high-value, no design dependencies on anything else in this document.

- **Files to modify**: `Perfect-CRUD/Sources/PerfectCRUD/Create.swift` (wrap `tableStructureCache` access in an `NSLock`, matching the `CRUDTransactionDepth` pattern introduced in Phase 2 below — no need for an `actor` here since the read/compute/write sequence needs to stay a single critical section, not just individually-atomic operations).
- **Test**: a regression test that drives concurrent `CRUDTableStructure(...)` calls for the same type from multiple tasks (e.g. `withThrowingTaskGroup`, 50+ concurrent calls) and asserts no crash / a single consistent cached value — this is the one test in this plan that should exist purely to prove a bug is fixed, not just that a new feature works.

---

## Phase 1 — Connection Pooling

### Where the pool lives

Inside `PerfectCRUD` itself, as a new file `Sources/PerfectCRUD/Pool.swift` — not a new package, not inside `PerfectNIOCRUD`. `PerfectCRUD` has zero dependencies and connector packages already depend *on* it, not the reverse, so a pool generic over `DatabaseConfigurationProtocol` needs nothing beyond what's already in the target. Putting it in `PerfectNIOCRUD` would deny pooling to non-NIO consumers (CLI tools, the Lasso Adapter's non-NIO paths, plain scripts).

### Public API

```swift
public actor DatabaseConnectionPool<C: DatabaseConfigurationProtocol & Sendable> {
    public struct Configuration: Sendable {
        public var minConnections: Int
        public var maxConnections: Int
        public var acquireTimeout: Duration?
        public init(minConnections: Int = 1, maxConnections: Int = 5, acquireTimeout: Duration? = .seconds(10))
    }

    public init(configuration: Configuration = .init(),
                makeConnection: @Sendable @escaping () throws -> C) throws

    /// Checks a connection out, runs `body`, always checks it back in
    /// (even on throw/cancellation) — the only supported access pattern.
    public func withConnection<T: Sendable>(_ body: @Sendable (Database<C>) async throws -> T) async throws -> T

    public var currentSize: Int { get async }
    public var availableCount: Int { get async }
}
```

Internals: an `actor` holding `available: [C]`, `createdCount: Int`, and a waiter queue, with `withTaskCancellationHandler` so a cancelled waiter doesn't leak a slot. Lazily creates connections up to `maxConnections` using the caller-supplied `makeConnection` closure — literally today's `makeDB()` body, reused as-is.

**Revised after review — two must-fix corrections to the naive design above:**

1. **The pool must not call `makeConnection()` synchronously on its own actor-isolated code.** A plain `actor` with no custom executor runs its isolated methods on Swift's default cooperative pool — calling a blocking, synchronous `makeConnection()` (dialing MySQL/Postgres, opening a `sqlite3*` file) directly from inside actor code stalls a cooperative-pool thread for the duration of the connect, exactly the failure mode this whole roadmap exists to eliminate. Fix: invoke `makeConnection()` via `withCheckedThrowingContinuation` + `DispatchQueue.global().async` from within the actor method, not inline. This is the same "Plan B" pattern Phase 2 now uses as its primary design (see below) — build it once, share it between Phase 1 and Phase 2 rather than treating them as fully independent. **This means Phase 1 and Phase 2 are not fully order-independent in practice**: Phase 1 needs a minimal blocking-dispatch helper that Phase 2 later expands into the full async-execution boundary. Recommend building that shared helper first, then Phase 1's pool and Phase 2's query execution both consume it.
2. **The waiter queue needs an explicit cancel-safe state machine, not just a `withTaskCancellationHandler` mention.** `onCancel` fires synchronously and non-isolated — it cannot call an actor method directly, so it must itself spawn `Task { await pool.cancelWaiter(id) }`, which races against normal checkout. Design: assign each waiter an ID *before* suspending; track per-ID state (`pending` / `cancelled` / `fulfilled`) inside the actor so registration and cancellation are commutative regardless of arrival order; ensure exactly one of {checkout, cancellation} ever resumes a given continuation. Test this with a stress case (many concurrent cancels racing many concurrent checkouts), not just a single-shot correctness test — this composition is a known-hard spot in Swift concurrency and deserves more than a unit test's worth of confidence.

**`Configuration.acquireTimeout` scoped out of v1.** Racing a timeout against the cancel-safe waiter design above compounds the same double-resume risk. Deferred; document the field as reserved/unused rather than half-wiring it.

### Consuming it from PerfectNIOCRUD without breaking existing callers

`RouteCRUD.swift:26-47` takes an `@autoclosure @escaping @Sendable () throws -> Database<C>`, re-evaluated per request. Add **new overloads**, distinguished by an explicit `pool:` label, so the existing `@autoclosure` overload stays byte-for-byte unchanged:

```swift
public extension Routes {
    func db<C: DCP & Sendable, NewOut>(
        pool: DatabaseConnectionPool<C>,
        _ call: @Sendable @escaping (OutType, Database<C>) async throws -> NewOut
    ) -> Routes<InType, NewOut> {
        map { input in try await pool.withConnection { db in try await call(input, db) } }
    }
    // .table(pool:_:_:) mirrors this
}
```

Old call sites (`.db(makeDB(), ...)`) keep resolving to the existing overload — zero source breaks. New adopters build one pool at startup and switch call sites to `.db(pool: dbPool) { ... }`.

### Backward compatibility

`PerfectTemplate/Sources/App/DB.swift`'s `makeDB()` needs no changes. Pool adoption is additive:
```swift
let dbPool = try DatabaseConnectionPool(makeConnection: makeDB)
// then: .db(pool: dbPool) { ... }  instead of  .db(makeDB(), ...)
```

### Per-connector concurrency semantics

- **MySQL / PostgreSQL / MariaDB**: network connections, safe to hold N open concurrently — standard pool behavior. `maxConnections` must stay under the target DB server's own connection cap, especially across multiple app instances.
- **SQLite**: file-based, fundamentally different. `SQLiteDatabaseConfiguration.init` opens one `sqlite3*` per instance with no WAL/busy-timeout pragma set by default. Multiple concurrent writer connections to the same file will produce `SQLITE_BUSY` under load. **v1 recommendation: document that SQLite pools should be sized `maxConnections: 1`** unless the caller explicitly configures `PRAGMA journal_mode=WAL` + `busy_timeout`. Open question: whether to add a `DatabaseConfigurationProtocol` static hint (`static var recommendedPoolSize: Int { get }`, default `.max`, overridden to `1` by SQLite) so the pool can warn/clamp automatically — small additive change, can be a fast-follow.

### Files to create/modify

- **Create** `Perfect-CRUD/Sources/PerfectCRUD/Pool.swift`
- **Create** `Perfect-CRUD/Tests/PerfectCRUDTests/PoolTests.swift` — Swift Testing, `.serialized` suite convention matching `PerfectCRUDTests.swift`, stub `DatabaseConfigurationProtocol` plus an instrumented variant recording checkout/checkin ordering
- **Modify** `Perfect-NIO/Sources/PerfectNIOCRUD/RouteCRUD.swift` — add the `pool:` overloads
- **Modify/create** `Perfect-NIO/Tests/PerfectNIOMySQLTests/MySQLIntegrationTests.swift` — pooled-route integration test alongside the existing per-request one
- **Create** `Perfect-CRUD/Documentation/pooling.md`
- No changes required to `PerfectTemplate/Sources/App/DB.swift`

### Testing approach

Swift Testing. Cover: sequential acquire/release reuses the same connection identity; concurrent `withConnection` calls beyond `maxConnections` queue and are served in order; a thrown error inside `body` still checks the connection back in; task cancellation while waiting doesn't leak a slot; `minConnections` pre-warms exactly that many at `init`.

### Risks / open questions

- No connection liveness/health check on checkout in v1 — a dropped connection surfaces as a query-time error, not proactive eviction. Fast-follow (`validate:` closure param), not a v1 blocker.
- No idle-eviction/max-lifetime — pool only grows. Fine for long-running server processes; a gap if this ever runs scale-to-zero.
- Waiter-queue cancellation is addressed above with an explicit state-machine design — flagged here as the item most likely to fail silently if the implementation drifts from that design during a rushed pass.
- SQLite pool sizing is documentation-only in v1, not type-enforced — a misconfigured pool will compile and often *appear* to work until concurrent writes collide.
- **`withConnection`'s closure scoping is convention, not a compiler guarantee.** Because `Database<C>` must itself be `Sendable` to cross the actor boundary, nothing stops a caller from capturing the `db` argument into an outer variable or a detached `Task` and using it after `withConnection` returns — the type system can't catch this. Document loudly in `pooling.md` rather than implying it's enforced.
- Once Phase 2's `CRUDBlockingExecutor`/blocking-dispatch helper exists, revisit whether the pool's dedicated queue and Phase 2's should be the same queue (bounded together) or deliberately separate — call out in Phase 2's risks below.

---

## Phase 2 — Async Execution Boundary (+ nested transactions/savepoints/isolation, folds in Action Item 7)

### Where the async/sync seam sits

Inside `PerfectCRUD` itself, not only at the `PerfectNIOCRUD` bridge — same reasoning as Phase 1's placement. The sync core (query builder, `SQLGenDelegate`/`SQLExeDelegate`, every connector) stays exactly as-is; zero changes to the connector protocol contract.

The critical constraint: blocking C-library calls (`libmysqlclient`, `libpq`, `sqlite3`) must never run on Swift's default cooperative executor — that's the literal failure mode the ADR names.

**Revised after review — primary/fallback flipped from the original draft.** The original design led with a custom `TaskExecutor` (SE-0417) and named `withCheckedThrowingContinuation` + `DispatchQueue.global` as a fallback "Plan B." The concurrency reviewer's assessment: both approaches move blocking work off the cooperative pool equally well, neither can interrupt work already in flight either way, but the continuation-based approach is simpler, avoids spawning an extra unstructured `Task` per call, keeps the *caller's own* task suspended (rather than a disconnected one), and gets the Swift runtime's double-resume/never-resumed detection for free. **Continuation-based dispatch is now the primary v1 design**; `TaskExecutor` is deferred to a later optimization pass only if profiling shows the per-call overhead actually matters at high request rates.

```swift
// Sources/PerfectCRUD/AsyncExecution.swift
func withCRUDExecutor<T: Sendable>(_ body: @Sendable @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        CRUDBlockingQueue.shared.async {
            do { continuation.resume(returning: try body()) }
            catch { continuation.resume(throwing: error) }
        }
    }
}

enum CRUDBlockingQueue {
    static let shared = DispatchQueue(label: "PerfectCRUD.blocking", qos: .userInitiated, attributes: .concurrent)
}
```

This same `CRUDBlockingQueue` (or a shared abstraction wrapping it) is what Phase 1's pool should use internally for `makeConnection()` dispatch, per the revision to Phase 1 above — build this helper first, then have both phases consume it.

**Cancellation is best-effort only, and this must be documented, not left implicit.** Neither this design nor the deferred `TaskExecutor` alternative can interrupt a blocking C call already in flight — there's no suspension point inside `mysql_stmt_execute()` for Swift's cooperative cancellation to act on. If the calling task is cancelled while `await db.transaction { ... }` is running, that cancellation does not stop the underlying query; `withCRUDExecutor` simply keeps waiting for it to finish. Document this explicitly in `pooling.md`/an equivalent async-execution doc so callers don't assume `task.cancel()` aborts an in-flight query.

### Sendable retrofit — a required first step, not a downstream audit

**Added after review.** The original draft's only nod to this was a Phase-2 "risk" reading "needs an explicit check against Perfect-Session's and the Lasso Adapter's model types" — framed as auditing external consumer row types. The concurrency reviewer found this understates the problem: it's a **compile-time blocker for PerfectCRUD's own types**, not just a downstream audit. Every async extension method captures `self`/query-builder state in a `@Sendable @escaping` closure passed to `withCRUDExecutor`, which requires `Self: Sendable`. None of `Selectable`, `TableProtocol`, `Whereable`, `Orderable`, `Limitable`, `Joinable`, `FromTableProtocol`, or their concrete conformers (`Table`, `Where`, `Join`, `JoinPivot`, `Ordering`, `Limit`, `Select`, `Insert`, `Update`, `Delete`) currently declare `Sendable`, and `DatabaseConfigurationProtocol` itself isn't `Sendable`-constrained.

**Action, sequenced before `AsyncExecution.swift` is written:** retrofit `Sendable` conformance (or explicit `where Self: Sendable` bounds on the new async extensions) across the full query-builder type hierarchy and `DatabaseConfigurationProtocol`. Treat this as its own reviewable sub-step of Phase 2 — a "build the whole hierarchy under strict concurrency" spike — not an afterthought discovered while writing the async methods. It is very likely source-affecting for any third-party `TableProtocol` conformer outside this monorepo, in the same category as (but larger than) the `SQLGenDelegate` addition below; call this out explicitly in the changelog.

**`tableStructureCache` note:** this hazard is now fixed independently in Phase 0, before Phase 2 starts — but it's worth restating why Phase 0 had to come first: Phase 2's concurrent dispatch queue is exactly what turns that cache's existing unsynchronized access into routine, not rare, concurrent contention.

### API shape: overload by `async`, don't rename

Swift resolves same-named sync/async overloads by call-site `await` presence — the standard sync→async migration idiom. No new method names for terminal operations:

```swift
public extension Database {
    func transaction<T: Sendable>(isolation: TransactionIsolationLevel? = nil,
                                   _ body: @Sendable @escaping () throws -> T) async throws -> T {
        try await withCRUDExecutor { try self.transaction(isolation: isolation, body) }
    }
}
public extension Selectable {
    func first() async throws -> OverAllForm? { try await withCRUDExecutor { try self.first() } }
}
```

For `Insert`/`Update`/`Delete` (whose sync form runs inside `init`), the async twin is a plain top-level async function with an identical parameter list, also resolved by `await`.

`Select`'s lazy `Sequence` conformance is left alone — rewriting it as `AsyncSequence` means suspending mid-cursor across a raw C statement handle bound to one OS thread, a real correctness hazard. Instead, a new, distinctly-named collecting method:

```swift
public extension Selectable {
    func fetchAll() async throws -> [OverAllForm] { try await withCRUDExecutor { try Array(try self.select()) } }
}
```

This mirrors how GRDB's and SQLAlchemy's async layers actually work — the fetch stays synchronous; only the hop onto/off of the calling task is async.

### Nested transactions, savepoints, isolation level

Track transaction depth **per `Database` value**, not globally — pooled connections must not share depth counters across concurrently-checked-out connections:

```swift
final class CRUDTransactionDepth: @unchecked Sendable {
    private let lock = NSLock()
    private var depth = 0
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; depth += 1; return depth }
    func decrement() { lock.lock(); defer { lock.unlock() }; depth -= 1 }
}
```

`transaction()` becomes depth-aware: `depth == 1` emits `BEGIN`/`COMMIT`/`ROLLBACK` (identical to today's behavior — non-nested call sites are byte-for-byte unchanged); `depth > 1` emits `SAVEPOINT crud_sp_N` / `RELEASE SAVEPOINT` / `ROLLBACK TO SAVEPOINT`. `SAVEPOINT` is standard SQL across MySQL, MariaDB, PostgreSQL, and SQLite (≥3.6.8) — no connector branching needed for nesting itself.

Isolation level *is* connector-specific syntax — one new `SQLGenDelegate` method with a default (non-breaking for existing conformers):

```swift
public protocol SQLGenDelegate {
    func setIsolationLevelSQL(_ level: TransactionIsolationLevel) -> String?
}
public extension SQLGenDelegate {
    func setIsolationLevelSQL(_ level: TransactionIsolationLevel) -> String? { nil }
}
public enum TransactionIsolationLevel: Sendable { case readUncommitted, readCommitted, repeatableRead, serializable }
```

Each connector opts in with its own `SET TRANSACTION ISOLATION LEVEL ...` syntax (MySQL/MariaDB/Postgres); SQLite has no equivalent and stays on the no-op default.

### Files to create/modify

- **Create** `Perfect-CRUD/Sources/PerfectCRUD/AsyncExecution.swift` — `withCRUDExecutor`, `CRUDBlockingQueue`, async overloads
- **Modify** `Perfect-CRUD/Sources/PerfectCRUD/PerfectCRUD.swift` — retrofit `Sendable` across `TableProtocol` and related protocols; add `DatabaseConfigurationProtocol: Sendable`; `setIsolationLevelSQL` default extension
- **Modify** `Perfect-CRUD/Sources/PerfectCRUD/{Table,Where,Join,Select,Insert,Update,Delete}.swift` — `Sendable` conformance on each concrete query-builder type
- **Modify** `Perfect-CRUD/Sources/PerfectCRUD/Database.swift` — `transactionDepth`, savepoint-aware `transaction()` (increment/decrement paired via `defer`, not success-only — see test case below), async overload
- **Modify** all four connectors — implement `setIsolationLevelSQL` (SQLite can skip, using the default); extend the existing `testMySQLConfigurationConformsToSendable`-style generic Sendable check (already present in `MySQLIntegrationTests.swift`) to all four, as a permanent compile-time regression test rather than a one-time manual audit
- **Create** `Perfect-CRUD/Tests/PerfectCRUDTests/Fixtures/StatefulStub.swift` — see shared-fixture note below
- **Create** `Perfect-CRUD/Tests/PerfectCRUDTests/AsyncExecutionTests.swift`, `TransactionNestingTests.swift`
- **Create** `Perfect-SQLite/Tests/PerfectSQLiteTests/TransactionNestingIntegrationTests.swift` — real savepoint-rollback behavior against `SQLiteDatabaseConfiguration(":memory:")`, always available, not gated behind an env var (see testing approach below)
- **Modify** `Perfect-NIO/Sources/PerfectNIOCRUD/RouteCRUD.swift` — no change strictly required; a follow-up doc note once Phase 2 ships

### A shared stateful stub is a deliverable, not a one-line aside

**Added after review.** The plan originally treated "Phase 3 needs a stateful stub" as a bullet in a files list. It's bigger than that: faking a *typed* row store means implementing `next<A: CodingKey>() throws -> KeyedDecodingContainer<A>?` (a real `KeyedDecodingContainerProtocol` conformance — the existing `DynamicStubExeDelegate` dodges this by only ever returning `nil` for the dynamic-row path). Build one reusable fixture — `Fixtures/StatefulStub.swift` — before Phase 2/3 test-writing starts, shared by both. Scope it to exactly what `DatabaseMigrator`/transaction tests actually need: `create` (no-op), `insert` (append to an in-memory row store), and **unfiltered** `select` (return all rows) — no WHERE-clause interpreter, since neither consumer's code ever filters.

### Testing approach

Swift Testing. Cases, revised for determinism and correct scope per review:

- **Savepoint SQL shape** (PerfectCRUD-level, no new stub needed): assert `SAVEPOINT crud_sp_N`/`RELEASE SAVEPOINT`/`ROLLBACK TO SAVEPOINT` emitted at the right depths and `BEGIN`/`COMMIT` only at depth 1, via the existing `StubConfig.capturedSQL` mechanism already in `PerfectCRUDTests.swift`.
- **Savepoint rollback behavior** (real, not stubbed — a stub can only prove PerfectCRUD emitted the right SQL string, not that a rollback actually undoes writes, which is database-engine behavior): a `Perfect-SQLite` integration test using `SQLiteDatabaseConfiguration(":memory:")`, fast and always available.
- **Transaction-depth self-healing**: after a failed inner (savepoint-level) transaction, a subsequent top-level transaction on the *same* `Database` value still emits plain `BEGIN`, not `SAVEPOINT` — proves increment/decrement is `defer`-paired correctly, not success-path-only.
- **Off-cooperative-pool proof**: don't infer from `Thread.current` (weak signal — the cooperative pool and a `DispatchQueue`-backed queue can share an OS thread by coincidence). Instead spy on `CRUDBlockingQueue`/`withCRUDExecutor` directly (a call counter or wrapper) to prove the job was actually routed through it.
- **Cancellation doesn't leak a slot**: `await` the cancelled task directly (`#expect(throws:)` on it, or a `do`/`catch` around `await task.value`) rather than racing a timer.
- Isolation-level SQL only emitted at `depth == 1`; async and sync call sites on the same method name both compile and dispatch correctly (a compile-time check suffices — call-site `await` presence resolves overload ambiguity unambiguously, no runtime test needed).
- Add `.timeLimit(.minutes(1))` (not `.seconds()` — Swift Testing only accepts `.minutes()` at that granularity) to concurrency-sensitive tests, since a real bug here is more likely to hang than fail cleanly.
- **Do not rely on `.serialized` for isolation** — it only serializes cases of a *parameterized* test, a no-op for ordinary `@Test` functions (both existing `PerfectCRUDTests.swift` and `PerfectSQLiteTests.swift` already use it this way without effect). Give each new test its own fresh pool/`Database`/config instance instead, matching the existing `makeDB()`-per-test pattern that already does this correctly.
- New env-var-gated tests use Swift Testing's `.enabled(if:)` trait (already the pattern in `GenericCatalogFixtureTests.swift`/`DynamicMySQLTests.swift`), not the older `guard ... else { return }` pattern still used in `MySQLIntegrationTests.swift` (an XCTest file) — a skipped-via-guard test reports as *passed*, hiding the difference between "ran and passed" and "silently did nothing." This applies even where a new test lands inside a currently-XCTest file.
- Migration/transaction bookkeeping errors are `CRUDSQLGenError` (the codebase's existing string-message error type) — state this explicitly so tests assert on a specific type/message rather than a bare `catch`.

### Risks / open questions

- Sendability retrofit (above) is now scoped as required Phase-2 work, not a downstream risk — tracked as its own sub-step rather than left implicit.
- The continuation-based design (primary) still can't interrupt work already in flight — documented above as a hard limitation, not a bug to fix.
- `CRUDBlockingQueue`'s queue is unbounded/elastic and currently separate from Phase 1's pool-internal queue — worth deciding whether they should share one bounded queue (sized to roughly `maxConnections` across active pools) as a fast-follow, so the two phases' concurrency limits stay coherent. Also loses Task-priority propagation (a `.userInteractive` and a `.background` caller land on the same QoS) — bundle into the same fast-follow.
- The `SQLGenDelegate` addition (`setIsolationLevelSQL`) is a standard non-breaking Swift idiom (new protocol requirement + same-module default extension) — the original draft's "technically source-breaking" framing was checked against this ecosystem's actual conformers and found overstated: none of the four shipped connectors, Perfect-Session, or the Lasso Adapter implement `SQLGenDelegate` in a way this would affect. State it as non-breaking-by-design in the changelog, not "technically breaking but low risk."
- **Phase 1 alone does not fully address the ADR's top blocking-thread concern.** If Phase 1 ships before Phase 2 and pooled-route callers still use today's synchronous CRUD methods inside `withConnection`'s body, queries still run on whatever executor invoked them — the same cooperative-pool hazard as today, just now wrapped in an actor checkout. Both phases are needed together for the ADR's core risk to actually be resolved; document this so "Phase 1 shipped" isn't read as "blocking-thread risk addressed."

---

## Phase 3 — Real Migrations

### Design: `DatabaseMigrator<C>`, layered above `reconcileTable`, not replacing it

```swift
public struct CRUDMigrationRecord: Codable, TableNameProvider {
    public static let tableName = "perfectcrud_migrations"
    public var identifier: String
    public var appliedAt: Date
}

public final class DatabaseMigrator<C: DatabaseConfigurationProtocol>: @unchecked Sendable {
    public struct Migration: Sendable {
        public let identifier: String
        public let up: @Sendable (Database<C>) throws -> Void
        public let down: (@Sendable (Database<C>) throws -> Void)?
    }
    public init()
    public func register(_ identifier: String,
                          up: @escaping @Sendable (Database<C>) throws -> Void,
                          down: (@Sendable (Database<C>) throws -> Void)? = nil) throws
    @discardableResult
    public func migrate(_ db: Database<C>) throws -> [String]
    @discardableResult
    public func rollbackLast(_ db: Database<C>) throws -> String
}
```

`migrate(_:)` creates the tracking table via the same `db.create(_:policy:)` path every other model uses, then applies each not-yet-recorded migration, each inside its own transaction:

```swift
public func migrate(_ db: Database<C>) throws -> [String] {
    try db.create(CRUDMigrationRecord.self, policy: .shallow)
    let applied = Set(try db.table(CRUDMigrationRecord.self).select().map(\.identifier))
    var newly: [String] = []
    for m in migrations where !applied.contains(m.identifier) {
        try db.transaction {
            try m.up(db)
            try db.table(CRUDMigrationRecord.self).insert(.init(identifier: m.identifier, appliedAt: Date()))
        }
        newly.append(m.identifier)
    }
    return newly
}
```

**Coexistence with `reconcileTable`, concretely:** individual migrations are free to call `db.create(Model.self, policy: .reconcileTable)` for simple additive column changes, or drop to `db.sql("ALTER TABLE ...")` for anything `reconcileTable` can't express (e.g. changing a column's type) — both run through the unmodified connector seam. No changes to `getCreateTableSQL`/`getCreateIndexSQL` are required; the migrator is purely additive orchestration.

**Ordering:** registration order determines execution order — not a lexical/timestamp sort — matching GRDB's actual behavior and avoiding a naming-convention footgun. Convention (documented, not enforced): date-prefixed identifiers like `"2026_07_create_posts"`.

**Should-have, not v1-blocking:** a safety check at the top of `migrate(_:)` verifying every already-applied identifier still appears in the currently-registered list, in the same relative order — catches a deleted/reordered shipped migration before it silently no-ops or double-applies.

### Files to create/modify

- **Create** `Perfect-CRUD/Sources/PerfectCRUD/Migration.swift`
- **Create** `Perfect-CRUD/Tests/PerfectCRUDTests/MigrationTests.swift` — reuses the shared `Fixtures/StatefulStub.swift` built in Phase 2 (create/insert/unfiltered-select is exactly what `migrate()`'s bookkeeping needs; no new stub work required here if Phase 2 built it as scoped)
- **Create** `Perfect-SQLite/Tests/PerfectSQLiteTests/MigrationIntegrationTests.swift` — real DDL against `SQLiteDatabaseConfiguration(":memory:")`
- **Documentation**: `Perfect-CRUD/Documentation/migrations.md`

### Testing approach

Swift Testing. Bookkeeping unit tests (registration-order application, duplicate-identifier rejection, already-applied filtering, `rollbackLast` without a `down` throws), plus: out-of-"logical"-order registration still applies in registration order; partial-apply-then-resume (fresh migrator against a DB with 2 of 5 already recorded); rollback against the SQLite integration target; failure-mid-migration rolls back its own transaction and leaves no tracking row (so a retry re-attempts it). Migration bookkeeping errors are `CRUDSQLGenError`, consistent with Phase 2 — assert on the specific type/message, not a bare `catch`.

### Risks / open questions

- **Concurrent-migrator race** on network DBs: multiple app-server instances calling `migrate()` at startup will race on tracking-table creation and on applying the same migration twice. **v1 recommendation: document "run `migrate()` from exactly one process/deploy step, not from every server instance's own startup path."** DB-level advisory locking is a named future enhancement, not built now.
- Down-migrations are opt-in, never inferred — auto-generating a reverse of an arbitrary `ALTER`/`DROP` is unsafe. Consistent with the ADR's "no magic" stance.
- Fixed tracking-table name (`perfectcrud_migrations`) could collide with an app's own table — low risk; worth a startup-time shape check.

---

## Phase 4 — Relationship Ergonomics (light outline)

1. **Fix the MySQL/MariaDB `@ForeignKey` DDL gap first** (see top of this document) — a real bug, not just missing coverage.
2. Per-connector integration tests with a real parent/child pair and `@ForeignKey(Parent.self, onDelete: cascade, onUpdate: restrict)`, asserting generated DDL and that delete/update actions actually fire.
3. Only after that: evaluate optional eager-load sugar over the existing join machinery — kept SQL-transparent (expands to existing join SQL at query-build time, never a runtime lazy fetch), per the ADR's anti-N+1 stance. Genuinely optional — the ADR only commits to "evaluate."

## Phase 5 — Admin-Console Integration (light outline)

Integration point: `AdminConsoleDelegate` in `Perfect-NIO/Sources/PerfectAdminConsole/` — confirmed fully `async` end-to-end already, and currently has zero `import PerfectCRUD`, so this integration point genuinely doesn't exist yet. Add a new delegate method (e.g. `registeredModels() async -> [ModelInfo]`, default `[]`, additive like every other delegate method) wrapping a type-erased `CRUDTableStructure` — already computed once per type and cached (`tableStructureCache`, hardened in Phase 0). Row operations dispatch through `DynamicQuery`/`DynamicMutation` rather than requiring hand-wired per-model routes, since the console can't know model types at compile time.

**`tableStructureCache` hardening is already handled by Phase 0** — no longer a Phase 5 prerequisite in its own right.

**Hard-gated on Phase 2, not just "lower priority" (added after review).** If this phase's `DynamicQuery`/`DynamicMutation` dispatch is built before Phase 2 lands, every admin-console CRUD panel action becomes a call site that blocks NIO's cooperative pool on synchronous C-library calls — expanding, not just perpetuating, the exact exposure the ADR names as its top concern, and doing so on a code path (a live production operator UI) where blocking is especially visible and costly. Do not start this phase's implementation until Phase 2 has shipped.

## Phase 6 — Lifecycle Hooks / Validation (light outline, deferred pending demand)

Per the ADR, not built speculatively. If demand appears: strictly opt-in via explicit protocol conformance on the model type (e.g. `protocol CRUDBeforeInsert { func beforeInsert() throws }`, checked with `as?` at `Insert`/`Update`/`Delete` init call sites) — never an implicit signal/callback registry, to avoid the Django-signals/ActiveRecord-fat-model failure mode.

## Phase 7 — folded into Phase 2

Nested-transaction/savepoint support and isolation-level control are specified under Phase 2 above — not a separate phase.

---

## Cross-cutting notes

- **Revised phase ordering, per review**: **Phase 0 (fix `tableStructureCache`) first, standalone, before anything else** — it's a live bug today, not a phased risk. Then **Phase 1 and Phase 2 share a blocking-dispatch helper** (Phase 1's pool needs safe blocking connection-creation just as much as Phase 2's query execution does) — build that helper once, consume it from both; they're not fully order-independent the way the original draft assumed, though either can lead once the helper exists. Phase 3's `migrate()` uses `db.transaction {}` for atomicity and works fine against today's synchronous `transaction()`, gaining savepoint-safety "for free" once Phase 2 ships — it doesn't strictly require Phase 2 first. **Phase 5 is hard-gated on Phase 2 completing**, not merely sequenced after it by priority (see Phase 5 above) — its dynamic dispatch would otherwise expand the exact blocking-thread exposure Phase 2 exists to close, on a highly visible admin-console path.
- **Branch convention:** each phase lands on its own feature branch off `main`, per established project practice.
- **Working clone for implementation:** all coding for these phases happens in a dedicated fresh clone — `/Users/timtaplin/Perfect-Resurrection/Perfect-CRUD-orm-roadmap/` — kept separate from the docs working copy that authored this ADR. Before starting each new phase's branch, sync that clone's `main` first: `git checkout main && git pull origin main && git checkout -b <phase-branch-name>`. Do not branch off a stale local `main` or off another phase's unmerged branch.
- **Every new public surface is additive** — new files, new methods/overloads distinguished by label or `async`, protocol extensions with defaults for existing conformers. None of Phases 1-4 requires a breaking change to `Database<C>`, `Table<A,C>`, `SQLGenDelegate`, `SQLExeDelegate`, or `DatabaseConfigurationProtocol`'s existing members — the one addition worth double-checking is the `Sendable` retrofit across the query-builder hierarchy (Phase 2), which is source-affecting for third-party `TableProtocol` conformers outside this monorepo, unlike everything else in this list.
- **Testing conventions, established here for all new tests across every phase**: Swift Testing throughout (even for new tests landing in currently-XCTest files like `MySQLIntegrationTests.swift`); env-var-gated tests use `.enabled(if:)`, never `guard ... else { return }` (the latter reports skipped as passed); do not rely on `.serialized` for isolation on non-parameterized tests — give each test fresh instances instead; concurrency-sensitive tests get `.timeLimit(.minutes(1))` and prove thread/executor routing via a spy/counter, never `Thread.current` inference. Consider introducing `@Tag(.live)` (not used anywhere in the ecosystem yet) on this batch of new live-DB integration tests, so CI can filter fast/free tests from real-DB ones without memorizing which env var gates which package.
