#!/bin/bash

#Check that the upload has moved all of the files it set out to.

log="$1"
errlog="$2"
if [[ "$log" == "" ]]; then echo "No log file given"; exit 1; fi
if [[ "$errlog" == "" ]]; then echo "No errlog file given"; exit 1; fi

#Tell the user how many files were indexed and how many were uploaded.
added=`grep -c "Adding file" "$log"`
uploads=`grep -c "Successfully uploaded" "$log"`
echo "Files indexed: $added, files uploaded: $uploads" >> "$log"


#Check if the numbers are the same.
if [[ "$added" -ne "$uploads" ]]; then
    #They are not, so figure out why.
    echo "Files that differ:" >> "$log"
    grep "Adding file" "$log" | tr "'" "-" | perl -ne 'print "$1\n" if (m/Adding file \-(.*)\-/)' | sort >tmp_index
    grep "Successfully uploaded" "$log" | perl -ne 'print "$1\n" if (m/Successfully uploaded (.*) to/)' | sort >tmp_upload
    comm -23 tmp_index tmp_upload >> "$log"
    rm tmp_upload tmp_index

    #Check how many of the files were not blank
    count=`grep "\[ERROR\] Cannot" "$errlog" | grep -v -c "File is empty"`
    if [[ "$count" -eq 0 ]]; then
        echo "Blank files were skipped. Nothing to worry about." >> "$log"
        exit 0
    else
        echo "Some errors occurred. See the error log for details." >> "$log"
        exit 2
    fi
fi

exit 0
