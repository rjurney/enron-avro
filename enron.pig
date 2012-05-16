register /me/pig/contrib/piggybank/java/piggybank.jar

register /me/pig/build/ivy/lib/Pig/avro-1.5.3.jar
register /me/pig/build/ivy/lib/Pig/json-simple-1.1.jar
register /me/pig/contrib/piggybank/java/piggybank.jar
register /me/pig/build/ivy/lib/Pig/jackson-core-asl-1.7.3.jar
register /me/pig/build/ivy/lib/Pig/jackson-mapper-asl-1.7.3.jar
register /me/pig/build/ivy/lib/Pig/joda-time-1.6.jar

define CustomFormatToISO org.apache.pig.piggybank.evaluation.datetime.convert.CustomFormatToISO();
define AvroStorage org.apache.pig.piggybank.storage.avro.AvroStorage();

set default_parallel 10
rmf /tmp/er_test

enron_messages = load '/enron/enron_messages.tsv' as (
     message_id:chararray,
     sql_date:chararray,
     from_address:chararray,
     from_name:chararray,
     subject:chararray,
     body:chararray
);
enron_messages = sample enron_messages 0.01;

enron_recipients = load '/enron/enron_recipients.tsv' as (
    message_id:chararray,
    reciptype:chararray,
    address:chararray,
    name:chararray
);

split enron_recipients into tos IF reciptype=='to', ccs IF reciptype=='cc', bccs IF reciptype=='bcc';

/*define strip_header(header) RETURNS clean {
    stripped = foreach $header generate message_id, address, name;
    $clean = foreach (group stripped by message_id) generate group as message_id, stripped.(address, name) as $header;
};*/

headers = cogroup tos by message_id, ccs by message_id, bccs by message_id;
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
                                  
store emails into '/tmp/er_test' using AvroStorage();
