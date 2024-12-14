= Data storage and management

== What is data storage?
Logical and Physical Data Storage Strategy or something like that

== HBase
=== Data Storage
1. Hadoop Distributed File System (HDFS)
Master-Slave

== Postgres
+ Database Cluster
#set enum(numbering: "a)")

#enum(enum.item(1)[Logical View])
A PostgreSQL server is a single process that runs in a SINGLE HOST and manages a _single_ database
cluster.

A database cluster is basically a collection of databases managed by a
PostgreSQL server.

All the databases in cluster are internally managed by a 4-byte integers, called
Object Identifiers (OIDs).

The relations between database objects and their respective OIDs are stored in
appropriate system catalogs, depending on the type of objects. For example, OIDs
of databases and heap tables are stored in pg_database and pg_class
respectively.

#enum(enum.item(2)[Physical View])

A database cluster is basically a single directory - or a *base directory*. For
each database in the cluster, there is a subdirectory within PGDATA/base, named
after the database's OID in pg_database.

This subdirectory is the default location for the database's files; in
particular, its system catalogs are stored there.

Each database is stored in a sub directory of *base directory*.

1.3 Layout of a database cluster

The layout of database cluster has been described in the official document

== Comparison
