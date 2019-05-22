#!/bin/bash

table_name=$1
number_of_tests=$2

#Line echo-er
println() {
echo "================================================================="
}

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
    	if [ $index_status = 'CREATING' ] || [ $index_status = 'UPDATING' ]
    	then
    	echo 'still creating or updating index, poll every 5 seconds'
    	sleep 5
    	status='creating'
	continue
    	fi
  	done
  	#if GSIs are done updating, check if the table is still updating (e.g. capacity updates)
  	table_status=$(aws dynamodb describe-table --table-name $table_name --query "Table.TableStatus" --output text)
		if [ $table_status != 'ACTIVE' ] && [ $status = 'active' ]
  	then
  		echo 'still updating the table, poll every 5 seconds'
  		sleep 5
  		status='creating'
  	fi
	done
}

#Function to run a single test (Create table, Update table 1, Update table 2, Delete table)
table_test_run() {
	SECONDS=0

	#create table, then wait until it is created (using built it 'cli' wait feature)
	echo "Starting table $table_name creation..."
	aws dynamodb create-table --table-name $table_name --attribute-definitions file://table_create_defs --key-schema file://table_create_key_schema --global-secondary-indexes file://table_create_gsi --provisioned-throughput file://table_create_throughput

	echo "Create table successfull. Waiting for it to become ACTIVE"
	aws dynamodb wait table-exists --table-name $table_name

	create_duration=$SECONDS
	echo "Table creation complete and ACTIVE"
	echo "Time taken: $(($create_duration / 60)) minutes and $(($create_duration % 60)) seconds"

	#update table, then wait until it is active (using custom poll_describe_table function)
	#update 1
	echo "Starting update 1..."
	aws dynamodb update-table --table-name $table_name --attribute-definitions file://table_update_defs --global-secondary-index-updates file://table_update_gsi_1 --billing-mode PAY_PER_REQUEST

	poll_describe_table

	let update_1_duration=$SECONDS-$create_duration
	echo "Table update 1 complete"
	echo "Time taken: $(($update_1_duration / 60)) minutes and $(($update_1_duration % 60)) seconds"

	#update 2
	echo "Starting update 2..."
	aws dynamodb update-table --table-name $table_name --attribute-definitions file://table_update_defs --global-secondary-index-updates file://table_update_gsi_2

	poll_describe_table

	let update_2_duration=$SECONDS-$create_duration-$update_1_duration
	echo "Table update 2 complete"
	echo "Time taken: $(($update_2_duration / 60)) minutes and $(($update_2_duration % 60)) seconds"

	#delete table, then wait until it is deleted (using built in cli 'wait' feature
	echo "Starting table $table_name delete..."
	aws dynamodb delete-table --table-name $table_name
	aws dynamodb wait table-not-exists --table-name $table_name
	let delete_duration=$SECONDS-$create_duration-$update_1_duration-$update_2_duration
	echo "Table delete complete"
	echo "Time taken: $(($delete_duration / 60)) minutes and $(($delete_duration % 60)) seconds"

	println
	let total_test_time=$SECONDS
	echo "TOTAL TIME FOR TEST: $(($total_test_time / 60)) minutes and $(($total_test_time % 60)) seconds"	
}

for i in $(seq 1 $number_of_tests)
do
table_test_run
println
sleep 5
echo "Test Run 2"
done

exit 0
