#!/bin/bash

# Many of the sensitive script content have been removed/changed to protect confidentiality.

#author: <removed>
#enhanced by: (Tony) Foo Hee Haw
#version: 1.4
#Description: Collect and generated the summary report with generation status from the logs
#Latest Changes: Added feature to automatically process the csv file and perform simple data analysis on the summarised results
#


main () {




echo "Retrieving information from all present .stdout log files at $sourceDir..."
echo "file_name|date|status|mismatches|missing(tgt)|missing(src)|record_count(tgt)|record_count(src)|lookup_mapped_no|no_of_src_col|no_of_tgt_col|mapped_col|lookup_key|source_key|mismatched_columns" > <Dir>/results_summary.csv
for line in <Dir>/logs/*.stdout; do

    filename=$(echo $line | cut -d "/" -f 6- | cut -d "." -f 1)
    processInfo
    echo "$filename - $status"

done

analyseResults

echo "Results consolidation file generated at <Dir>."
}

processInfo() {

    status=""
    datetime=$(date -r $line "+%d/%m/%y %R")
    records_in_target=$(tail -n 20 $line | grep "Total No of Records in Target" | cut -d ":" -f 7 | sed 's#.$##')
    records_in_source=$(tail -n 20 $line | grep "Total No of Records in Source" | cut -d ":" -f 7 | sed 's#.$##')

#cfg_name=`grep "Generating excel file" $line|awk '{print $11}'|sed -e s,$sourceDir,,|cut -d "." -f1`
    mismatches=$(tail -n 20 $line | grep "No of Records with mismatches" | cut -d ":" -f 7 | sed 's#.$##')
    mismatch_list=$(tail -n 20 $line | grep "List of Mismatch Columns" | cut -d ":" -f 2 | sed 's#;$##')
 #   missing_in_target=$(tail -n 20 $line | grep 'Number of Records missing in target' $line| cut -d ":" -f 7 | sed 's#.$##')
 #   missing_in_source=$(tail -n 20 $line | grep 'Number of Records missing in source' $line| cut -d ":" -f 7 | sed 's#.$##')
    missing_in_target=$(tail -n 20 $line | grep 'Target missing' | cut -d ":" -f 7 | sed 's#.$##')
 #   echo `tail -n 20 $line | grep 'Target missing' | cut -d ":" -f 7 | sed 's#.$##'`
    missing_in_source=$(tail -n 20 $line | grep 'Source missing' | cut -d ":" -f 7 | sed 's#.$##')
    uniq_key=$(tail -n 20 $line | grep "List of Source Keys" | cut -d ":" -f 2 | sed 's#;$##')
    src_head_count=$(tail -n 20 $line | grep 'No of Columns in SRC' | cut -d ":" -f 2)
    tgt_head_count=$(tail -n 20 $line | grep 'No of Columns in TGT' | cut -d ":" -f 2)
    map_col_count=$(tail -n 20 $line | grep 'Columns Mapped Count' | cut -d ":" -f 2)
    lookup_key=$(head -n 10 $line | grep 'Key Look-up field' | cut -d ":" -f 2)
    mapped_lookup_count=$(tail -n 20 $line | grep 'No of Records mapped in Lookup' | cut -d ":" -f 7 | sed 's#.$##')

#Write a switch case for status:
    if [[ $records_in_target == 0 || $records_in_source == 0 ]] 
    then    
        status="No Data"
    elif [[ $map_col_count == 0 ]]
    then
        status="Header issue"
    elif [[ $mismatches -gt 0 || $missing_in_target -gt 0 || $missing_in_source -gt 0 ]]
    then
        status="Not matched"
    elif [[ $mismatches == 0 && $missing_in_target == 0 && $missing_in_source == 0 ]]
    then
        status="Matched"
    else
        status="Generated with Error"
    fi
    

    echo "$filename|$datetime|$status|$mismatches|$missing_in_target|$missing_in_source|$records_in_target|$records_in_source|$mapped_lookup_count|$src_head_count|$tgt_head_count|$map_col_count|$lookup_key|$uniq_key|$mismatch_list" >> <Dir>/results_summary.csv

}

analyseResults() {

    split_files_list=$( grep "_aa|" <Dir>/results_summary.csv )
    if [[ ! -z $split_files_list ]]
    then
        #Set IFS to '\n'
        IFS=
        
        # Loop through every split file found
        while read entry
        do
  #          echo "entry is $entry"
            all_aa=$( cut -d "|" -f 1 <<< $entry | sed 's#aa$##')
           
           
           #if multiple "aa"s of different names
          
           
           while read main_name
           do
#           echo "main name is $main_name ddd"
                all_info_mn=$( grep "$main_name" <Dir>/results_summary.csv )
      #          echo "$all_info_mn" > tony.log
                
                #Get all the info              
                sum_name=$(sed 's#_$##' <<< $main_name)
                
                sum_mismatch=$( awk -F '|' '{ sum += $4 } END {print sum}' <<< $all_info_mn )
                sum_misstgt=$( awk -F '|' '{ sum += $5 } END {print sum}' <<< $all_info_mn )
                sum_misssrc=$( awk -F '|' '{ sum += $6 } END {print sum}' <<< $all_info_mn )
                sum_tgtrec=$( awk -F '|' '{ sum += $7 } END {print sum}' <<< $all_info_mn )
                sum_srcrec=$( awk -F '|' '{ sum += $8 } END {print sum}' <<< $all_info_mn )
                sum_mapped=$( awk -F '|' '{ sum += $9 } END {print sum}' <<< $all_info_mn )
                sum_mm_colist=$( awk -F '|' '{print $15}' <<< $all_info_mn | tr ";" "\n" | sort -u | tr "\n" ";" )
                
                #Other info
                sum_date=$(tail -n 1 <<< $all_info_mn | cut -d "|" -f 2 )
                other_info=$( tail -n 1 <<< $all_info_mn | cut -d "|" -f 10-14 )
      #          echo "other_info is $other_info"
                
                
                if [[ ! -z $( awk -F '|' '{print $3}' <<< $all_info_mn | grep "Not matched") ]]
                then
                    sum_status="Not matched"
                else
                    sum_status="Matched"
                fi


                
                echo "$sum_name|$sum_date|$sum_status|$sum_mismatch|$sum_misstgt|$sum_misssrc|$sum_tgtrec|$sum_srcrec|$sum_mapped|$other_info|$sum_mm_colist" >> <Dir>/results_summary.csv
            done <<< $all_aa
        done <<< $split_files_list
    fi
    
    unset IFS
    
    #sort by date descending, then remove any duplicates based on filename, then sort by filename in ascending
    head -n 1 <Dir>/results_summary.csv >> <Dir>/results_summary.csv.sort
    tail -n +2 <Dir>/results_summary.csv| sort -r -t '|' -k2 | sort -u -t "|" -k1,1 >> <Dir>/results_summary.csv.sort;
    mv <Dir>/results_summary.csv.sort <Dir>/results_summary.csv
    
    # From here we'll use python/perl to convert the csv to excel then do some data analysis of its values
    ./consolidated_analysis.pl
    rm -f <Dir>/results_summary.csv
    
}

main "$@"
