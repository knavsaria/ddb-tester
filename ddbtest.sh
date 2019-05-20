#!/bin/bash

SECONDS=0
table_name=$1

#polling describe-table function
poll_describe_table() {
	status='creating'
	while [ $status = 'creating' ]
	do
  	list=$(aws dynamodb describe-table --table-name $table_name --query "Table.GlobalSecondaryIndexes[*].IndexStatus" --output text)
  	status='active'
		#check if any of the GSIs are busy being created
  	for index_status in $list
  	do
    	if [ $index_status = 'CREATING' ]
    	then
    	echo 'still creating index, poll every 5 seconds'
    	sleep 5
    	status='creating'
    	fi
  	done
  	#check if the table is still updating, when the GSIs are all ACTIVE
  	table_status=$(aws dynamodb describe-table --table-name $table_name --query "Table.TableStatus" --output text)
		if [ $table_status != 'ACTIVE' ] && [ $status = 'active' ]
  	then
  		echo 'still updating the table, poll every 5 seconds'
  		sleep 5
  		status='creating'
  	fi
	done
}
	
#create table, then wait until it is created (using built it 'cli' wait feature)

aws dynamodb create-table --table-name $table_name --attribute-definitions file://table_create_defs --key-schema file://table_create_key_schema --global-secondary-indexes file://table_create_gsi --provisioned-throughput file://table_create_throughput

echo "Create table successfull. Waiting for it to become ACTIVE"
aws dynamodb wait table-exists --table-name $table_name

create_duration=$SECONDS
echo "Table creation complete and ACTIVE"
echo "Time taken: $(($create_duration / 60)) minutes and $(($create_duration % 60)) seconds"

#update table, then wait until it is active (using custom poll_describe_table function)
#update 1
aws dynamodb update-table --table-name $table_name --attribute-definitions file://table_update_defs --global-secondary-index-updates file://table_update_gsi_1 --billing-mode PAY_PER_REQUEST

poll_describe_table

update_1_duration=$SECONDS
echo "Table update 1 complete"
echo "Time taken: $(($update_1_duration / 60)) minutes and $(($update_1_duration % 60)) seconds"

#update 2
aws dynamodb update-table --table-name $table_name --attribute-definitions file://table_update_defs --global-secondary-index-updates file://table_update_gsi_2

poll_describe_table

update_2_duration=$SECONDS
echo "Table update 2 complete"
echo "Time taken: $(($update_2_duration / 60)) minutes and $(($update_2_duration % 60)) seconds"

#delete table, then wait until it is deleted (using built in cli 'wait' feature
aws dynamodb delete-table --table-name $table_name
aws dynamodb wait table-not-exists --table-name $table_name
delete_duration=$SECONDS
echo "Table delete complete"
echo "Time taken: $(($delete_duration / 60)) minutes and $(($delete_duration % 60)) seconds"

exit 0
