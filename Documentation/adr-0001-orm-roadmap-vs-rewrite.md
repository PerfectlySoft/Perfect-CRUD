# ADR-0001: PerfectCRUD Roadmap — Evolve In Place vs. Ground-Up Rewrite

**Status:** Proposed
**Date:** 2026-07-26
**Deciders:** Tim Taplin

## Context

PerfectCRUD is the ORM underpinning the Perfect ecosystem's database access — used directly or transitively by Perfect-Session, Perfect-NIO's `PerfectNIOCRUD` bridge, PerfectTemplate, and the Lasso Adapter project. It's a simple, Codable-driven, connector-agnostic library with zero external dependencies.

The Perfect ecosystem's stated priorities, in order, are: **(1) Swift-native, (2) ease of use for developers, (3) flexibility, (4) robust stability, (5) performance.**

The question on the table: developers coming to Perfect from other Swift ORMs (Fluent, GRDB, SwiftData) and from other-language ecosystems (SQLAlchemy/Django, Prisma/TypeORM/Drizzle, ActiveRecord) will bring expectations PerfectCRUD doesn't fully meet today. Does closing that gap require a ground-up new ORM library, or can PerfectCRUD evolve to meet it?

This ADR is grounded in two pieces of research conducted 2026-07-26:

1. A direct codebase audit of PerfectCRUD (`Perfect-CRUD/Sources/PerfectCRUD/**`, all 20 source files) and PerfectNIO's `PerfectNIOCRUD` bridge, cross-checked against PerfectTemplate's real usage.
2. A survey of the competitive landscape: Swift-native ORMs (Vapor Fluent, GRDB.swift, SwiftData) and cross-ecosystem ORMs (SQLAlchemy 2.0, Django ORM, Prisma, TypeORM, Drizzle, ActiveRecord), focused on what makes each one "sticky" for adopters and what developers commonly criticize about them.

### What the audit found already works

- A typed KeyPath query builder: select/where/join (parent-child, many-to-many via junction table, self-joins)/order/limit, plus six custom `LIKE` operators.
- A newer dynamic/runtime query layer (`DynamicQuery`/`DynamicMutation`/`DynamicSQL`) — a connector-agnostic escape hatch for ad-hoc field selection, mutation, and raw SQL, all still parameter-bound (not string-interpolated) for injection safety.
- A clean three-protocol connector seam (`DatabaseConfigurationProtocol` / `SQLGenDelegate` / `SQLExeDelegate`) that already spans MySQL, PostgreSQL, SQLite, and MariaDB with zero PerfectCRUD-side dependencies.
- Basic transactions (`BEGIN`/`COMMIT`/`ROLLBACK` wrapping a closure).
- Schema definition purely from `Codable` conformance — no macros, no separate DSL, table/column names derived automatically or overridden via `TableNameProvider`/`CodingKeys`.

### What the audit found missing or weak

- **No connection pooling.** `PerfectNIOCRUD.Routes.db()`/`.table()` re-evaluate their connection-provider closure on every request (`RouteCRUD.swift:26-47`); `PerfectTemplate`'s `makeDB()` explicitly creates a new connection per call. This is the single largest gap versus every competitor surveyed.
- **Fully synchronous execution wrapped inside async handlers**, not native async/await. No `async`/`await` exists anywhere in PerfectCRUD's query/execution path. A slow query blocks a cooperative-thread-pool thread inside NIO. Every current-generation competitor (Fluent, GRDB 7, SQLAlchemy 2.0 async) is async-native top to bottom.
- **No real migration system.** Only `TableCreatePolicy.reconcileTable`, a boot-time schema diff that can add/remove columns but cannot alter a column's type, with no versioned history, no up/down scripts, no audit trail.
- **Transactions have no nesting/savepoints or isolation-level control.**
- **`@ForeignKey` is declared but unused** — zero call sites or tests in the repo.
- **No lifecycle hooks or validation callbacks.**
- Joins are read-only: the README states plainly that joins aren't supported in updates/inserts/deletes, and there's no cascade-delete support.

### What the competitive research found

- Swift developers in 2026 expect, by default: async/await-native APIs top to bottom, a declarative model-definition style with `Sendable`/`Codable` for free, a versioned migration system, a chainable type-safe query builder with a raw-SQL escape hatch, and relationship declarations with an explicit eager-load path. GRDB's `ValueObservation` (reactive queries) is an emerging expectation beyond that baseline; SwiftData is Apple-platform-only and not viable for a Linux server target.
- Across other ecosystems, the specific "hook" that converts developers varies: SQLAlchemy's is *never being trapped* (Core is always there as an escape hatch); Django's is *auto-generated admin UI* — cited repeatedly as the single most differentiating feature in that whole survey, with no equivalent in any other ORM covered; Prisma's is compile-time type safety from a schema; Drizzle's is *SQL transparency* with near-zero runtime cost.
- The clearest industry trend in 2025-2026 is a swing **away** from heavy, opaque ORMs and toward SQL-transparent tooling: TypeORM's growth has stalled (attributed to its decorator/reflection-heavy, Hibernate-style design), Drizzle has gained enough momentum that PlanetScale hired its entire core team, and Prisma itself rewrote its architecture specifically to shed weight and "magic" overhead.
- Recurring criticisms to design against: N+1 queries as the default failure mode of any lazy-relationship system; hidden/magic query generation eroding trust; heavy runtime overhead in constrained environments; decorator/reflection metaprogramming aging poorly in a language with strong native structural typing (directly applicable to Swift); convention-driven models/callbacks becoming unmaintainable at scale (Django signals, ActiveRecord "fat models").

## Decision

**Evolve PerfectCRUD in place, through a sequence of additive, seam-level changes — do not undertake a ground-up rewrite.**

The gaps that matter (pooling, async execution, migrations) are solvable without touching PerfectCRUD's public API or its connector abstraction. The architecture that already works (Codable-driven schema, connector-agnostic query generation, a raw-SQL escape hatch that stays injection-safe) is exactly the kind of "not magic, not a trap" design the research shows is winning favor across every ecosystem surveyed right now. A rewrite would put that at risk for no corresponding gain: it would have to re-earn trust from every dependent package (Perfect-Session, PerfectTemplate, the Lasso Adapter) and re-solve a four-database connector abstraction that already works, to fix problems that are actually additive.

This mirrors the reasoning already applied to the Perfect-MySQL → mysql-nio question (see `Perfect-MySQL/Documentation/mysql-nio-integration-plan.md` and its associated findings doc): pooling turned out to be the bigger, more certain win over an async-driver rewrite there too.

## Options Considered

### Option A: Ground-up new ORM library

| Dimension | Assessment |
|-----------|------------|
| Complexity | High — full connector abstraction, query builder, and migration system from scratch |
| Cost | High — 6+ dependent packages need a migration path; duplicated effort re-solving already-working problems (multi-DB SQL generation) |
| Scalability | Unknown until built |
| Team familiarity | Perfect-CRUD's existing design is already well understood; a new design starts from zero |

**Pros:** Clean slate to design async-native from day one; no legacy API constraints.
**Cons:** Highest blast radius in the ecosystem; re-implements a working connector abstraction; the actual gaps (pooling, async boundary, migrations) don't require a rewrite to fix; risks the exact "opaque, over-engineered ORM" backlash the research shows is currently costing TypeORM and pre-rewrite Prisma developer goodwill.

### Option B: Evolve PerfectCRUD incrementally (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium — each phase is additive and independently shippable |
| Cost | Low-medium — no breaking changes to dependent packages required per phase |
| Scalability | Directly addresses the two gaps (pooling, sync execution) most likely to bite under real load |
| Team familiarity | High — same connector seam, same query builder, same conventions |

**Pros:** Lowest risk to the 6+ dependent packages; reuses a connector abstraction that already spans 4 databases; keeps the SQL-transparent, non-magic design the market is currently favoring; each phase ships value independently.
**Cons:** Some technical debt (e.g., the fully-sync execution core) has to be threaded through carefully to stay additive rather than becoming a second breaking rewrite in disguise; less "clean slate" flexibility.

### Option C: Do nothing, adopt Fluent instead

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low upfront, high migration cost |
| Cost | High — would mean abandoning PerfectCRUD across the whole ecosystem, plus adopting a heavier, more opinionated dependency |
| Scalability | Fluent is mature and async-native |
| Team familiarity | Low — new API surface, new conventions, tied to the Vapor ecosystem's assumptions |

**Pros:** Async-native and migrations come for free; large existing community.
**Cons:** Contradicts Perfect's zero-dependency, framework-agnostic posture; abandons a working investment across 6+ packages; adopts exactly the "heavier abstraction" pattern the research shows developers are trending away from; not evaluated further as it wasn't the question asked, but included here for completeness.

## Trade-off Analysis

The deciding factor is where PerfectCRUD's actual weaknesses sit relative to its public API surface. Pooling and async execution are runtime/infrastructure concerns that can be solved *underneath* the existing `Database`/`Table` API without consumers changing a line of code. Migrations can be layered *alongside* the existing `TableCreatePolicy.reconcileTable` as a new, opt-in path. None of this requires touching the query builder, the connector protocols, or the Codable-driven schema model that 6+ packages already depend on.

Weighed against Perfect's priority order — Swift-native, ease of use, flexibility, stability, then performance — a rewrite would spend a large amount of effort re-establishing "Swift-native" and "stability" (a new library needs to prove itself) for gains that are really about "ease of use" (pooling, migrations) that don't require starting over. Incremental evolution serves the priority order more directly: each phase targets one specific ease-of-use or stability gap without putting flexibility or existing stability at risk.

## Consequences

- **Becomes easier:** Adding pooling and true async execution without a breaking API change; onboarding developers who expect migrations; potentially differentiating Perfect via an admin-console integration no competitor offers (see Action Items).
- **Becomes harder:** Nothing structurally — but discipline is required to keep each phase additive rather than letting scope creep turn "add async" into "silently rewrite the execution core." Each phase should be reviewable and shippable independently.
- **Will need to be revisited:** Whether `@ForeignKey`'s dead-code status means it should be exercised/documented or reconsidered; whether demand for lifecycle hooks/validation actually materializes (deliberately deferred — see Action Items — to avoid the Django-signals/ActiveRecord-fat-model failure mode the research flagged).

## Action Items

1. [ ] **Connection pooling** — add a pool primitive wired through `PerfectNIOCRUD.Routes.db()`/`.table()`, replacing per-request connection creation. Highest value, lowest risk; touches no public API.
2. [ ] **Async execution boundary** — offload PerfectCRUD's synchronous calls (thread-pool/`@concurrent`), following the pattern already proven in the Lasso Adapter's async pipeline conversion. Additive wrapper, not a breaking change to the sync core.
3. [ ] **Real migrations** — a GRDB-`DatabaseMigrator`-style versioned migration system (named, ordered, tracked in a system table), layered above the existing `reconcileTable` rather than replacing it.
4. [ ] **Relationship ergonomics** — write tests/examples exercising `@ForeignKey` (currently unused), then evaluate optional eager-load sugar over the existing join machinery — kept SQL-transparent, not a lazy-proxy abstraction.
5. [ ] **Admin-console integration (the differentiator)** — wire PerfectCRUD's existing `CRUDTableStructure` reflection into PerfectAdminConsole for auto-generated per-model CRUD panels. No competitor in the survey (Fluent, GRDB) offers this; Perfect already has the console infrastructure.
6. [ ] **Lifecycle hooks/validation** — defer until real demand appears; if built, keep strictly opt-in via explicit protocol conformance, not implicit signal/callback dispatch.
7. [ ] Nested-transaction/savepoint support and isolation-level control — fold into the async-execution phase (Action Item 2) since both touch the same transaction code path.
