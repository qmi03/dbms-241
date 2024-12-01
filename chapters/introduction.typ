#set list(indent: 10pt)
#set par(justify: true)

= Introduction

== Foreword

HBase and PostgreSQL are two representatives of two flavors of DBMS - SQL and NoSQL. This should be enough to suggest that there exists _some_ differences between the two. In fact, they are very far from each other on the spectrum - further than, say, PostgreSQL to MongoDB. Therefore, we decide to conduct a comparison between PostgreSQL and HBase to see why they are so different.

To sum up, most of the differences between PostgreSQL and HBase derive from the different use cases they serve, and the kind of processing workload they are optimized for.

From the perspective of processing, we can identify two categories:
  #columns(2)[
    *Transactional processing*: Computation pertaining to the daily operation.
      - Real-time processing: Must complete in a few seconds at most.
      - Relevant data ratio: Only a few records in a database are relevant to a query.
      - Frequency: Very high.
      - Dataset size: Small to medium.
      - Data-access pattern: Random access.
    #colbreak()
    *Analytical processing*: Computation that answers business questions.
      - Batch processing: Can take from minutes to hours to complete.
      - Relevant data ratio: A large portions of records are relevant to an analysis.
      - Frequency: Very low - typically on a days/weeks/months' granularity's basis.
      - Dataset size: Large to very large.
      - Data-access pattern: Sequential.
  ]

#figure(caption: [PostgreSQL vs HBase], image("/images/battle!.png"))

PostgreSQL and HBase are designed for different use cases:
  - *PostgreSQL*: Like good 'ol traditional RDBMs, PostgreSQL are geared towards transactional use cases.
  - *HBase*: An in-betweener between transactional & analytical processing. It was conceived of as a database engine for efficient distributed random access in the Hadoop ecosystem - which is designed for high-performance analytical batch processing on very big datasets.
This explains why they are different:
  - *PostgreSQL* works well on small-to-medium datasets and mostly serves day-to-day business operations, such as banking, purchases, etc.
  - *HBase* is designed for Big data use cases - efficient data analysis - but it's also used for storing big transactional datasets, such as customer's clickstream.

Because they are different, the conceptual models they use are different, thus are their schema design processes.

The reasons we decided to choose these two DBMSs are three-fold:
  - Highlight the characteristics of each DBMS that are optimized for their use cases: data model, concurrency control & recovery, query processing, etc.
  - Contrast the schema design processes of SQL and NoSQL databases.
  - Considerations into when to use each.

== Overview

=== PostgreSQL

PostgreSQL is a popular open-source object-relational DBMS which (kind of) implements the SQL language. In fact, no production DBMS so far has completely conformed to the SQL standard. However, in this regard, PostgreSQL is known for its high SQL conformance.

A bit of history, PostgreSQL dates back to 1986 and has been constantly developed for over 35 years. Therefore, PostgreSQL has undergone many big transformations. The latest major stable version as of 2024 is PostgreSQL 17.

According to Stackoverflow survey of 2023, PostgreSQL is the most popular DBMS.

#figure(caption: "2023 Stackoverflow's ranking of DBMSs", image("/images/Postgres ranking 2023.png", width: 80%))

Being relational, PostgreSQL is suitable for most real-time transaction use cases.

The details of when to apply PostgreSQL rather than other RDBMS is left to the investigation of how PostgreSQL handles:
- Physical data storage.
- Indexing.
- Query processing.
- Transaction processing.
- Concurrency control.
- Recovery.
- Other advanced usages.

==== Philosophy
PostgreSQL emphasizes on:
  - High SQL compliance: PostgreSQL tries to conform to the SQL standard as long as it doesn't badly hurt performance or hamper other well-known features of RDBMS.
  - Extensibility: PostgreSQL has many plugins and mechanisms to extend its behavior.
    - Plugins & extensions. For example, foreign data wrapper (FDW), which allows a SQL server to query a remote relation.
    - Procedural Languages: PL/pgSQL, Perl, Python, and Tcl.
    - User-defined data types.
    - Custom functions, even from different programming languages.
==== NoSQL support
PostgreSQL is an *object-relational* DBMS so its capabilities extend beyond traditional features of RDBMS.

For example, PostgreSQL provides support for storing and efficiently querying the JSON data type:
  - Native support for the `json` and `jsonb` data types.
  - Access operators for JSON data such as `->`, `->>`, etc.
  - A bunch of functions for building, iterating, transforming JSONs: `jsonb_build_object`, `jsonb_object_agg`, `json_each`, etc.
These make working with JSONs very expressive and flexible. In a sense we can work with JSON documents as in document-based NoSQL DBMSs. This means that we can model data in a schema-less fashion in PostgreSQL.

==== Summary
We can sum up the whole points as below:
- PostgreSQL is an object-relational DBMS.
- PostgreSQL has supports for modeling data like document-based DBMS.
- PostgreSQL is extensible.
- PostgreSQL is highly SQL-conformant.

=== HBase

HBase is a distributed wide-column NoSQL DBMS. It's part of the Hadoop ecosystem. In fact, it's the DBMS for the Hadoop Filesystem (HDFS), in the same sense as in PostgreSQL is a DBMS for the ext3, NTFS filesystems.

In the below picture, we can see that HBase is built upon HDFS:

#figure(caption: "HBase in Hadoop landscape", image("/images/Hadoop landscape.png", width: 80%))

HBase is still very young - first introduced in 2008. The latest version as of 2024 is 3, and it's still in beta.

HBase is optimized for a mix of transactional and analytical use cases. Therefore, it should perform better on very big datasets than PostgreSQL.

In summary, HBase is conceived of as:
- Providing random access on top of the sequential access provided by HDFS filesystem.
- Providing real-time, random access to very large files.
- Integrating well with the Hadoop ecosystem.