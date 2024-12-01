= Recovery <recovery>

Any software systems can run into failures. DBMS is no exception and failures during a transaction can render the whole database corrupted.

There are many possible reasons why a DBMS may fail:
- Concurrency control: Multiple transactions running concurrently can potentially cause serialization anomalies or deadlocks. In those cases, the recovery subsystem may need to restart some transactions & rollback the database's state into a previous consistent state.
- Software interruption: Users may decide to interrupt a transaction mid-flight. A transaction must be rolled back in this case.
- Power failure: If the system is interrupted while a transaction is running, this would hang the transaction and thus violate the atomicity of transactions. This is one of those failure scenarios that we cannot avoid totally. In this case, the recovery system must either log enough information so that the completed operations can be rolled back or the not-completed operations can be carried on.
- File system/Disk failure: Another scenario where failures cannot be avoided. If the file system or the disk is faulty, any I/O can be unreliable. One way to recover from this is to restore the database state from a previous backup. This is not of ours concern in this section.

This is where recovery comes in: Its main role is to recover the database from a corrupted state.
Specifically, recovery plays an important role in ensuring the ACID properties of transactions, specifically the A (atomicity) and D (durability). Recovery is unavoidable if reliability is to be achieved.

== Recovery in PostgreSQL

Like many other RDBMS, PostgreSQL's main recovery mechanism is via the Write-ahead log (WAL).

=== General WAL concepts

The *WAL file* is an append-only sequential log file residing on disk, typically stored at `$PGDATA/pg_wal`.

When running, the PostgreSQL server also has a *WAL buffer* residing in shared memory to speed up logging. The *WAL buffer* is, at some appropriate time, flushed to the *WAL file*.

#figure(caption: "The WAL buffer & WAL file")[
  #image("/images/WAL.png", height: 300pt)
]

The main idea of WAL is as follows:
- Each operation (in many cases, not all types of operations) in a transaction is logged to the WAL buffer.
- Before the data files are modified by an operation, the WAL record of that operation has to be written to the WAL buffer first. Only after the record has been written can the operation commence.
- A WAL record contain enough information so that its corresponding operation can be redone or rolled back idempotently (meaning that if we redo/rollback the same operation many times, we'll see the effect of redoing/rolling back exactly once).
- Before a transaction commits, the WAL buffer must be flushed to the WAL file first. @interdb

Therefore, the WAL file completely captures at a moment in time which transactions are running & which operations have been or have not been done. If a crash happens, the database server can reload the WAL and replaying or rolling back to a consistent state.

Why does the WAL buffer has to be flushed to disk first before a transaction commits? To enforce Durability. Imagine after a transaction successfully commits, a power failure happens while the WAL is not flushed to disk. Essentially, the commit is lost and the database can only be recovered to a state before the commit happened - so the transaction will seem to have never committed. However, this violates Durability, which mandates that if a transaction has committed, its effect is always visible.

=== WAL structure in PostgreSQL

We'll be concerned of what information is stored in the WAL so that this can be used to recover the database to a consistent state.

In PostgreSQL, The WAL is called a *transaction log*. Logically, a *transaction log* is a virtual file whose bytes can be indexed by an 8-byte address. This means that this virtual file is 2^64 bytes (16 exabytes or 2^34 gigabytes) in size, which is vast enough for any real applications. However, physically, PostgreSQL cannot handle a file this big, so it splits the *transaction log* in chunks of 16 megabytes (by default). Each of these chunks is called a *WAL segment*. @interdb

#figure(caption: "The transaction log structure")[
  #image("/images/transaction log.png")
]

Each WAL segment is stored in a separate disk file @interdb. This file is further divided to pages of 8 kilobytes:
- Each page has a page header.
- The XLOG records are written after the page header.

#figure(caption: "The WAL segment structure")[
  #image("/images/WAL_segment.png")
]

Each XLOG record has a *log sequence number* (LSN) that is the index of the XLOG record in the transaction log. @interdb

The XLOG record comprises a general header portion and each associated data portion. @interdb

The header's most notable fields:
- `xl_xid`: The associated transaction ID.
- `xl_rmid` and `xl_info`: The information related to the resource manager for this record.
  - A resource manager is a collection of operations associated with the WAL feature, such as writing and replaying of XLOG records.
  - In short, these identifies if the XLOG record stands for:
    - A heap operation: `INSERT`, `UPDATE`, etc.
    - An index operation.
    - A transaction operation, like a `COMMIT`.
    - etc.
Therefore, the header completely identifies an operation in a specific transaction.

The data portion is highly dependent on the type of operation the XLOG presents. We just note that the data portion also contains a header and multiple data blocks. Each data block can be a *backup block* (storing an image of a full page of the database) or a *non-backup block*. @interdb

=== Checkpoint

A checkpoint is a special XLOG record that marks the redo point if PostgreSQL is to recover from the WAL.

The latest checkpoint is the redo point.

In PostgreSQL there's a process called the checkpointer, which periodically performs checkpointing:
  1. An XLOG record of this checkpoint is written to the WAL buffer.
  2. All data in shared memory is flushed to the storage.
  3. All dirty pages in the shared buffer pool are gradually written and flushed to the storage.

On recovery from a system failure, PostgreSQL *always rolls forward* from the REDO point and replays all XLOG records from there.

=== Recovery algorithm in PostgreSQL

Assume there's a transaction that inserts a tuple into `TABLE_A` and then commits. Assume that the latest XLOG record corresponding to `TABLE_A` has the log sequence number `LSN_0`.

Here's what happens if the transaction can be completed till end @interdb:

+ Assume the checkpointer performs a checkpoint here.
+ PostgreSQL loads the `TABLE_A` page into the shared buffer pool in RAM.
+ PostgreSQL inserts a tuple into the page.
+ PostgreSQL creates and inserts an XLOG record of this statement into the WAL buffer at the location `LSN_1`.
+ PostgreSQL updates the `TABLE_A`’s `LSN` from `LSN_0` to `LSN_1`.
+ As this transaction commits, PostgreSQL:
    + Creates and writes an XLOG record of this commit action into the WAL buffer.
    + Writes and flushes all XLOG records on the WAL buffer to the WAL segment file, from `LSN_1`.
    
Assume that there's a power cut just after step 6. This means that:
- In the WAL file, the transaction appears to have committed.
- The shared buffer pool was lost, so the updated table pages are lost.

Here's what PostgreSQL does to recover @interdb:
+ PostgreSQL reads all items in the `pg_control` file - an 8kb binary file that stores information about various aspects of the PostgreSQL server's internal state.
  If the `state` item is `in production`, PostgreSQL enters recovery-mode because this means that the database was not shut down normally.
  If it is `shut down`, PostgreSQL enters normal startup-mode.
+ PostgreSQL reads the latest checkpoint record in the `pg_control` file, which is the redo point.
+ PostgreSQL starts from the redo point (the latest checkpoint in the WAL file), which is at the start of the transaction.
+ PostgreSQL reads the XLOG record of the first `INSERT` statement from the WAL segment file.
+ PostgreSQL loads the `TABLE_A` page from the database cluster into the shared buffer pool.
+ PostgreSQL compares the XLOG record’s LSN with the corresponding page’s LSN.
    The rules for replaying XLOG records are as follows:
    - If the XLOG record’s LSN is larger than the page’s LSN, the data-portion of the XLOG record is inserted into the page, and the page’s LSN is updated to the XLOG record’s LSN.
    - If the XLOG record’s LSN is smaller, there is nothing to do other than to read next WAL record.
+ PostgreSQL replays the remaining XLOG records in the same way, in this case, replays the COMMIT XLOG record.
+ After replaying all XLOG (WAL) records during the recovery process, PostgreSQL checks the state of each transaction. If it encounters a transaction that was incomplete at the time of the crash, PostgreSQL aborts the transaction.
  Because the COMMIT XLOG record is present, the transaction is successful upon recovery
  
=== Summary

+ PostgreSQL has a WAL file which serves as a history of all operations performed in every transaction.
+ In the WAL file, there are multiple checkpoints, the latest of which is the redo point to start recover from.
+ With most operations, PostgreSQL logs them in the WAL file so that they can be replayed upon recovery.
+ If after recovery, the transaction is found to be incomplete, it is rolled back.

== Recovery in HBase

Because HBase is a distributed DBMS, we'll be concerned with 2 problems of recovery:
- How does the cluster recover to a consistent state if one of its data node fails?
- How does a region server recover locally to a consistent state after a failure?

=== How the cluster recovers from a region server's failure

We'll only consider how to recover from a region server's failure because these are where data can be stored. Although the master server may fail, this only causes availability problem & should not corrupt data, therefore, we skip the treatment for this type of failure.

There are some points worth reiterating about the HBase architecture:
- Data are assigned into regions - which is a partition of a table in HBase.
- Regions are further assigned to region servers - which serves all read and write requests for the region.
- By default, region server has no replica. This means that by default, each region is served by exactly one region server.

Although distributed in nature, the fact that each region is stored at one region server means that if one region server fails, the corresponding regions are not available until recovery.

The master server detects a region server failure via Zookeeper. Zookeeper will determine Node failure when it loses region server heartbeats. The master server will then be notified that the region server has failed.

The question here is that if a region is only assigned to one region server and that region server has crashed, how do we retrieve data in that region? In fact, although each region server is the sole server for some regions, HBase typically uses HDFS, which always performs data replication. Therefore, region data are unlikely to be lost. The master server can reassign the replicated region data to other active region servers.

However, there is one point yet to be addressed: What if the crashed server still has unflushed mutations in the Memstore? Each region server actually maintains a WAL file, and like region data, it's written to HDFS and is also replicated. The master will split the WAL file based on regions. Each split of the WAL file is then sent to a new region server that serves the split's region. Each new region server will then replay the WAL split.

The detail of how HBase organizes, maintains and replays WAL is fully treated when we consider the next question.

The remaining sections deal with the local recovery-related activities at each region server.

== Revisit HBase concurrency model

These are the most notable points about the concurrency model of HBase:
- HBase has no mixed read/write transactions @hbase-blogspot.
- HBase provides the strong concurrency level @hbase-doc, which means that all reads always return the latest committed version & the clients can observe changes in the same order as committed writes.
- A transaction is based on a row-by-row basis, for example:
  - A mutation is atomic within a row, even spanning across column families @hbase-apache-acid.
  - All rows returned via any access API will consist of a complete row that existed at some point in the table's history @hbase-apache-acid.
  - A scan is not a consistent view of a table, that is, a mutation during a scan can cause the scan to return mutated rows @hbase-apache-acid.
- HBase does not guarantee any consistency between regions @hbase-apache-acid.

In short, HBase does not guarantee ACID across multiple rows and across multiple operations. Each operation mostly acts like its own transaction. This makes recovery much simpler compared to PostgreSQL.

=== WAL in HBase and how it differs from PostgreSQL

In HBase, the WAL is called a HLog @hbase-gitbook. The HLog in HBase is also an append-only sequential log.

However, there are a few notable differences from the WAL in PostgreSQL:
- HBase only maintains an HLog file, there's no WAL buffer.
- A single record is created for updates. There is no separate commit record.

=== Recovery algorithm in HBase

Assume that we're performing an insert to a row in an HBase table via a `PUT`.

+ The `PUT` is routed to the region server serving the region of the specified row.
+ The region server locks the row to prevent concurrent writes to the same row.  
+ The region server retrieves the current WriteNumber.
+ The region server logs the change to the HLog *on disk*.
+ The region server applies the changes to the MemStore, tagging `KeyValue`s with the retrieved WriteNumber.  
+ The region server commits the transaction by attempting to roll the ReadPoint forward to the acquired WriteNumber.
+ The region server unlocks the row.

Note that the MemStore is in memory and changes to the MemStore is not flushed to disk until it is full. Note that the granularity of transaction in HBase is pretty low - short time between initiation and commit. Therfore, there's no need for an HBase buffer as it would be committed and flushed shortly after that, making the buffer rather less useful. In the same light, due to each operation being essentially its own transaction, there's no commit record as the single HLog record that we write at the start already represents the whole transaction - in another word that HLog record is its own commit record.

=== Summary

+ HLog also resides on disk but not in-memory.
+ For each operation, HBase writes a record to the HLog on disk before making mutations.

== Comparison

The basic idea & operations of WAL are the same in PostgreSQL & HBase:
- There are append-only sequential logs on disk in both PostgreSQL & HBase.
- Before making a mutation to data in an in-memory buffer, it is logged into the WAL first.
- Recovery is done by replaying the records in the WAL file.

However, the WAL and its associated operations in PostgreSQL are far more complex and flexible compared to HBase. Besides recovery, the WAL in PostgreSQL can also be used in continuous archiving, point-in-time recovery, etc.

Nevertheless, in both PostgreSQL and HBase, the main point of the WAL existence is recovery.