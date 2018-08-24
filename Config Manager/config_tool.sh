#!/bin/bash

# Directories and some content have been removed to protect confidentiality

#Script: Provide a argument .txt file of all the files.
# Read: This script will then copy all the config files to <Dir> and summarise into xlsx file
# Write: Write from xlsx file to new config files at <Dir> (xlsx file reference should not be placed at that directory)
# Verify: Experimentary platform - Parse the files in x/y folders then try to determine correct mappings

# Latest Changes: 21 Aug 2018
# Details: Verify sub: Renamed from update: Now can guess delimiters, integration entirely with other features

function main() {

#Script introduces itself
echo 'config_tool.sh: Support tool used to automate certain aspects of handling config files. Featuring...
Read:   Reads selected config files from a reference list and consolidate all the information within into an excel file.
Write:  From a reference xlsx file, write all the information within into new config files.
Verify: Checks all available reports in <Dir>, creating config file (if missing) or updating mapping

NOTE: Any existing files from destination directory <Dir>/ConfigTool will be wiped when starting the script'
        
echo -e "\r\nSelect a number option to proceed"

select opt in "Read" "Write" "Verify" "Cancel"; do

rm -rf <Dir>/ConfigTool
mkdir -p <Dir>/ConfigTool

case $opt in

    "Read" )
    loopcount=0
    if [[ $1 == "" ]]
    then
        echo "No reference file was provided. ALL configs will be copied and tabulated. Proceed?"
        select subopt in "Ok" "Cancel"; do
        case $subopt in
            "Ok" )            
            for file in <Dir>/config/*.cfg
            do
                readCFG $file
            done
            echo "$loopcount files copied"
            #Now make that csv into a useful excel file
            perl ConfigPrep.pm retrieveConfig > /dev/null
            rm -f configr.csv
            echo "Config information of all available config files have been consolidated to <Dir>/ConfigTool/configr.xlsx"
            exit
            ;;
            "Cancel" )
            echo "Exiting..."
            exit
            ;;
        esac
        done
    else
        echo "Retrieving files as listed in $1..."
        while read line || [[ -n $line ]]
        do
#            echo "line is $line"
            [[ ! -z $line ]] && readCFG "$line.cfg" #test if the line is zero value if it is not run the function
#            echo "loopcount is $loopcount"
        done < $1
        echo "$(($(wc -l < configr.csv) - 1 )) out of $loopcount files copied"
        
        perl ConfigPrep.pm retrieveConfig > /dev/null
        rm -f configr.csv
        echo "Config information of all available config files have been consolidated to <Dir>/ConfigTool/configr.xlsx"
        exit
    fi
    ;;
    
    "Write" )
    if [[ $1 == "" || ! -f $1 || $1 != *".xlsx"* ]]
    then
        echo "Invalid xlsx reference file. Exiting"
        exit
    else
        perl ConfigPrep.pm writeToConfig $1
        echo "New config files have been created based on $1 at <Dir>/ConfigTool."
        exit
    fi
    ;;
    
    "Verify" )
    
    verifyST
    
    exit
    ;;
    
    "Cancel" )
    echo "Exiting"
    exit
esac
done
            
}

function readCFG() {

    # file variable will vary depending on whether this function was invoked from ref file copy or entire copy
    if [[ $1 != *"<Dir>/config/"* ]]
    then
        file=<Dir>/config/$1
    else
        file=$1
    fi
    
#    echo "in function"
#    echo "1 is $1"
#    echo "file is $file"
    ((loopcount++))
    ls $file &>/dev/null || return;
    dos2unix -q $file
    
    cp $file <Dir>/ConfigTool
    filename=$( cut -d "/" -f 6- <<< $file | cut -d "." -f 1 )

    if [[ ! -f configr.csv || $(wc -l < configr.csv) < 1 ]]
    then
        headers2=$(grep ':' $file | cut -d ":" -f 1 | tr "\n" "~" | sed 's#~$#\n#')
#        echo "L117: $headers2"
        echo "File_Name~$headers2" > configr.csv
    fi
    
    # main_params: contain all the data from first params but discarding the last line
    main_params=$(grep ':' $file | head -n -1 | cut -d ":" -f 2 | tr "\n" "~")
    mapping_range=$(( $(grep -n 'Mapping:' $file | cut -d ":" -f 1) + 1 ))
    map_params=$( tail -n +${mapping_range} $file | sed -e "s#[ \s]*=>[ \s]*#:#g" | tr "\n" ";" | sed 's#;$##')
    
    echo "$filename~${main_params}${map_params}" >> configr.csv
    
}

function verifyST() {
    # Dependencies: ConfigPrep.pm, lookup/colref.csv
    
    # Notes/Limitations
    #0. This func can be called from main menu (not requiring arguments) - if successful can be baked into reconcile scripts instead.
    # function still cannot check for time columns and omit them (probably doable)
    # problematic reports like column => column_A while tgt also has column will cause incorrect mappings (low occurance)
    
    # Main Algo flow:
    # Unix
    #1. Check if both files & config is already available
    #2. Get the various information like delimiter, no. of current mapping rows
    #3. Get the headers of both src/tgt files (Information from #2 can help trace correct header in reports)
    
    # in ConfigPrep.pm
    #4. While both headers in arrays
    #4a. Match same columns in same positions (most common scenario)
    #4b. Match same columns in different positions (occuring due to srccol != tgtcol or dev mistake)
    #4c. Match different columns through a lookup (some reports notorious for these are <removed> kind reports)
    #4d. Whatever matched pass it back to unix in 'srcmapA:tgtmapA;srcmapB:tgtmapB;' type format
    
    # Unix again
    #5. Format the returned string properly
    #6. If Perl failed to match all columns perl will return a exit status -> Unix will error and skip that file
    #7. Else unix will replace all the mapping 
    
    #Check if config is available
    # Doesn't matter if i reference from src or tgt, i need both files to make this work
    
    echo "Updating config Mapping for all files <Dir>..."
    
    total_count=0
    updated_count=0
    shopt -s nullglob
    for files in <Dir>/*.[cC][sS][vV] <Dir>/*.txt
    do
#        echo "L150: file_s is $files"
        f_fullname=$( cut -d "/" -f 6 <<< $files )
        filet="<Dir>/$f_fullname"
        f_basename=$( cut -d "." -f 1 <<< $f_fullname )
#        echo "f_basename is $f_basename f_fullname is $f_fullname"
    
        if [[ ! -f $filet ]] #if other file does not exist
        then
            echo "$f_basename: Corresponding same name target file not found. skipping"
            continue #skip to next loop iteration
        else
            if [[ ! -f <Dir>/config/$f_basename.cfg ]]
            then
                echo "$f_basename: Config file not found. Generating new one from template..."
                
                cp <Dir>/config/template.cfg <Dir>/ConfigTool/$f_basename.cfg
                
                #Edit new config filename related parameters (grepping the header might be better instead of hardcoding sed)
                sed -i "4s#\$#$f_fullname#" <Dir>/ConfigTool/$f_basename.cfg #Append to line corresponding to "Source_File" field
                sed -i "5s#\$#$f_fullname#" <Dir>/ConfigTool/$f_basename.cfg # ~ "Target_File" field
                sed -i "6s#\$#$f_basename#" <Dir>/ConfigTool/$f_basename.cfg
                sed -i "7s#\$#$f_basename#" <Dir>/ConfigTool/$f_basename.cfg
                
                #Here i need to figure out algorithm to guess the seperators correctly
                
                #Delimiters can be | , ; ~
                # If i work based on these assumptions
                # Header rows tend to not contain any misleading delimiters, but it could be hard to correctly identify header rows
                #   when we are trying to GUESS the config settings here
                
                # Something to start with:
                # Parse the 4 delimiters line by line for the first line. As long as one of the liens contain 0 instances of the delimiter class, abort and skip it completely.
                # Tabulate these data into arrays then utilise a concept similar to the one used to deal with headers...
                
                tail -n 10 $files > $files.temp
                tail -n 10 $filet > $filet.temp
                
                sdel=$(python -c "import commonfunc; commonfunc.guess_delimiter(\"$files.temp\")" 2> /dev/null)
#                echo "$f_basename: sdel is $sdel"
                tdel=$(python -c "import commonfunc; commonfunc.guess_delimiter(\"$filet.temp\")" 2> /dev/null)
#                echo "$f_basename: tdel is $tdel"
                
                rm $files.temp $filet.temp
                
                if [[ -z $sdel ]]
                then
                    echo "$f_basename: Unable to determine delimiter in src report"
                    continue
                fi
                
                if [[ -z $tdel ]]
                then
                    echo "$f_basename: Unable to determine delimiter in tgt report"
                    continue
                else
                    sSep=$( grep -n "Source_Separator" <Dir>/ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
                    tSep=$( grep -n "Target_Separator" <Dir>/ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
                    
#                    echo "sSep is $sSep"
#                    echo "tSep is $tSep"
                    
                    sed -e "${sSep}s#\$#$sdel#" -e "${tSep}s#\$#$tdel#" -i <Dir>/ConfigTool/$f_basename.cfg
                fi
            else
                cp <Dir>/config/$f_basename.cfg <Dir>/ConfigTool
            fi  #End if - config not found
            
            ((total_count++))
        
            src_delim=$(grep -i "Source_separator" <Dir>/ConfigTool/$f_basename.cfg | cut -d ":" -f 2)
            tgt_delim=$(grep -i "Target_separator" <Dir>/ConfigTool/$f_basename.cfg | cut -d ":" -f 2)
            
            src_head=$(head -n 1 $files)
            tgt_head=$(head -n 1 $filet)
            
            #Still haven't filter time based columns - COuld probably do a head 10 check for ":" and "time" then sed out
#                echo "src_head is $src_head, tgt_head is $tgt_head, src_del is $src_delim, tgt_del is $tgt_delim"
            full_map=$( perl ConfigPrep.pm getMapping "$src_head" "$tgt_head" "$src_delim" "$tgt_delim" | tail -n 1)
            
#                echo "full_map is $full_map"
            
            if [[ $full_map == "error" ]] #Can't get perl error codes to work somehow, this will do for now.
            then
                echo "$f_basename: Unable to auto map all columns, manual edit recommended, Skipping"
                continue
            else
                full_map=$( sed -e 's#:# => #g' -e 's#;$##' -e 's#;#\n#g' <<< $full_map )
                
                sed -i '24,$d' <Dir>/ConfigTool/$f_basename.cfg
                echo "$full_map" >> <Dir>/ConfigTool/$f_basename.cfg
                perl -pi -e 'chomp if eof' <Dir>/ConfigTool/$f_basename.cfg #Remove the newline at the end, though it doesn't matter
                echo "$f_basename: Mapping updated"
                ((updated_count++))
            fi
        fi #ENd if both files are there   
    done
    
    echo "Generated config files with updated Mappings for $updated_count out of $total_count files"
}
    
main "$@"    
