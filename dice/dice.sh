#!/bin/bash

dice_value=$1

if [ -z "$dice_value" ]; then
    echo -e "\e[5;31;1;4mPlease enter a value.\e[0m"
    exit 1
fi

dice_value=printf "%d" ${dice_value}

echo "Rolling this dice - 1 to $dice_value"

roll=0
if [ $dice_value -eq $dice_value ]; then
    roll=$(((RANDOM % $dice_value)+1))
fi




echo "You rolled $roll out of $dice_value"

exit 0