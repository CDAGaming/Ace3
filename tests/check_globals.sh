#!/bin/bash 

echo "Checking all Ace3 files"

for listing in `find .. -name "*.lua" -print`; do
	dir=`echo $listing | awk -F '/' '{print $2}'`
	file=`echo $listing | sed 's/^[^/]*\/[^/]*\/\(.*\)$/\1/'`
	if [[ $dir != "tests" && $dir != "benchs" ]]; then
		res=`luac -p -l "$listing" | grep SETGLOBAL`
		if [[ $? == 0 ]]; then
			echo -e "Found global in $listing:\n $res"
		fi;
	fi;
done
