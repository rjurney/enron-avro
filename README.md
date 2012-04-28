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

As we can see, this data is highly structured.
    
    mysql> select * from messages limit 1;
    +-----------+----------------------------------------------+---------------------+-----------+----------+--------------------+
    | messageid | smtpid                                       | messagedt           | messagetz | senderid | subject            |
    +-----------+----------------------------------------------+---------------------+-----------+----------+--------------------+
    |         1 | <2614099.1075839927264.JavaMail.evans@thyme> | 2001-10-31 05:23:56 | -0800 PST |        1 | Path 30 mitigation |
    +-----------+----------------------------------------------+---------------------+-----------+----------+--------------------+
    1 row in set (0.01 sec)
    
Querying a single email to return it as a document we might see in our inbox is complex.  And yet this is precisely the format that is most convenient for analysis.  This is the limitation of highly structured, relational data.

    mysql> -- Select a single email as we might view it in raw format.
    select m.smtpid as id, 
           m.messagedt as date, 
           s.email as sender,
           (select group_concat(CONCAT(r.reciptype, ':', p.email) SEPARATOR ' ') from recipients r join people p ON r.personid=p.personid where r.messageid = 511) as to_cc_bcc,
           m.subject as subject, 
           SUBSTR(b.body, 1, 200) as body
                from messages m 
                join people s
                    on m.senderid=s.personid
                join bodies b 
                    on m.messageid=b.messageid 
                        where m.messageid=511;
    
    +-----------------------------------------------+---------------------+----------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------+--------------------------------------------------------------------------------------------------------------+
    | id                                            | date                | sender               | to_cc_bcc                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | subject                             | body                                                                                                         |
    +-----------------------------------------------+---------------------+----------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------+--------------------------------------------------------------------------------------------------------------+
    | <25772535.1075839951307.JavaMail.evans@thyme> | 2002-02-02 12:56:33 | pete.davis@enron.com | to:pete.davis@enron.com cc:albert.meyers@enron.com cc:bill.williams@enron.com cc:craig.dean@enron.com cc:geir.solberg@enron.com cc:john.anderson@enron.com cc:mark.guzman@enron.com cc:michael.mier@enron.com cc:pete.davis@enron.com cc:ryan.slinger@enron.com bcc:albert.meyers@enron.com bcc:bill.williams@enron.com bcc:craig.dean@enron.com bcc:geir.solberg@enron.com bcc:john.anderson@enron.com bcc:mark.guzman@enron.com bcc:michael.mier@enron.com bcc:pete.davis@enron.com bcc:ryan.slinger@enron.com | Schedule Crawler: HourAhead Failure | 

    Start Date: 2/2/02; HourAhead hour: 11;  HourAhead schedule download failed. Manual intervention required. |
    +-----------------------------------------------+---------------------+----------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------+--------------------------------------------------------------------------------------------------------------+
    1 row in set (0.04 sec)
    




