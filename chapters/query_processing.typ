= Query processing

Every data storage system needs to provide some way for users to specify their data needs, i.e to read/update/insert, on which fields/tables/records, etc. One way to achieve this is through queries - which can be thought as requests to the data storage system. Query processing is the process where these requests are analyzed to figure out how to satisfy those requests and also where these requests are run. 

The way queries are specified varies:
  - In PostgreSQL, we specify data needs via the structured query language (SQL).
  - In HBase, only plain APIs are supported out-of-the-box.

== HBase

By default, the only way to performs queries to HBase is via Java APIs. Although the Apache Hive provides a SQL layer on top of HBase, it's out of scope of this report.

The basic Java APIs for data operations:

- Get: Retrieves a single row or specific columns from a row.
- Scan: Retrieves multiple rows based on a range of keys.
- Put: Insert or updates a single row. Note that there is no API for Insert.
- Delete: Deletes a row, specific columns, or timestamped versions.

What happens when the user calls a Java API? Note that HBase is a distributed DBMS, it needs to locate where a piece of data is stored. In more details:

+ The HBase client library forms a request, which includes:
    - Operation: `Get`, `Put`, `Delete`, or `Scan`.
    - Target: Table, row, region, column.
  This request is serialized into a predefined format.
+ The client contacts the ZooKeeper to locate the meta-information about the requested table, including which region server holds the region for the target row.
+ The client connects directly to the region server hosting the target region for the operation.
+ The region server then reads the request and performs the appropriates operations according to the request.

== Postgres

Query processing in PostgreSQL is more involved, because:
- The SQL interface is a complex language on its own, which demands efforts for parsing.
- The SQL interface is very expressive and more flexible: users can specify whatever shape of data they desire. Therefore, it's more complicated to figure out an efficient way to execute the queries and to actually carry out query execution.

In fact, query processing the most complicated subsystem in PostgreSQL.

Every query issued by a connected client is handled by a type of process call the *backend process* in PostgreSQL. This process consists of 5 subsystems:

#figure(caption: [Query processing phases @interdb])[
  #image("../images/PostgreSQL query processor.png", height: 300pt),
]

+ Parser

  This subsystem's role:
  - Check syntax of the SQL statement in plain text.
  - Generate a *parse tree* from the SQL statement.
  
  Note that this phase does not check for semantics error, for example, selecting from a non-existent table or column.

+ Analyzer

  This subsystem performs *semantic check* from the *parse tree* and generates a *query tree*. To do this, it needs to fetch the metadata about relations in the system catalog.

+ Rewriter

  This phase implements the *rule system* in PostgreSQL. It takes the *query tree* from the analyzer and the *user-defined rules* (in the `pg_rules` system catalog) to rewrite it into another *query tree*.
  
  A rule is simply an instruction on how to rewrite the query tree. Underneath, it's just _another_ *query tree* @postgres-doc.
  
  To illustrate, views in PostgreSQL are implemented using the rule system @postgres-doc @interdb.
  
  For example, a view like:
  
  ```
  CREATE VIEW myview AS SELECT * FROM mytab;
  ```
  
  is very nearly the same thing as:
  
  ```
  CREATE TABLE myview (same column list as mytab);
  CREATE RULE "_RETURN" AS ON SELECT TO myview DO INSTEAD
      SELECT * FROM mytab;
  ```
  
  although you can't actually write that as tables cannot have `ON SELECT` rules.
  
  Therefore, a select from `myview` is rewritten into a select from `SELECT * FROM mytab`.

+ Planner

  This is where the query processor decides on how to execute the queries _efficiently_. To do this, it must consider (almost) all strategies to find the desired records, for example:
  + How to locate the rows satisfying a condition effectively, i.e using index, sequential scan, etc.
  + How to fetch the desired rows efficiently, i.e fetching the table's pages containing the rows or if index-only scan is applicable, fetching the index pages containing the rows.
  + How to sort the rows efficiently if sorting is specified.
  + How to perform joins efficiently if join is specified.
  
  From all of these considerations, the planner chooses the most approximately efficient plan and generates a corresponding plan tree.

+ Executor

  The executor accepts the *plan tree* and executes the query by accessing the tables and indexes in the order that was created by the *plan tree*.

=== Planner: Query optimization

As mentioned, query optimization happens in the planner.

PostgreSQL's query optimization is *cost-based*: there is no rule-based optimization. Besides, there is currently no way to hint a specific plan to PostgreSQL except for using extensions.

==== Terminology

*Cost* in PostgreSQL is:
- A dimensionless value. By default, a page read has a cost of `1`.
- Not an absolute performance indicator.
- Indicator to compare the relative performance of operations.

*Cost* is estimated by predefined functions (i.e. `cost_seqscan`, `cost_index`) using the statistics stored in the system catalog.

There are 3 kinds of costs:
- Startup cost: 
  - The cost expended before the first tuple is fetched.
  -  For example, the start-up cost of the index scan node is the cost of reading index pages to access the first tuple in the target table.
- Run cost: The cost of fetching all tuples.
- Total cost = Startup cost + Run cost.

Example: `0.00` and `145.00` are respectively the start cost and the run cost.
```
db=# EXPLAIN SELECT * FROM tbl;
                       QUERY PLAN                        
---------------------------------------------------------
 Seq Scan on tbl  (cost=0.00..145.00 rows=10000 width=8)
(1 row)
```

==== Cost estimation algorithm

In this section, for simplicity, we'll only illustrate cost estimation algorithm for single-table queries. The planner in PostgreSQL performs 3 steps:
+ Carry out *preprocessing*.
  
  + Simplify the expressions in the SELECT clause, the LIMIT clauses, etc.
  
    For example, constant folding such as rewriting `2 + 2` to `4`.

  + Normalize boolean expressions.
  
    For example, `NOT (NOT a)` is rewritten to `a`.
      
  + Flatten `AND/OR` expressions.
  
    In the SQL standard, `AND` and `OR` are binary operators. In PostgreSQL internals, they are n-ary operators. Therefore, this step transforms the original representation to one that use n-ary versions of `AND` and `OR`.

+ Estimates the costs of all possible access paths and chooses the cheapest one.

+ Create the plan tree from the cheapest access path.

=== Executor: Sequential scan & Index scan & Index-only scan

Scans is a common operation in PostgreSQL, which scans the tuples of a relation searching for a matching tuple based on some conditions.

A sequential scan is the simplest scan. It simply scan the table page by page, tuples by tuples.
```
db=# EXPLAIN SELECT * FROM tbl;
                       QUERY PLAN                        
---------------------------------------------------------
 Seq Scan on tbl  (cost=0.00..145.00 rows=10000 width=8)
(1 row)
```

An index scan scan the index of the table to look for an appropriate match. Based on the availability of an appropriate index, an index scan may or may not be used:
- The indexed attributes must be specified in the scan filter condition.
- The scan filter operation should be compatible with the index. For example, equality filter or range filter can be applicable for B-Tree index.
- The statistics about selectivity: If PostgreSQL expects the scan to return a large portion of the table, it shall use sequential scan:
  - Sequential access is more efficient than random access in index scan.
  - After scanning the index, the table pages have to be fetched, but because the majority of tuples are expected, there's a high chance that all of the pages are fetched anyways. Therefore, the index scan in this case is just an unnecessary overhead.

Note that using an index scan, we have fetch both the index pages and the table pages. Why do we have to fetch the table pages also? Because the users requests some fields that are not present in the index file. By default, the index file contains only the indexed field, but it can be made to include additional fields (but not used for indexing). In cases that the requested fields are all present in an index, *index-only scan* may be used. This reduces the overhead of having to do another table fetch.

We'll give an example to sum up the above points:
- Table definition:
  ```
  db=# CREATE TABLE test (
    id INT,
    name TEXT
  );
  CREATE TABLE
  Time: 15.128 ms
  ```
- Populate data into the table:
  ```
  db=# CREATE SEQUENCE seq START 1;
  CREATE SEQUENCE
  Time: 9.864 ms
  
  db=# INSERT INTO test
    -# SELECT nextval('seq'), nextval('seq')::text || '_name'
    -# FROM generate_series(1, 10000000);
  INSERT 0 10000000
  Time: 29169.012 ms (00:29.169)
  
  db=# DROP SEQUENCE seq;
  DROP SEQUENCE
  Time: 9.085 ms
  ```
  We have to populate a large enough  data - if all data just fits within a single page, *sequential scan* will always be used.
- Sequential scan (optimized into parallel sequential scan):
  ```
  db=# EXPLAIN SELECT id FROM test;
                                   QUERY PLAN
---------------------------------------------------------------------------------
 Gather  (cost=1000.00..116286.39 rows=1 width=4)
   Workers Planned: 2
   ->  Parallel Seq Scan on test  (cost=0.00..115286.29 rows=1 width=4)
         Filter: (id = 1)
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(7 rows)

  Time: 1.222 ms
  ```
- Create an index on `id`:
  ```
  db=# CREATE INDEX idx_test ON test(id);
  CREATE INDEX
  Time: 4054.271 ms (00:04.054)
  ```
- Index scan:
  ```
  db=#  EXPLAIN SELECT * FROM test WHERE id = 1;
   EXPLAIN SELECT * FROM test WHERE id = 1;
                                QUERY PLAN
  ----------------------------------------------------------------------
   Index Scan using idx_test on test  (cost=0.43..8.45 rows=1 width=17)
     Index Cond: (id = 1)
  (2 rows)
  
  Time: 0.566 ms
  ```
- Index-only scan:
  ```
  db=# EXPLAIN SELECT id FROM test WHERE id = 1;
                                  QUERY PLAN
  --------------------------------------------------------------------------
   Index Only Scan using idx_test on test  (cost=0.43..4.45 rows=1 width=4)
     Index Cond: (id = 1)
  (2 rows)
  
  Time: 0.761 ms
  ```
- What if we want to use index-only scan when selecting both columns of the table while needing to index on only `id`?
  ```
  db=# CREATE INDEX idx_all_test ON test(id) INCLUDE(name);
  CREATE INDEX
  Time: 4793.885 ms (00:04.794)

  db=# EXPLAIN SELECT * FROM test WHERE id = 1;
                                    QUERY PLAN
  -------------------------------------------------------------------------------
   Index Only Scan using idx_all_test on test  (cost=0.43..4.45 rows=1 width=17)
     Index Cond: (id = 1)
  (2 rows)
  
  Time: 0.776 ms
  ```

=== Executor: Join algorithms

Join algorithms are some of the more interesting algorithms in the executor. Therefore, a few join algorithms in PostgreSQL are presented here.

==== Nested loop join

This is the simplest join algorithm and can be used on all join conditions.

#figure(caption: [Nested loop join @interdb])[
  #image("../images/PostgreSQL nested loop join.png")
]

At its most basic form, for each row in the outer table, we loop over all rows in the inner table. This is costly as we have to scan all possible pairs.

PostgreSQL supports the materialized nested loop join to reduce cost of scanning the inner table:
  - Before running a nested loop join, the executor writes the inner table tuples to the `work_mem` or a temporary file by scanning the inner table once.
  - Inside the nested loop join, the executor can now load the inner table tuples with less I/O cost.

#figure(caption: [Indexed nested loop join @interdb])[
  #image("../images/PostgreSQL materialized nested loop join.png")
]

PostgreSQL also supports the more complex indexed nested loop join, utilizing the index of the inner table if the join condition can be determined by that index. The inner loop uses the index of the inner table to lookup more efficiently.

#figure(caption: [Indexed nested loop join @interdb])[
  #image("../images/PostgreSQL indexed nested loop join.png") 
]

==== Merge join

Merge join can only be used in equi-joins and natural joins.

#figure(caption: [Merge join @interdb])[
  #image("../images/PostgresSQL merge join.png")
]

PostgreSQL first sorts the outer and inner tables. The resulting sorted tables will be stored in memory if they fit or else temporary files will be used. We can then keep 2 pointers to the current tuples of the outer and inner table and sequentially match them up.

There are some other variations of merge join supported by PostgreSQL.

#figure(caption: [Merge join variations @interdb])[
  #image("../images/PostgreSQL merge join variations.png")
]

==== Hash join

Hash join can only be used in equi-joins and natural joins.

The hash join in PostgreSQL behaves differently depending on the sizes of the tables.

- If the target table is small enough (more precisely, the size of the inner table is ≤ 25% of the `work_mem`), it will be a simple two-phase in-memory hash join.
- Otherwise, the hybrid hash join is used with the skew method.

The *hash table area* is called a *batch* in PostgreSQL, which contains many *buckets*. 

With in-memory hash joins, there are 2 phases @interdb:
+ Build: All tuples of the inner table are inserted into a batch.
+ Probe: Each tuple of the outer table is compared with the inner tuples in the batch and joined if the join condition is satisfied.

The hybrid hash join with skew method is more complex, compared to in-memory hash join. Here are some differences:
- The outer table and the inner table are stored into multiple batches.
- The first batch of the inner table is kept in memory while the first batch of the outer table is not stored at all (we'll see why).
- Besides, an additional batch called the skew batch is kept in memory. This batch contains the inner table tuples whose attribute involved in the join condition appear frequently in the outer table.

The hybrid hash join happens in multiple rounds, with the first rounds very different from the remaining rounds @interdb:
- First round:
  + Build:
    + Create a *batch* and a *skew batch* on `work_mem`.
    + Create *temporary batch files* for storing the inner table tuples.
    + Scan the inner table:
      + If a tuple's joining attribute appears frequently in the outer table, it's inserted into the skew batch.
      + Otherwise, calculate the hash key of the tuple and insert it into the corresponding batch.
  + Probe:
    + Create *temporary batch files* for storing the *outer table tuples*.
    + Scan the outer table:
      - If the tuple appears frequently in the table, probe the skew batch and perform a join.
      - If the tuple hashes to the inner table's first batch, it's joined immediately. Therefore, the first outer batch file is never stored in `work_mem` or temporary file.
      - Otherwise, the tuple is written into an outer batch file, which corresponds to the inner batch file it hashes to.

- The second round:
  + Clear the skew batch and the first inner batch in `work_mem`.
  + Load the second inner batch into `work_mem`.
  + Scan the second outer batch and probe the inner batch file to perform joins.
- Remaining rounds:
  + Load the corresponding inner batch into `work_mem`.
  + Scan the corresponding outer batch and probe the inner batch file to perform joins.

== Summary

Transaction processing in PostgreSQL is very heavyweight in terms of parsing, analyzing, planning and execution. This is due to the expressive power of SQL.

While in HBase, a simplistic interface is given via some plain APIs, this removes the need for parsing (other than deserializing the protocol serialized format). The APIs specify very simple operations: `Get`, `Put`, `Delete` - this make the planner & executor in HBase also simpler. The difficult part in HBase is how to communicate queries to a region server.