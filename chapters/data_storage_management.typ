= Data Storage and Management

== What is Data Storage?

Data storage refers to the comprehensive strategy of organizing, managing, and
storing data both logically and physically within a database system. This
involves understanding how data is structured, stored, and accessed at different
levels of abstraction.

== HBase

=== Data Storage

==== Physical Storage Strategy

+ *Hadoop Distributed File System (HDFS)*
  - Distributed, scalable storage system
  - Master-Slave architecture
    - NameNode (Master): Manages file system metadata
    - DataNodes (Slaves): Store actual data blocks

+ *Storage Model*
  - Column-oriented storage
  - Data stored in sparse, distributed tables
  - Supports dynamic column additions
  - Each table divided into multiple regions
    - Regions split automatically based on data size
    - Regions distributed across multiple DataNodes

+ *Storage Organization*
  - Data stored in HFiles
  - Organized by Column Families
  - Supports real-time read/write operations
  - Optimized for write-heavy workloads

== PostgreSQL

=== Data Storage

==== Storage Characteristics
- Row-oriented storage model
- Fixed schema with predefined columns
- Uses B-tree indexes for efficient data retrieval
- Supports complex data types and relations

==== Logical View

+ *Database Cluster Concept*
  - Single PostgreSQL server manages a database cluster
  - Runs on a single host
  - Database cluster: Collection of databases managed by one server

+ *Object Identification*
  - Uses 4-byte integers called Object Identifiers (OIDs)
  - OIDs track relationships between database objects
  - Stored in system catalogs:
    - Database OIDs in pg_database
    - Heap table OIDs in pg_class

==== Physical Storage Structure

+ *PGDATA Directory Layout*
  - Root directory containing all database cluster files
  - Key subdirectories include:
    - `base/`: Per-database subdirectories
    - `global/`: Cluster-wide tables
    - `pg_wal/`: Write-Ahead Log (WAL) files
    - `pg_multixact/`: Multitransaction status data
    - `pg_stat/`: Permanent statistics files

+ *Database File Storage*
  - Each database stored in a subdirectory under `base/`
  - Subdirectory named after database's OID
  - Individual tables and indexes as separate files
    - Filename based on filenode number
    - Supports file segmentation for large relations (>1 GB)
    - Each relation has multiple file forks:
      - Main fork: Actual data
      - Free Space Map (FSM) fork: Tracks available space
      - Visibility Map (VM) fork: Tracks page tuple status

+ *Special Storage Mechanisms*
  - TOAST (The Oversized-Attribute Storage Technique)
    - Handles large column values
    - Stores oversized values in a separate TOAST table
    - Linked via `pg_class.reltoastrelid`

+ *Tablespace Management*
  - Supports storing relations in different physical locations
  - Uses symbolic links in `pg_tblspc/` directory
  - Allows flexible storage configuration
  - Version-specific subdirectories prevent conflicts

+ *Temporary File Handling*
  - Temporary files created in `base/pgsql_tmp/`
  - Used for operations exceeding memory capacity
  - Filename format: `pgsql_tmpPPP.NNN`
    - PPP: Backend Process ID
    - NNN: Unique temporary file identifier

==== TOAST (The Oversized-Attribute Storage Technique)

+ *Purpose*
  - Handles storage of large field values in PostgreSQL
  - PostgreSQL uses a fixed page size (commonly 8 kB), and does not allow tuples to
    span multiple pages. TOAST helps overcome this limitation.
  - Transparently manages large data values

+ *How it works*
  - Large field values are compressed and/or broken up into multiple physical rows.
  - This happens transparently to the user, with only small impact on most of the
    backend code.
  - The TOAST infrastructure is also used to improve handling of large data values
    in-memory.
+ *Storage Mechanisms*
  - Compression of large values
  - Breaking large values into multiple physical rows
  - Supports data types with variable-length representation

+ *TOAST Strategies*
  - EXTENDED (Default): Allows compression and out-of-line storage
  - PLAIN: No compression or out-of-line storage
  - EXTERNAL: Out-of-line storage without compression
  - MAIN: Compression without out-of-line storage

+ *Technical Details*
  - Uses special bits in length word to manage storage
  - Limits logical value size to 1 GB
  - Supports compressed and out-of-line storage
  - Associated TOAST table for each table with large attributes
    - Stores chunks of oversized values
    - Unique index for fast retrieval

+ *Performance Benefits*
  - Reduces main table size
  - Improves buffer cache efficiency
  - Enables faster sorting operations
  - Minimal performance overhead

+ *Storage Optimization*
  - Automatic compression
  - Chunk-based storage (default ~2000 bytes per chunk)
  - Configurable compression and storage strategies

== Comparison of Storage Strategies

=== Storage Architecture
- *HBase*: Distributed, scalable, column-oriented
- *PostgreSQL*: Centralized, row-oriented, structured

=== Scalability
- *HBase*: Horizontal scaling through HDFS
- *PostgreSQL*: Vertical scaling, limited horizontal distribution

=== Data Flexibility
- *HBase*: Dynamic column addition, sparse data support
- *PostgreSQL*: Rigid schema, defined column structures

=== Performance Characteristics
- *HBase*: Optimized for write-heavy, large-scale datasets
- *PostgreSQL*: Efficient for structured, consistent data

= Conclusion

The choice between HBase and PostgreSQL depends on specific use case
requirements, data characteristics, and scalability needs.

= References
- PostgreSQL 13 Documentation
- PostgreSQL Internals
