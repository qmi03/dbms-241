= Concurrency control <concurrency>

== Problems with concurrent execution

=== Lost update problem (write - write conflict)

=== Dirty read problem (write - read conflict)

=== Unrepeatable read problem (write - read conflict)


== PostgreSQL

PostgreSQL uses Multi-version Concurrency Control (MVCC) to maintain data consistency. Each SQL statement sees a snapshot of data as it was some time ago, regardless of the current state of the underlying data. This provides transaction isolation by preventing statements from viewing inconsistent data produced by concurrent transactions performing updates on the same data rows.

=== Transaction Isolation

#figure(caption: "Isolation level in PostgreSQL")[
  #table(
    columns: (auto, auto, auto, auto, auto),
    inset: 10pt,
    align: horizon,
    table.header(
      [*Isolation level*], [*Dirty read*], [*Non-repeatable read*], [*Phantom read*], [*Serialization anomaly*],
    ),
    [`READ UNCOMMITTED`], [Not possible], [Possible], [Possible], [Possible],
    [`READ COMMITTED`], [Not possible], [Possible], [Possible], [Possible],
    [`REPEATABLE READ`], [Not possible], [Not possible], [Not possible in PostgreSQL], [Possible],
    [`REPEATABLE READ`], [Not possible], [Not possible], [Not possible], [Not possible],
  )
]


==== Read Committed Isolation Level

==== Repeatable Read Isolation Level

==== Serializable Isolation Level

=== Explicit Locking

==== Table-level Locks

==== Row-level Locks

==== Page-level Locks

==== Deadlocks

==== Advisory Locks

=== Data Consistency Checks at the Application Level

==== Enforcing Consistency with Serializable Transactions

==== Enforcing Consistency with Explicit Blocking Locks

=== Serialization Failure Handling

=== Caveats

=== Locking and Indexes