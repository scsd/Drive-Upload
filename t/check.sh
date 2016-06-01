#!/bin/bash

#Check that the upload has moved all of the files it set out to.

log="$1"
if [[ "$log" == "" ]]; then echo "No file given"; exit 1; fi

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
    diff=`comm -3 tmp_index tmp_upload`
    rm tmp_upload tmp_index
    echo "$diff" >> "$log"
    i=0
    sum=""
    for name in $diff;
    do
        #Check how many lines in each file.
        if [[ `wc -l "$name" | perl -ne 'print "$1" if (m/^(\d+) /)'` -ne 0 ]]; then
            i=$((i+1))
            sum="$name, $sum"
        fi
    done
    #If any of the files were not blank, there was an error.
    if [[ "$i" -gt 0 ]]; then
        echo "Error: Some files did not upload properly: $sum" >> "$log"
        exit 1
    else
        echo "Some blank files were skipped: $sum" >> "$log"
        exit 0
    fi
fi

exit 0
