Series Introduction: The Data Lifecycle
=======================================

In a series of blog posts, we're going to explore the full lifecycle of data in the enterprise: Introducing new data sources to the Hadoop filesystem via ETL, processing this data with Pig and Python to expose new and interesting properties, consuming this data as an analyst in HIVE, and discovering and accessing these resources using HCatalog and Templeton.

Using Pig, Hadoop, Sqoop and Avro to Mine the Enron Emails
==========================================================

Code for creating and querying an Avro encoded repository of the UC Berkeley Enron email archive.

The Berkeley Enron Emails
-------------------------

### Introduction

In this project we will convert this MySQL database of Enron emails into Avro format for analysis on Hadoop with Pig.

Email is a rich source of information for analysis by many means. During the investigation of the Enron scandal of 2001, 517,431 messages from 114 inboxes of key Enron executives were collected. These emails were published and have become a common dataset for academics to analyze document collections and social networks. Andrew Fiore and Jeff Heer at UC Berkeley have cleaned this email set and provided it as a MySQL archive. 

We hope that this dataset can become a sort of common set for examples and questions, as anonymizing one's own data in public forums can make asking questions and getting authoritative answers tricky.

More information about the Enron Emails is available:

* [Document Classification on Enron Email Dataset](http://people.cs.umass.edu/~ronb/enron_dataset.html)
* [Enron Scandal on Wikipedia](http://en.wikipedia.org/wiki/Enron_scandal)
* [UC Berkeley Enron Email Analysis](http://bailando.sims.berkeley.edu/enron_email.html)

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
    
Querying a single email to return it as a document we might see in our inbox is complex. And yet this is precisely the format that is most convenient for analysis. This is the limitation of highly structured, relational data. Lets select a single email as we might view it in raw format.

    mysql> select m.smtpid as id, 
           m.messagedt as date, 
           s.email as sender,
           (select group_concat(CONCAT(r.reciptype, ':', p.email) SEPARATOR ', ') from recipients r join people p ON r.personid=p.personid where r.messageid = 511) as to_cc_bcc,
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

This is painful, to say the least.  In contrast, with our data in Avro encoded document format, we'll be able to more easily access these emails to analyze both their structured and unstructured components with whatever tools we prefer.

### Dumping MySQL to Tab-Delimited 

Now that we're comfortable with our data, lets query it for export.

1) Get the emails and their senders:

    mysql> select m.smtpid as message_id, m.messagedt as date, s.email as from_address, s.name as from_name, m.subject as subject, b.body as body from messages m join people s on m.senderid=s.personid join bodies b on m.messageid=b.messageid limit 10;

    +----------------------+---------------------+----------------------+----------------------+----------------------+----------------------+
    | message_id           | date                | from_address         | from_name            | subject              | body                 |
    +----------------------+---------------------+----------------------+----------------------+----------------------+----------------------+
    | <2614099.10758399272 | 2001-10-31 05:23:56 | marketopshourahead@c | CAISO Market Operati | Path 30 mitigation   | System Notification: |
    | <31442247.1075839927 | 2001-10-31 04:04:37 | marketopsrealtimebee | CAISO Market Operati | Path 15              | Internal path flows  |
    | <1111763.10758399275 | 2001-10-31 03:33:18 | marketopsrealtimebee | CAISO Market Operati | Path 15              | Path 15 S-N flows ar |
    | <29147324.1075839927 | 2001-10-31 01:51:22 | marketopshourahead@c | CAISO Market Operati | Unscheduled Flow Pro | Market Message: At 2 |
    | <17933220.1075839927 | 2001-10-30 23:07:04 | marketopsrealtimebee | CAISO Market Operati | Expost pricing on OA | Beginning HE20, the  |
    | <17725708.1075839927 | 2001-10-30 22:43:37 | marketopsrealtimebee | CAISO Market Operati | Incorrect prices on  | Starting HE19 the IS |
    | <29992592.1075839928 | 2001-10-30 21:03:49 | crcommunications@cai | CRCommunications     | CAISO NOTICE:  Data  | To Market Participan |
    | <20631685.1075839928 | 2001-07-02 18:00:58 | kalmeida@caiso.com   | Keoni" "Almeida      | FW: CAISO Notice: Up | The price is still 9 |
    +----------------------+---------------------+----------------------+----------------------+----------------------+----------------------+

2) Get the recipients of those emails, be it to/cc/bcc:

    select m.smtpid, r.reciptype, p.email, p.name from messages m join recipients r on m.messageid=r.messageid join people p on r.personid=p.personid limit 10;

    +-----------------------------------------------+-----------+------------------------------+-------------------------------------+
    | smtpid                                        | reciptype | email                        | name                                |
    +-----------------------------------------------+-----------+------------------------------+-------------------------------------+
    | <2614099.1075839927264.JavaMail.evans@thyme>  | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <31442247.1075839927371.JavaMail.evans@thyme> | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <1111763.1075839927587.JavaMail.evans@thyme>  | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <29147324.1075839927746.JavaMail.evans@thyme> | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <17933220.1075839927790.JavaMail.evans@thyme> | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <17725708.1075839927988.JavaMail.evans@thyme> | to        | mktstathourahead@caiso.com   | Market Status: Hour-Ahead/Real-Time |
    | <29992592.1075839928142.JavaMail.evans@thyme> | to        | 20participants@caiso.com     | ISO Market Participants             |
    | <29992592.1075839928142.JavaMail.evans@thyme> | to        | isoclientrelations@caiso.com | ISO Client Relations                |
    | <20631685.1075839928414.JavaMail.evans@thyme> | to        | bill.williams@enron.com      | Bill Williams III                   |
    +-----------------------------------------------+-----------+------------------------------+-------------------------------------+

We can run that same query to dump the results as TSV, or "Tab Separated Values." MySQL's mysql client allows us to dump a query as TSV using the -e and -B options. -e executes a supplied query, and -B gives tab-delimited output.  For simplicity's sake, we'll dump this data in more than one query.

Run these from the command line to perform the dumps.

    [bash]$ mysql -u root -B -e "select m.smtpid as message_id, m.messagedt as date, s.email as from_address, s.name as from_name, m.subject as subject, b.body as body from messages m join people s on m.senderid=s.personid join bodies b on m.messageid=b.messageid;" enron > enron_messages.tsv
    [bash]$ head enron_messages.tsv
    
    message_id	date	from_address	from_name	subject	body
    <2614099.1075839927264.JavaMail.evans@thyme>	2001-10-31 05:23:56	marketopshourahead@caiso.com	CAISO Market Operations - Hour Ahead	Path 30 mitigation	System Notification: At 0115 PST, WACM terminated request for coordinated\noperation controllable devices for Path 30 USF mitigation.
    <31442247.1075839927371.JavaMail.evans@thyme>	2001-10-31 04:04:37	marketopsrealtimebeep@caiso.com	CAISO Market Operations - Realtime/BEEP	Path 15	Internal path flows are now below limits.  BEEP has been returned to normal\nmode (unsplit operation) as of 0000 hours.  BEEP will dispatch as one zone.\nSent by Market Operations, inquiries please call the Real Time Desk.\n\n\nThe system conditions described in this communication are dynamic and\nsubject to change.  While the ISO has attempted to reflect the most current,\naccurate information available in preparing this notice, system conditions\nmay change suddenly with little or no notice.
    
    [bash]$ mysql -u root -B -e "select m.smtpid, r.reciptype, p.email, p.name from messages m join recipients r on m.messageid=r.messageid join people p on r.personid=p.personid" enron > enron_recipients.tsv
    [bash]$ head enron_recipients.tsv
    
    smtpid	reciptype	email	name
    <2614099.1075839927264.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <31442247.1075839927371.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <1111763.1075839927587.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <29147324.1075839927746.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <17933220.1075839927790.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <17725708.1075839927988.JavaMail.evans@thyme>	to	mktstathourahead@caiso.com	Market Status: Hour-Ahead/Real-Time
    <29992592.1075839928142.JavaMail.evans@thyme>	to	20participants@caiso.com	ISO Market Participants
    <29992592.1075839928142.JavaMail.evans@thyme>	to	isoclientrelations@caiso.com	ISO Client Relations
    <20631685.1075839928414.JavaMail.evans@thyme>	to	bill.williams@enron.com	Bill Williams III

### ETL (Extract-Transform-Load) with Pig

We can now load our sql dump in Pig. I prefer to use several parameters when I use Pig in local mode. The '-l /tmp' option lets me put my pig logs in /tmp so they don't clutter my working directory. '-x local' tells Pig to run in local mode instead of Hadoop mode. '-v' enables verbose output, and '-w' enables warnings. These last two options are useful for debugging problems when working with a new dataset.

    [bash]$ pig -l /tmp -x local -v -w
    
    grunt> enron_messages = LOAD '/me/enron-avro/enron_messages.tsv' AS (
     
         message_id:chararray,
         sql_date:chararray,
         from_address:chararray,
         from_name:chararray,
         subject:chararray,
         body:chararray
      
    );
    grunt> describe enron_messages
    enron_messages: {message_id: chararray,sql_date: chararray,from_address: chararray,from_name: chararray,subject: chararray,body: chararray}
    grunt> illustrate enron_messages
         -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    | enron_messages     | message_id:chararray                          | sql_date:chararray    | from_address:chararray    | from_name:chararray    | subject:chararray                   | body:chararray                                                                                                  | 
    -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    |                    | <33385450.1075839957796.JavaMail.evans@thyme> | 2002-01-25 12:56:33   | pete.davis@enron.com      | Pete Davis             | Schedule Crawler: HourAhead Failure | \n\nStart Date: 1/25/02; HourAhead hour: 11;  HourAhead schedule download failed. Manual intervention required. | 
    -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    grunt>  

Data Processing with Pig
------------------------

If Perl is the duct tape of the internet, then Pig is the duct tape of Big Data(TM). Pig can easily transform data from one format to another. In this case, we'll use Pig to transform raw TSV to semi-structured Avro records.

### Avro-izing our Data with Pig 

Now we've got our data in document format in Pig, with a schema. Lets save our data in Avro format to persist this schema. To do so, we need to register the jars that Avro needs, as well as Piggybank for the AvroStorage UDF itself. We'll also define a short form of the AvroStorage command, as the fully qualified name is java-long.

    /* Piggybank has useful utilities, like CustomFormatToISO and AvroStorage
    register /me/pig/contrib/piggybank/java/piggybank.jar
    
    /* Avro and datetime dependencies */
    register /me/pig/build/ivy/lib/Pig/avro-1.5.3.jar
    register /me/pig/build/ivy/lib/Pig/json-simple-1.1.jar
    register /me/pig/contrib/piggybank/java/piggybank.jar
    register /me/pig/build/ivy/lib/Pig/jackson-core-asl-1.7.3.jar
    register /me/pig/build/ivy/lib/Pig/jackson-mapper-asl-1.7.3.jar
    register /me/pig/build/ivy/lib/Pig/joda-time-1.6.jar
    
    /* Define short form versions of the java-long names */
    define CustomFormatToISO org.apache.pig.piggybank.evaluation.datetime.convert.CustomFormatToISO();
    define AvroStorage org.apache.pig.piggybank.storage.avro.AvroStorage();
    
    /* Default to 10 reducers and remove any previous results from our path */
    set default_parallel 10
    rmf /enron/emails.avro
    
    /* Enron messages contain from data, but not recipients */
    enron_messages = load '/enron/enron_messages.tsv' as (
         message_id:chararray,
         sql_date:chararray,
         from_address:chararray,
         from_name:chararray,
         subject:chararray,
         body:chararray
    );
    
    /* Recipients are lumped into a single table with different types */
    enron_recipients = load '/enron/enron_recipients.tsv' as (
        message_id:chararray,
        reciptype:chararray,
        address:chararray,
        name:chararray
    );
    
    /* Split the recipients into different relations based on their type */
    split enron_recipients into tos IF reciptype=='to', ccs IF reciptype=='cc', bccs IF reciptype=='bcc';
    
    /* COGROUP lets us group together all kinds of recipients - whether they are present for a given message_id or not */
    headers = cogroup tos by message_id, ccs by message_id, bccs by message_id;
    
    /* Now we join the recipient headers back to the messages, giving us complete documents.  
       Note, we also format the datetime from Unix time to ISO time, for processing with Pig's DateTime utilities. */
    with_headers = join headers by group, enron_messages by message_id;
    emails = foreach with_headers generate enron_messages::message_id as message_id, 
                                      CustomFormatToISO(enron_messages::sql_date, 'yyyy-MM-dd HH:mm:ss') as datetime,
                                      enron_messages::from_address as from_address,
                                      enron_messages::from_name as from_name,
                                      enron_messages::subject as subject,
                                      enron_messages::body as body,
                                      headers::tos.(address, name) as tos,
                                      headers::ccs.(address, name) as ccs,
                                      headers::bccs.(address, name) as bccs;
                                  
    store emails into '/enron/emails.avro' using AvroStorage();


Pig generates as many segments as there are mappers. In this case, 0-6 or 7 mappers.

    [bash]$ ls /enron/emails.avro

    part-m-00001.avro       part-m-00004.avro       part-m-00006.avro       part-m-00009.avro
    part-m-00002.avro       part-m-00005.avro       part-m-00007.avro
    part-m-00000.avro       part-m-00003.avro       part-m-00008.avro

### Cat Avro

We can cat these Avro encoded files using a simple python utility I wrote, called [cat_avro](https://github.com/rjurney/Collecting-Data/blob/master/src/python/cat_avro). A less robust Ruby version of cat_avro is available [here](https://github.com/rjurney/Collecting-Data/blob/master/src/ruby/bin/cat_avro).

The script uses the Python Avro library, and is pretty simple:

    from avro import schema, datafile, io
    
    ...
    
    for record in df_reader:
      if i > 20:
        break
      i += 1
      if field_id:
        pp.pprint(record[field_id])
      else:
        pp.pprint(record)

    [bash]$ cat_avro /enron/emails.avro/part-m-00001.avro
    
    ...
    
    {u'bccs': [],
     u'body': u'Does anyone have a template form of letter that we can circulate to the legal group to deal with the adequate assurance requests that seem to be coming in more frequently?\\n\\nCarol St. Clair\\nEB 4539\\n713-853-3989 (phone)\\n713-646-8537 (fax)\\n281-382-1943 (cell phone)\\n8774545506 (pager)\\n281-890-8862 (home fax)\\ncarol.st.clair@enron.com',
     u'ccs': [],
     u'datetime': u'2001-11-05T08:56:39.000Z',
     u'from_address': u'carol.st.@enron.com',
     u'from_name': u'Carol St. Clair',
     u'message_id': u'<312437.1075861584646.JavaMail.evans@thyme>',
     u'orig_date': u'2001-11-05 08:56:39',
     u'subject': u'Adequate Assurance Letter',
     u'tos': [{u'address': u'andrew.edison@enron.com', u'name': u'Andrew Edison'},
              {u'address': u'a..robison@enron.com', u'name': None},
              {u'address': u't..hodge@enron.com', u'name': u'Jeffrey T. Hodge'},
              {u'address': u'elizabeth.sager@enron.com',
               u'name': u'Elizabeth Sager'}]}

The cat_avro utility prints 20 records and then the schema of the records. 

### Loading avros with AvroStorage

Note that a schema is included with each data file, so that it lives with the data. This is convenient. From now on we don't have to cast our data as we load it like we did before.

    grunt> enron_emails = LOAD '/enron/emails.avro' USING AvroStorage();
    grunt> describe enron_emails
    
    emails: {message_id: chararray,orig_date: chararray,datetime: chararray,from_address: chararray,from_name: chararray,subject: chararray,body: chararray,tos: {ARRAY_ELEM: (address: chararray,name: chararray)},ccs: {ARRAY_ELEM: (address: chararray,name: chararray)},bccs: {ARRAY_ELEM: (address: chararray,name: chararray)}}
    
    grunt> illustrate enron_emails
    
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    | emails     | message_id:chararray                         | orig_date:chararray    | datetime:chararray       | from_address:chararray    | from_name:chararray                       | subject:chararray     | body:chararray                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | tos:bag{ARRAY_ELEM:tuple(address:chararray,name:chararray)}             | ccs:bag{ARRAY_ELEM:tuple(address:chararray,name:chararray)}             | bccs:bag{ARRAY_ELEM:tuple(address:chararray,name:chararray)}             | 
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    |            | <8218544.1075844279771.JavaMail.evans@thyme> | 2000-09-05 13:05:00    | 2000-09-05T13:05:00.000Z | david@ddh-pd.com          | DDH Product Design, Inc." "David Hayslett | Family Reunion Photos | Rod,\n\n It was nice to talk to you this evening. It did sound like you\n had a cold. There is no way to protect from going from air\n conditioning to the outside heat/humidity then back into\n the air conditioning. Just try to get some rest and we'll think positive\n for some cooler weather for you.\n\n Attached pls. find the photos I spoke of. There were 30 of them and I\nnarrowed them to the family I could name. I'll write more later.\n It would be great if you all came out around the holidays!\n Love,\n\n Dave........... \n - Family_Reunion_2000.zip\n | {(hayslettr@yahoo.com, )}                                               | {(rod.hayslett@enron.com, )}                                            | {(rod.hayslett@enron.com, )}                                             | 
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### Conclusion

We've seen how Pig can be used to take SQL data and convert it to well formed document data with Avro.







