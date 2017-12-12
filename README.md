# PerfectSwORM

SwORM is an object-relational mapping (ORM) system for Swift 4+. SwORM takes Swift 4 `Codable` types and maps them to SQL database tables. SwORM can create tables based on `Codable` types and perform inserts and updates of objects in those tables. SwORM can also perform selects and joins of tables, all in a type-safe manner.

SwORM is designed to be light-weight and has zero additional dependencies. Database client library packages can add SwORM support by implimenting a few protocols. These protocols allow SwORM to operate with the client libraries in a generic way. Support is available for [SQLite](https://github.com/kjessup/Perfect-SQLite) and [Postgres](https://github.com/kjessup/Perfect-PostgreSQL).

## General Usage

SwORM usage begins by creating a database connection. The inputs for connecting to a database will differ depending on your client library. These examples will use SQLite for demonstration purposes.

Create a `Database` object by providing a configuration.

```swift
let db = Database(configuration: try 
	SQLiteDatabaseConfiguration(testDBName))
```

Database objects are used to create or access tables.

```swift
// ensure the table has been initialized
try db.create(TestTable1.self, policy: .dropTable)
// get the table
let table = db.table(TestTable1.self)
```

Table objects can be used to `insert`, `update`, and `delete` objects, or to construct more complex queries and then `select` a result set.

```swift
let newOne = TestTable1(id: 2000, name: "New One", integer: 40, 
	double: nil, blob: nil, subTables: nil)
// insert a new object
try table.insert(newOne)
```

```swift
// create a join with a where clause
let query = try table
		.order(by: \TestTable1.name)
	.join(\.subTables, on: \.id, equals: \.parentId)
		.order(by: \TestTable2.id)
	.where(\TestTable1.id == .integer(2000) && 
		\TestTable2.name == .string("Me"))
```

The query has not been executed yet, but `select` can be called to return an iterable object containing all of the found items.

```swift
// iterate through found objects
for row in try query.select() {
	let thisId = row.id
	...
}
// the query can execute multiple times
let foundCount = try query.count()
// select results can use map, filter, etc.
let foo = try query.select().map { ... }
```

## Codable Types

Any `Codable` type can be used with SwORM, often, depending on your needs, with no modifications. All of a type's relevant properties will be mapped to columns in the database table. You can customize the column names by adding a `CodingKeys` property to your type. 

By default, the type name will be used as the table name. To customize the name used for a type's table, have the type implement the `TableNameProvider` protocol. This requires a `static let tableName: String` property.

SwORM supports the following property types:

* All Ints, Double, Float, Bool, String
* [UInt8], [Int8], Data
* Date, UUID

The actual storage in the database for each of these types will depend on the client library in use. For example, Postgres will have an actual "date" and "uuid" column types while in SQLite these will be stored as strings.

A type used with SwORM can also have one or more arrays of child, or joined types. These arrays can be populated by using a `join` operation in a query. Note that a table column will not be created for joined type properties.

The following example types illustrate valid SwORM `Codables` using `CodingKeys`, `TableNameProvider` and joined types.

```swift
struct TestTable1: Codable, TableNameProvider {
	enum CodingKeys: String, CodingKey {
		// specify custom column names for some properties
		case id, name, integer = "int", double = "doub", blob, subTables
	}
	// specify a custom table name
	static let tableName = "test_table_1"
	
	let id: Int
	let name: String?
	let integer: Int?
	let double: Double?
	let blob: [UInt8]?
	let subTables: [TestTable2]?
}

struct TestTable2: Codable {
	let id: UUID
	let parentId: Int
	let date: Date
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}
```

Joined types should be an Optional array of Codable objects. Above, the `TestTable1` struct has a joined type on its `subTables` property: `let subTables: [TestTable2]?`. Joined types will only be populated when the corresponding table is joined using the `join` operation.

### Identity

All SwORM Codable types should have an `id` column. When SwORM creates the table corresponding to a type it needs to know what the primary key for the table will be. You can explicitly indicate which property is the primary key when you call the `create` operation. If you do not indicate the key then a property named "id" will be sought. If the key can not be found an error will be thrown.

Note that a custom primary key name can be specified when creating tables "shallow" but not when recursively creating them. See the "Create" operation for more details.

## Operations

Activity in SwORM is accomplished by obtaining a database connection object and then chaining a series of operations on that database. Some operations execute immediately while others (select) are executed lazily. Each operation that is chained will return an object which can be further chained or executed.

Operations are grouped here according to the objects which impliment them. Note that many of the type definitions shown below have been abbreviated for simplicity and some functions implimented in extensions have been moved in to keep things in a single block.

### Database

A Database object wraps and maintains a connection to a database. Database connectivity is specified by using a `DatabaseConfigurationProtocol` object. These will be specific to the database in question.

```swift
// postgres sample configuration
let db = Database(configuration: 
	try PostgresDatabaseConfiguration(database: postgresTestDBName, host: "localhost"))
// sqlite sample configuration
let db = Database(configuration: 
	try SQLiteDatabaseConfiguration(testDBName))
```

Database objects implement this set of logical functions:

```swift
public struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	public typealias Configuration = C
	public let configuration: Configuration
	public init(configuration c: Configuration)
	public func table<T: Codable>(_ form: T.Type) -> Table<T, Database<C>>
	public func transaction<T>(_ body: () throws -> T) throws -> T
	@discardableResult
	public func create<A: Codable>(_ type: A.Type, 
		primaryKey: PartialKeyPath<A>? = nil, 
		policy: TableCreatePolicy = .defaultPolicy) throws -> Create<A, Self>
}
```

The operations available on a Database object include `transaction`, `create`, and `table`. 

#### transaction

The `transaction` operation will execute the body between a set of "BEGIN" and "COMMIT" or "ROLLBACK" statements. If the body completes execution without throwing an error then the transaction will be committed, otherwise it is rolled-back.

```swift
try db.transaction {
	... further opertions
}
```

#### create

The `create` operation is given a Codable type. It will create a table corresponding to the type's structure. The table's primary key can be indicated as well as a create policy which determines some aspects of the create. 

`TableCreatePolicy` consists of the following options:

* .shallow - If indicated, then joined type tables will not be automatically created. If not indicated then any joiuned type tables will be automatically created. They will have the default primary key of "id".
* .dropTable - The database table will be dropped before it is created.
* .reconcileTable - If the database table already exists then any columns which differ between the type and the table will be either removed or added.

Calling create on a table which already exists is a harmless operation resulting in no changes unless the `.reconcileTable` or `.dropTable` policies are indicated.

#### table

The `table` operation returns a Table object based on the indicated Codable type. Table objects are used to perform further operations.

```swift
let table1 = db.table(TestTable1.self)
```

### Table

A Table object can be used to perform updates, inserts, deletes or select queries. Tables can only be accessed by providing the Codable type which is to be mapped. Tables indicate the over-all resulting type of any operation (referred to as the *OverAllForm*).

```swift
public struct Table<A: Codable, C: DatabaseProtocol>: TableProtocol, JoinAble, SelectAble, WhereAble, OrderAble, UpdateAble, DeleteAble, LimitAble {
	public typealias OverAllForm = A
	public typealias Form = A
	public var databaseConfiguration: DatabaseConfigurationProtocol { return database.configuration }
	
	// update - UpdateAble
	@discardableResult
	public func update(
		_ instance: OverAllForm, 
		setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	public func update(
		_ instance: OverAllForm, 
		ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	
	// insert - InsertAble
	@discardableResult
	public func insert(_ instances: [Form]) throws -> Insert<Form, Table<A,C>>
	@discardableResult
	public func insert(_ instance: Form) throws -> Insert<Form, Table<A,C>>
	@discardableResult
	public func insert(
		_ instances: [Form], 
		setKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Insert<Form, Table<A,C>>
	@discardableResult
	public func insert(
		_ instance: Form, 
		setKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Insert<Form, Table<A,C>>
	@discardableResult
	public func insert(
		_ instances: [Form], 
		ignoreKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Insert<Form, Table<A,C>>
	@discardableResult
	public func insert(
		_ instance: Form, 
		ignoreKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Insert<Form, Table<A,C>>
	
	// delete - DeleteAble
	@discardableResult
	public func delete() throws -> Delete<OverAllForm, Self>
	
	// join - JoinAble
	public func join<NewType: Codable, KeyType: Equatable>(
		_ to: KeyPath<OverAllForm, [NewType]?>,
		on: KeyPath<OverAllForm, KeyType>,
		equals: KeyPath<NewType, KeyType>) throws -> Join<OverAllForm, Self, NewType, KeyType>
		
	// order - OrderAble
	public func order(by: PartialKeyPath<Form>...) -> Ordering<OverAllForm, Self>
	public func order(descending by: PartialKeyPath<Form>...) -> Ordering<OverAllForm, Self>
	
	// where - WhereAble
	public func `where`(_ expr: Expression) -> Where<OverAllForm, Self>
	
	// limit - LimitAble
	public func limit(_ max: Int = 0, skip: Int = 0) -> Limit<OverAllForm, Self>
	
	// select - SelectAble
	public func select() throws -> Select<OverAllForm, Self>
	public func count() throws -> Int
}
```

Table can follow: `Database`.

Table supports: `update`, `insert`, `delete`, `join`, `order`, `limit`, `where`, `select`, `count`.

### Join

A `join` operation represents a set of objects from another table which will be selected along with the main over-all type. 

Join can follow: `table`, `order`, `limit`, or another `join`.

### Where

A `where` operation introduces a criteria which will be used to indicate exactly which objects should be selected or updated from the database. Where can be used when performing a select or an update.

### Order

An `order` operation introduces an ordering of the over-all resulting objects and/or of the objects selected for a particular join. An order operation should immediately follow either a `table` or a `join`.

### Limit

A `limit` operation can follow a `table`, `join`, or `order` operation. Limit can both apply an upper bound on the number of resulting objects and impose a "skip" value. For example the first five found records may be skipped and the result set will begin at the sixth row.

### Update

An `update` operation can be used to replace values in existing records. An `update` can follow a `table` operation. It can also follow a `where` operation if that `where` follows a `table`.

### Insert

An `insert` operation can follow a `table`. Insert is used to add new records to the database.

### Delete

A `delete` can follow a `table` operation. It can also follow a `where` operation if that `where` follows a `table`.

### Select

A `select` operation can follow a `where`, `order`, `limit`, `join`, or `table` operation. Select returns an object which can be used to iterate over the resulting values.

### Count

A `count` operation can follow a `where`, `order`, `limit`, `join`, or `table` operation. Count works similarly to `select` but it will execute the query immediately and simply return the number of resulting objects.




