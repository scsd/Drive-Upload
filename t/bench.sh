#!/bin/bash

#This file will serve as a way of benchmarking different
#versions of the scripts.

#Load the configs.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR"/config

#Go to the git repo.
cd "$DIR"/

#Figure out the name of the output file
file="run.log"
errLog="run.err"
#Start the timer
begin=`date "+%s"`
#Run the script
../driveUpload.pl -a "$address" -e "$errLog" -m "$uploads" -u "$user" $loc &> "$file"
#Get exit code
codeUpload="$?"
#End the timer
end=`date "+%s"`
#Figure out how log the script took to run.
totalTime=`echo "$end-$begin" | bc`
echo "Script took $totalTime seconds to run." >> "$file"
#Get how big the filesystem uploaded is.
du -sh $loc >> "$file"
echo "" >> "$file"
./check.sh "$file" "$errLog"
codeCheck="$?"
#Send a notification when done
if [[ $codeUpload -eq 0 && $codeCheck -eq 0 ]]; then
    echo "$branch upload complete"
    notify-send -u normal "$branch branch upload" "Upload Complete"
else
    #Check the exit codes.
    if [[ $codeUpload -ne 0 ]]; then
        echo "The upload script failed with code: $codeUpload" >> "$file"
    else
        echo "The checks failed with code: $codeCheck" >> "$file"
    fi
    notify-send -u critical "$branch branch upload" "Upload Failed, error code: $code"
    cat "$file" | mail -s "Upload test failed - log" "$address"
    cat "$errLog" | mail -s "Upload test failed - errors" "$address"
fi

#Compose a small analisys of the uploads
tail -n 15 "$file" | mail -s "Branch Benchmark Analisys" "$address"

#Clean up.
rm "$file" "$errLog"
