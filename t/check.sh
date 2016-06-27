#!/bin/bash

#Check that the upload has moved all of the files it set out to.

log="$1"
errlog="$2"
if [[ "$log" == "" ]]; then echo "No log file given"; exit 1; fi
if [[ "$errlog" == "" ]]; then echo "No errlog file given"; exit 1; fi

#Tell the user how many files were indexed and how many were uploaded.
added=`grep -c "Adding file" "$log"`
uploads=`grep -c "Successfully uploaded" "$log"`
echo "" >> "$errlog"
echo "Files indexed: $added, files uploaded: $uploads" >> "$errlog"


#Check if the numbers are the same.
if [[ "$added" -ne "$uploads" ]]; then
    #They are not, so figure out why.
    echo "Files that differ:" >> "$errlog"
    grep "Adding file" "$log" | \
        tr "'" "-" | \
        perl -ne 'print "$1\n" if (m/Adding file \-(.*)\-/)' | \
        tr -s -c "[:alnum:]\.\n" "_" | \
        sort >tmp_index
    grep "Successfully uploaded" "$log" | \
        perl -ne 'print "$1\n" if (m/Successfully uploaded (.*) to/)' | \
        tr -s -c "[:alnum:]\.\n" "_" | \
        sort >tmp_upload
    comm -23 tmp_index tmp_upload >> "$errlog"
    rm tmp_upload tmp_index
    echo "" >> "$errlog"
    echo "" >> "$errlog"

    #Check how many of each error has happened.
    errors=`grep "\[ERROR\]" "$errlog" | \
        perl -pe "s/'.*'/***/; s/\d{4}\/\d{2}\/\d{2} \d{2}\:\d{2}\:\d{2} \- \[ERROR\]\s+//" | \
        sort | \
        uniq -c`

    #Check if any errors are serious.
    serious=`echo "$errors" | \
        grep -v "File is empty" | \
        grep -v "is a file, skipping" | \
        grep -v "symbolic link" | \
        wc -l`

    #Show the errors
    echo "$errors" >> "$errlog"

    #check if any serious errors occured.
    if [[ "$serious" -eq 0 ]]; then
        echo "No serious errors. Nothing to worry about." >> "$log"
        exit 0
    else
        echo "errors found!" >> "$log"
        exit 2
    fi
fi

exit 0
