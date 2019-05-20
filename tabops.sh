#!/bin/bash

SECONDS=0

for i in {1..500}
do
echo $i
done
duration=$SECONDS
echo "$(($duration / 60)) minutes and $((duration % 60)) seconds elapsed"


