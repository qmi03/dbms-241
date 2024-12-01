= Transaction processing

A transaction is a set of database reads and writes that is handled as a unit with a few crucial properties @transaction-manifesto. One such set of properties is ACID. Benefits of transactions @transaction-manifesto:
- Transactions make concurrency simple: Transactions relieve the burden of having to reason about potential interactions between operations from separate operations. The developers can think of transactions as executing sequentially.
- Transactions enable abstraction: _Application-defined_ transactions are composable - the execution of one transaction can’t affect the visible behavior of another. This allows us to mix-and-match transactions, compose transactions inside another, etc.

Transactions main use is maintaining ACID, enabling abstraction to the users so that they won't have to worry about transactions interfering with each other. To maintain ACID, transaction processing needs two subsystems: recovery subsystem and concurrency control subsystem. Because these two subsystems will be covered in more details in the next two chapters, this chapter only provides an overview of activities happening inside a transaction to allows for concurrency control.

== HBase

In HBase, like typical NoSQL DBMS, has very limited transaction support. It does not have a built-in, explicit transactional framework for multi-row or multi-table operations. Each operation in HBase is a transaction itself @hbase-apache-acid. Therefore, there's not much to say about transactions in HBase.

HBase provides *strict concurrency levels*, which means that:
  - All reads immediately see the committed writes.
  - All reads see writes in order of they are committed.
However all of these are guaranteed within a region only. Plus, we have the fact that each operation on a row is transaction (`Get`, `Put`, `Delete`) itself, except for `Scan` as it scans multiple rows and the rows are not guaranteed to be from the same snapshot in time. These two points make concurrency control in HBase significantly simpler: It just needs to lock a row before updating. This lock blocks other concurrent updates on the same row, but doesn't block concurrent reads on the same row - reads don't see uncommitted changed on the rows as HBase uses some kind of *multiversion concurrency control* (MVCC). We'll explore it further and see its in @concurrency.

For recovery, HBase utilizes the *write-ahead log* (WAL). For the same points above, the WAL in HBase is simplistic in both of its structure and associated operations. We'll explore it further in @recovery.

== PostgreSQL

Unlike HBase, transactions is one of the core features of PostgreSQL and facilitate the ACID guarantees. In PostgreSQL, there's a component called the *transaction manager*, which is responsible for ensuring the ACID properties of transactions.

Each transaction can be user-defined by placing a set of operations between `BEGIN` and `END`.

```sql
BEGIN;

--- SQL statements

END;
```

`BEGIN` initiates a transaction block, that is, all statements after a `BEGIN` command will be executed in a single transaction until an explicit `COMMIT` or `ROLLBACK` is given @postgres-doc.

Each transaction can also be started implicitly: By default (without BEGIN), PostgreSQL executes transactions in “autocommit” mode, that is, each statement is executed in its own transaction and a commit is implicitly performed at the end of the statement (if execution was successful, otherwise a rollback is done) @postgres-doc.

Each transaction in PostgreSQL is assigned a unique identifier called `txid` by the *transaction manager* when it starts @interdb. We can query the `txid` of the current transaction like so:

```sql
db=# BEGIN;
BEGIN
Time: 8.349 ms
db=#* SELECT txid_current();
 txid_current
--------------
        30222
(1 row)

Time: 12.288 ms

db=#* END;
COMMIT
Time: 0.152 ms
```

The `txid` is a 32-bit unsigned integer, so it's limited. PostgreSQL reserves the following 3 special `txid`s:
- `0`: Invalid `txid`.
- `1`: Bootstrap `txid`, which is only used in the initialization of the database cluster.
- `2`: Frozen `txid` (to avoid the transaction id wraparound problem - because txid is upper bound).

`txid`s can be compared with each other. PostgreSQL views ordering as circular:

#figure(caption: [`txid` ordering @interdb])[
  #align(center)[
    #image("../images/txid_cycle.png")
  ]
]

- Half the cycle right before the `txid` is in the past and visible.
- Half the cycle right after the `txid` is in the past and invisible.

The "visibility" concept here has to do with how PostgreSQL performs concurrency control and will be explored in @concurrency.

The transaction manager always holds information about currently running transactions.

There are two structures related to transactions & concurrency that PostgreSQL has to maintain: The `CLOG` and the Transaction snapshot. We'll defer it to @concurrency. For now, we note that PostgreSQL uses MVCC for concurrency control.

There are 3 levels of isolation levels that can be specified for transactions in PostgreSQL: `READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`. `READ COMMITTED` is the default isolation level in PostgreSQL. `READ UNCOMITTED` is not present as the MVCC concurrency model that PosgreSQL uses avoids dirty reads by default. See @concurrency. We can specify the isolation level like so (for a single transaction):

```
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Your SQL statements here
COMMIT;
```

We can also specify isolations at the session level:

```
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

For recovery, the PostgreSQL also uses the WAL like HBase, but it's significantly more complex. We'll defer it to @recovery.

