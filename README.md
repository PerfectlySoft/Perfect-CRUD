# PerfectSwORM

I've been experimenting with some of the new Swift 4 features to see if they would pull off an ORM closer to (Lasso's) query expressions.

The goals were:
1. Type safe
2. Light weight
3. Using new Codable types to keep usage very simple (i.e. users don't have to do anything on their end to make compatible types)
4. Using KeyPaths for column identification

So far I've been able to coax this syntax out, working, supporting joins, ordering, selects:

```swift
struct TestTable1: Codable {
	enum CodingKeys: String, CodingKey {
		case id, name, integer = "int", double = "doub", blob, subTables
	}
	let id: Int
	let name: String?
	let integer: Int?
	let double: Double?
	let blob: [UInt8]?
	let subTables: [TestTable2]?
}

struct TestTable2: Codable {
	let id: Int
	let parentId: Int
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}

let db = Database(...)			
let j2 = try db.table(TestTable1.self)
			.order(by: \TestTable1.name)
		.join(\.subTables, on: \.id, equals: \.parentId)
			.order(by: \TestTable2.id)
		.where(\TestTable2.name == .string("Me"))
		.select()

j2.forEach { row in
	row.subTables?.forEach {
		sub in
		XCTAssert(sub.id % 2 == 1)
	}
}
```
It's type-safe (you can't specify bogus key paths, except in the `where` clause, which can only be validated at run time), and the package has zero dependencies. The expression system lets you use real Swift operators (>=, !=, etc.) so you aren't specifying conditions as a String. Almost everything is validated at compile time.

I plan to add update/insert/delete and use it on the qBiq project and see where it goes.

(StrongORM seems like a better name now.)
