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
#Clean up.
rm "$file" "$errLog"
#Start the timer
begin=`date "+%s"`
#Run the script
../driveUpload.pl -e "$errLog" -m "$uploads" -u "$user" $loc &> "$file"
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
    echo "upload complete"
    notify-send -u normal "Drive-Upload" "Upload completed successfully"
    #Compose a small analisys of the uploads
    tail -n 15 "$file" "$errLog" | mail -s "Benchmark Analisys" "$address"
else
    #Check the exit codes.
    if [[ $codeUpload -ne 0 ]]; then
        echo "The upload script failed with code: $codeUpload" >> "$file"
    else
        echo "The checks failed with code: $codeCheck" >> "$file"
    fi
    notify-send -u critical "Drive-Upload" "Upload Failed, see logs for details."
    cat "$file" | mail -s "Upload test failed - log" "$address"
    cat "$errLog" | mail -s "Upload test failed - errors" "$address"
fi
