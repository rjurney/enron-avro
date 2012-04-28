Using Pig, Hadoop, Sqoop and Avro to Mine the Enron Emails
==========================================================

Code for creating and querying an Avro encoded repository of the UC Berkeley Enron email archive.

The Berkeley Enron Emails
-------------------------

### Introduction

Email is a rich source of information for analysis by many means. During the investigation of the Enron scandal of 2001, 517,431 messages from 114 inboxes of key Enron executives were collected. These emails were published and have become a common dataset for academics to analyze document collections and social networks. Andrew Fiore and Jeff Heer at US Berkeley have cleaned this email set and provided it as a MySQL archive. 

In this project we will convert this MySQL database of Enron emails into Avro format for analysis on Hadoop with Pig.

We hope that this dataset can become a sort of common set for examples and questions, as anonymizing one's own data in public forums can make asking questions and getting authoritative answers tricky.

More information about the Enron Emails is available:

[Document Classification on Enron Email Dataset](http://people.cs.umass.edu/~ronb/enron_dataset.html)
[Enron Scandal on Wikipedia](http://en.wikipedia.org/wiki/Enron_scandal)
[UC Berkeley Enron Email Analysis](http://bailando.sims.berkeley.edu/enron_email.html)

Setting up the Enron Database
-----------------------------

### Installing MySQL

MySQL is a simple but powerful open-source database. MySQL 5.5 is available [here](http://dev.mysql.com/downloads/), and [easy setup instructions](http://dev.mysql.com/doc/refman/5.5/en/installing.html) are available.

### Download and Load the Enron Emails

A MySQL 5.5 compatible version of the emails is available [here](https://s3.amazonaws.com/rjurney_public_web/images/enron.mysql.5.5.20.sql.gz).

Download the database archive, unpack it, create the enron database and then load the archive into it.

    [bash]$ tar -xvzf enron.mysql.5.5.20.sql.gz
    [bash]$ mysql -u root -e 'create database enron'
    [bash]$ mysql -u root < enron.mysql.5.5.20.sql

This will take some time, as the data is loaded into many tables with relationships and indexes. This is a good example of how structured, relational data works. Data processing in relational databases is front-loaded to optimize query performance later. With Hadoop and Pig, semi-structured or un-structured data is processed in parallel on many machines via [MapReduce](http://research.google.com/archive/mapreduce.html). We might say that concurrency on many networked machines replaces indexes on one machine. This allows us to manipulate many kinds of data in an ad hoc fashion without having to rigorously structure it before processing.

### Inspect and Query the Emails

    [bash]$ mysql -u root enron
    
    mysql> show tables;
    
    +-----------------+
    | Tables_in_enron |
    +-----------------+
    | bodies          |
    | categories      |
    | catgroups       |
    | edgemap         |
    | edges           |
    | headers         |
    | mailgraph       |
    | messagecats     |
    | messages        |
    | people          |
    | recipients      |
    +-----------------+
    11 rows in set (0.00 sec)
    
    mysql> 




