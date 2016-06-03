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
        tr -s -c "[:alnum:]\.\-\_\n" "_" | \
        sort >tmp_index
    grep "Successfully uploaded" "$log" | \
        perl -ne 'print "$1\n" if (m/Successfully uploaded (.*) to/)' | \
        tr -s -c "[:alnum:]\.\-\_\n" "_" | \
        sort >tmp_upload
    comm -23 tmp_index tmp_upload >> "$errlog"
    rm tmp_upload tmp_index

    #Determine how many of each error occurs
    exist=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "File does not exist"`
    r=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "Cannot read file"`
    empty=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "File is empty"`
    sym=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "File is a symbolic link"`
    o=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "The file handle is open"`
    bin=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "The file is binary"`
    ukn=`grep "\[ERROR\] Cannot" "$errlog" | grep -c "Unknown error"`

    #Display the results
    echo "$exist - Non-existant files" >> "$errlog"
    echo "$r - Non-readable files" >> "$errlog"
    echo "$empty - Empty files" >> "$errlog"
    echo "$sym - Symbolic files" >> "$errlog"
    echo "$o - File is open" >> "$errlog"
    echo "$bin - Binary files" >> "$errlog"
    echo "$ukn - Unknown errors" >> "$errlog"

    #check if any serious errors occured.
    if [[ $((exist + r + o + bin + ukn)) -eq 0 ]]; then
        echo "No serious errors. Nothing to worry about." >> "$log"
        exit 0
    else
        echo $((exist + r + +o + bin + ukn + empty + sym)) " errors found!" >> "$log"
        exit 2
    fi
fi

exit 0
