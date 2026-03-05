import gleam/list

type Id =
  Int

type Record(a) =
  #(Id, a)

pub type Table(a) {
  Table(incrementer: Id, records: List(Record(a)))
}

/// Returns an empty table.
pub fn new() {
  Table(1, [])
}

/// Returns a record by id.
pub fn get(table: Table(a), id: Id) {
  table.records
  |> list.filter(fn(record) { record.0 == id })
  |> list.first()
}

/// Returns the first record matching a selector function.
pub fn get_by(table: Table(a), selector: fn(a) -> Bool) {
  table.records
  |> list.filter(fn(record) { selector(record.1) })
  |> list.first()
}

/// Inserts a record and returns the updated table and inserted tuple.
pub fn insert(table: Table(a), record: a) {
  let new_record = #(table.incrementer, record)

  #(Table(table.incrementer + 1, [new_record, ..table.records]), new_record)
}

/// Replaces a record by id.
pub fn update(table: Table(a), id: Id, record: a) {
  let new_record = #(id, record)

  let records =
    list.map(table.records, fn(existing_record) {
      case existing_record.0 == id {
        True -> new_record
        False -> existing_record
      }
    })

  Table(table.incrementer, records)
}

/// Deletes a record by id.
pub fn delete(table: Table(a), id: Id) {
  let records =
    list.filter(table.records, fn(existing_record) { existing_record.0 != id })

  Table(table.incrementer, records)
}
