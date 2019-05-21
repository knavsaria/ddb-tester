# ddb-tester
bash script to test creation, updation and deletion of a DynamoDB table. Includes a function to poll until table updates are complete.

First Argument - $1 - the name of the table to create, update and delete
Second Argument - $2 - the number of times to lifecycle runs for this table
Table operation function arguments are hard coded files that point to json files in the same directory as the script
