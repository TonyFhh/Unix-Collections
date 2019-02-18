#!/bin/bash

# Script: Provide a argument .txt file
# Check and Read Config: This script will then copy all the config files to $OUTDIR and summarise into xlsx file
# Write Config from XLSX: Write from xlsx file to new config files at $OUTDIR (xlsx file reference should not be placed at that directory)
# Parse Src/Tgt: Experimentary platform - Parse the files in src/tgt folders then try to determine correct mappings/uniq keys and generate new cfg if necessary
# Update Name Parameters: Match all naming parameters of config files to config file name.
# Update Split File config: Apply any changes from main config to its splitted file configs.

# Latest Changes: 27 Sep 2018
# Details: Modified dos2unix command to only perform on sampling 10 line file to improve execution time. (dos2unix command would normally be performed by reconcile.sh)

function main() {

OUTDIR=<DIR1> #Removed to preserve confidentiality
HOMEDIR=<DIR2> #Removed to preserve confidentiality
REPORTDIR=<DIR3> #Removed to preserve confidentiality

#Script introduces itself
echo "General Purpose support tool used to automate some aspects of handling config files. Featuring...

Check and Read Config:
Reads selected config files from a reference list and consolidate all the information within into an excel file.

Write Config From XLSX:
From a reference xlsx file, write all the information within into new config files.

Parse Src/Tgt:
Checks all available reports in $REPORTDIR/src(tgt)_reports, creating config files (if missing) or updating unique key/mapping

Update Name Parameters:
Checks all Name related parameters in configs, changing them to match config basename where applicable.

Update Split File Configs:
Regenerates all split file configs in $REPORTDIR/(reports) from the main config file.

NOTE: Any existing files from destination directory $OUTDIR will be wiped when starting the script"
        
echo -e "\r\nSelect a number option to proceed"

select opt in "Check and Read Config" "Write Config From XLSX" "Parse Src/Tgt" "Update Name Parameters" "Update Split File Configs" "Cancel"; do

mkdir -p $OUTDIR
rm -f $OUTDIR/*


case $opt in

    "Check and Read Config" )
    loopcount=0
    if [[ $1 == "" ]]
    then
        echo "No reference file was provided. ALL configs will be copied and tabulated. Proceed?"
        select subopt in "Ok" "Cancel"; do
        case $subopt in
            "Ok" )            
            for file in $HOMEDIR/config/*.cfg
            do
                readCFG $file
            done
            echo "$loopcount files copied"
            #Now make that csv into a useful excel file
            perl ConfigPrep.pm retrieveConfig > /dev/null
            rm -f configr.csv
            echo "Config information of all available config files have been consolidated to $OUTDIR/configr.xlsx"
            exit
            ;;
            "Cancel" )
            echo "Exiting..."
            exit
            ;;
        esac
        done
    else
        echo "Checking and Retrieving configs for files listed in $1..."
        awk '{$1=$1}1' $1 | cut -d "." -f 1 > tmp && mv tmp $1
        sort -uf -o $1 $1 #Remove trailing and leading spaces then remove duplicates
        rm -f ct_missing.log
        while read line || [[ -n $line ]]
        do
#            echo "line is $line"
            if [[ ! -z $line ]]
            then
                readCFG $( sed 's#$#.cfg#' <<< $line )
#                readCFG "$line.cfg" #test if the line is zero value if it is not run the function
            fi
#            echo "loopcount is $loopcount"
        done < $1
        

        # If there are any config files found, configr.csv will be generated through readCFG()
        if [[ -f configr.csv ]]
        then
            echo "$(($(wc -l < configr.csv) - 1 )) out of $loopcount files copied"
        
            perl ConfigPrep.pm retrieveConfig > /dev/null
            
            echo "Config information of all available config files have been consolidated to $OUTDIR/configr.xlsx"
            
            #Log which files didnt get copied"
            if  [[ $(($(wc -l < configr.csv) - 1 )) -lt $loopcount ]]
            then
                ls $OUTDIR/*.cfg | awk -F '[/.]' '{print $6}' > ct_copied.log
                echo "Unavailable configs have been logged to $HOMEDIR/ct_missing.log"
            fi
            
            rm -f configr.csv
        
        else
            echo "No available config files were found for all $loopcount files." 
        fi
        
        
        exit
    fi
    ;;
    
    "Write Config From XLSX" )
    if [[ $1 == "" || ! -f $1 || $1 != *".xlsx"* ]]
    then
        echo "Invalid xlsx reference file. Exiting"
        exit
    else
        perl ConfigPrep.pm writeToConfig $1
        echo "New config files have been created based on $1 at $OUTDIR."
        exit
    fi
    ;;
    
    "Parse Src/Tgt" )
    
    verifyST
    
    exit
    ;;
    
    "Update Name Parameters" )
    echo "Checking name parameters for all config files..."
    for cfg in $HOMEDIR/config/*.cfg
    do
        cfg_basename=$( awk -F '[/.]' '{print $6}' <<< $cfg )
        updateNames $cfg $cfg_basename "Source_File"
        updateNames $cfg $cfg_basename "Target_File"
        updateNames $cfg $cfg_basename "Mismatch_Report"
        updateNames $cfg $cfg_basename "Missing_Tgt_Data_Report"
    done
    echo "Check Complete, mismatching config name parameters have been corrected"
    exit
    ;;
    
    "Update Split File Configs" )
    # Update config of all existing splitted files in src_reports and reports
    update_split
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
    if [[ $1 != *"$HOMEDIR/config/"* ]]
    then
        file=$1
    else
        file=$( awk -F '/' '{print $NF}' <<< $1 )
    fi
    
#    echo "in function"
#    echo "1 is $1"
#    echo "file is $file"
    ((loopcount++))
    foundfile=$( find $HOMEDIR/config -iname "$file" )
#    echo "file is $file, foundfile is $foundfile"
    if [[ -z $foundfile ]]
    then
        echo "$(cut -d "." -f 1 <<< $file )" >> ct_missing.log
        return
    fi
    
    dos2unix -k -q $foundfile
    
    cp $foundfile $OUTDIR
    filename=$( cut -d "/" -f 6- <<< $foundfile | cut -d "." -f 1 )
#    echo "filename is $filename"

    if [[ ! -f configr.csv || $(wc -l < configr.csv) < 1 ]]
    then
        headers2=$(grep ':' $foundfile | cut -d ":" -f 1 | tr "\n" "\`" | sed 's#\`$#\n#')
#        echo "L117: $headers2"
        echo "File_Name\`$headers2" > configr.csv
    fi
    
    # main_params: contain all the data from first params but discarding the last line (Mapping:)
    main_params=$(grep ':' $foundfile | head -n -1 | cut -d ":" -f 2 | tr "\n" '`')
    mapping_range=$(( $(grep -n 'Mapping:' $foundfile | cut -d ":" -f 1) + 1 ))
    map_params=$( tail -n +${mapping_range} $foundfile | sed -e "s#[ \s]*=>[ \s]*#:#g" | tr "\n" ";" | sed 's#;$##')
    
    echo "$filename\`${main_params}${map_params}" >> configr.csv
    
}

function verifyST() {
    # Dependencies: ConfigPrep.pm, lookup/colref.csv
    
    # Notes/Limitations
    #0. This func can be called from main menu (not requiring arguments) - if successful can be baked into reconcile scripts instead.
    # function still cannot check for time columns and omit them (probably doable)
    # problematic reports like PL_ASAT => PL_ASAT_ORIG while tgt also has PL_ASAT will cause incorrect mappings (low occurance)
    
    # Main Algo flow:
    # Unix
    #1. Check if both files & config is already available
    #2. Get the various information like delimiter, no. of current mapping rows
    #3. Get the headers of both src/tgt files (Information from #2 can help trace correct header in reports)
    
    # in ConfigPrep.pm
    #4. While both headers in arrays
    #4a. Match same columns in same positions (most common scenario)
    #4b. Match same columns in different positions (occuring due to srccol != tgtcol or dev mistake)
    #4c. Match different columns through a lookup (some reports notorious for these are MY tsp_mrc_pl_ir_os kind reports)
    #4d. Whatever matched pass it back to unix in 'srcmapA:tgtmapA;srcmapB:tgtmapB;' type format
    
    # Unix again
    #5. Format the returned string properly
    #6. If Perl failed to match all columns perl will return a exit status -> Unix will error and skip that file
    #7. Else unix will replace all the mapping 
    
    #Check if config is available
    # Doesn't matter if i reference from src or tgt, i need both files to make this work
    
    echo "Checking config parameters for .csv and .txt files in app/CCR/P4SG_Reports/src_reports|tgt_reports..."
    
    total_count=0
    regen_count=0
    updated_count=0
    shopt -s nullglob
    for files in $REPORTDIR/src_reports/*.[cC][sS][vV] $REPORTDIR/src_reports/*.txt
    do
        ((total_count++))
#        echo "L150: file_s is $files"
        f_fullname=$( cut -d "/" -f 6 <<< $files )
        filet="$REPORTDIR/tgt_reports/$f_fullname"
        f_basename=$( cut -d "." -f 1 <<< $f_fullname )
#        echo "f_basename is $f_basename f_fullname is $f_fullname"
    
        if [[ ! -f $filet ]] #if other file does not exist
        then
            echo "$f_basename: Corresponding same name target file not found. skipping"
            continue #skip to next loop iteration
        else
        
            # Create some temporary files of first 10 lines to help process more quickly.
            head -n 10 $files > $files.temp
            head -n 10 $filet > $filet.temp
            dos2unix -q -k $files.temp
            dos2unix -q -k $filet.temp
            
            #DO some processing to try and eliminate false headers
            # grep -on will check the first line where '|' '~' ';' ',' first occurs (At least this works for headers like "MM Audit Confirmation as at 10/04/18" )
            # else if header contain those chars, file won't be changed and the python function will error out and require user intervention
            guess_head_src=$( grep -on '[|~;,^]' $files.temp | head -n 1 | cut -d ":" -f 1 )
            
            if [[ $guess_head_src -gt 1 ]]
            then
                sed -i "1,$(( $guess_head_src - 1 ))d" $files.temp
            elif [[ -z $guess_head_src ]]
            then
                echo "$f_basename: Unable to find suitable src delimiter, Please check report."
                rm $files.temp $filet.temp
                continue
            fi
            
            guess_head_tgt=$( grep -on '[|~;,^]' $filet.temp | head -n 1 | cut -d ":" -f 1 )
            if [[ $guess_head_tgt -gt 1 ]]
            then
                sed -i "1,$(( $guess_head_tgt - 1 ))d" $filet.temp
            elif [[ -z $guess_head_tgt ]]
            then
                echo "$f_basename: Unable to find suitable tgt delimiter, Please check report."
                rm $files.temp $filet.temp
                continue
            fi
        
            # If config not already available, create them.
            if [[ ! -f $HOMEDIR/config/$f_basename.cfg ]]
            then
                echo "$f_basename: Config file not found. Generating new one from template..."
                vST_sub_createcfg
                if [[ $? -gt 0 ]]
                then
                    rm $files.temp $filet.temp
                    continue
                fi
                ((regen_count++))

            else
                cp $HOMEDIR/config/$f_basename.cfg $OUTDIR
            fi  #End if - config not found
            
        
            sdel=$(grep -i "Source_separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 2)
            tdel=$(grep -i "Target_separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 2)
            
            if [[ -z $sdel || -z $( head -n 1 $files.temp | grep $sdel ) || -z $tdel || -z $( head -n 1 $filet.temp | grep $tdel ) ]]
            then
                echo "$f_basename: Unable to validate delimiter parameters, regenerating from template"
                vST_sub_createcfg
                
                #Once again try to get delim parameters
                sdel=$(grep -i "Source_separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 2)
                tdel=$(grep -i "Target_separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 2)
            fi
            
#            echo "guess_head_src is $guess_head_src, guess_head_tgt is $guess_head_tgt"
            src_head=$(head -n 1 $files.temp) #This badly assumes the first line to be the header, which may not the case
            tgt_head=$(head -n 1 $filet.temp)
            
            #Thus needs error handling.
            
            #Still haven't filter time based columns - COuld probably do a head 10 check for ":" and "time" then sed out
#                echo "src_head is $src_head, tgt_head is $tgt_head, src_del is $sdel, tgt_del is $tdel"
            full_map_debug=$( perl ConfigPrep.pm getMapping "$src_head" "$tgt_head" "$sdel" "$tdel" )
#                echo "$files: full_map_debug is $full_map_debug" >> ct.log        
            full_map=$( perl ConfigPrep.pm getMapping "$src_head" "$tgt_head" "$sdel" "$tdel" | tail -n 1)
            

            
            if [[ $full_map == "error" ]] #Can't get perl error codes to work somehow, this will do for now.
            then
                echo "$f_basename: Unable to auto map all columns, manual edit recommended, Skipping"
                rm $OUTDIR/$f_basename.cfg
                rm $files.temp $filet.temp
                continue
            else
                full_map=$( sed -e 's#:# => #g' -e 's#;$##' -e 's#;#\n#g' <<< $full_map )
                
                sed -i '24,$d' $OUTDIR/$f_basename.cfg
                echo "$full_map" >> $OUTDIR/$f_basename.cfg
#                perl -pi -e 'chomp if eof' $OUTDIR/$f_basename.cfg #Remove the newline at the end, though it doesn't matter
            fi
            
            #Evaluate unique keys
            vST_sub_parse_ukey
            
            # Apply Tolerance % if there is src key lookup
            tp_line=$( grep -n 'Tolerance_Percentage:' ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
            echo "tp_line is $tp_line"
            #This has flaws against contract mapping
            if [[ ! -z $( grep 'Src_Keys_Lookup:' ConfigTool/$f_basename.cfg | cut -d ":" -f 2) ]]
            then
                #Try to look for Common mismatched stuff
                # Regex: Search for *Contract/Trade, Root(and any number of strings that follows after), Package etc within the mapping
                # Then replace ' =>' onwards with the tolerance application, convert \n to , then append to Tolerance percentage
                
                if [[ $( grep 'Src_Keys_Lookup:' ConfigTool/$f_basename.cfg | cut -d ":" -f 2) =~ CONTRACT ]]
                then
                    tp_in=$(grep -iP '^[\w ]{0,6}(((ORIG.*)?TRADE|COMPONENT|ROOT.*|PACKAGE|SERIAL|GID|GLOBAL)[ _]?(No|Number|ID)?) \=\>' ConfigTool/$f_basename.cfg | sed 's# =>.*#=>10000#' | tr '\n' ',' | sed 's#,$##' )
                else
                    tp_in=$(grep -iP '^[\w ]{0,6}(((ORIG.*)?CONTRACT|ROOT.*|PACKAGE|SERIAL|GID|GLOBAL)[ _]?(No|Number|ID)?) \=\>' ConfigTool/$f_basename.cfg | sed 's# =>.*#=>10000#' | tr '\n' ',' | sed 's#,$##' )
                fi
                #Try to look for Common mismatched stuff
                # Regex: Search for *Contract, Root(and any number of strings that follows after), Package etc within the mapping
                # Then replace ' =>' onwards with the tolerance application, convert \n to , then append to Tolerance percentage
                echo "$f_basename: tp_in is $tp_in"
                sed -i "${tp_line}s#Tolerance_Percentage:.*#Tolerance_Percentage:$tp_in#" ConfigTool/$f_basename.cfg
            fi
            
            if [[ -f $HOMEDIR/config/$f_basename.cfg && ! -z $( diff $OUTDIR/$f_basename.cfg $HOMEDIR/config/$f_basename.cfg ) ]]
            then
                echo "$f_basename: Config updated" | tee --append $OUTDIR/ct.log
                diff $OUTDIR/$f_basename.cfg $HOMEDIR/config/$f_basename.cfg | grep '<' | sed -e 's#<#+#' >> $OUTDIR/ct.log
                diff $HOMEDIR/config/$f_basename.cfg $OUTDIR/$f_basename.cfg | grep '<' | sed -e 's#<#-#' >> $OUTDIR/ct.log
                echo "" >> $OUTDIR/ct.log
                ((updated_count++))
            elif [[ ! -f $HOMEDIR/config/$f_basename.cfg && -f $OUTDIR/$f_basename.cfg ]]
            then
                echo -e "$f_basename: Config generated from template\n" >> $OUTDIR/ct.log
            else
                # Since thee are no changes to config, there's no need to duplicate it and confuse things (Option 1 is made for this)
                echo "$f_basename: no changes so removing"
                rm $OUTDIR/$f_basename.cfg
            fi
        
            rm $files.temp $filet.temp # Clear temporary files
        fi #ENd if both files are there   
    done
    
    echo -e "\n(Re)Generated config files: $regen_count"
    echo "Updated config files: $updated_count"
    echo "Total files parsed: $total_count"
    
    if [[ $updated_count -ge 1 ]]
    then
        echo -e "\nDetails on updated parameters can be found in home/ownccr/rgClient/ConfigTool/ct.log"
    fi
}

vST_sub_createcfg () {
    cp $HOMEDIR/config/template.txt $OUTDIR/$f_basename.cfg
    
    #Edit new config filename related parameters (grepping the header might be better instead of hardcoding sed)
    sed -i "4s#\$#$f_fullname#" $OUTDIR/$f_basename.cfg #Append to line corresponding to "Source_File" field
    sed -i "5s#\$#$f_fullname#" $OUTDIR/$f_basename.cfg # ~ "Target_File" field
    sed -i "6s#\$#$f_basename#" $OUTDIR/$f_basename.cfg
    sed -i "7s#\$#$f_basename#" $OUTDIR/$f_basename.cfg
    
    #Here i need to figure out algorithm to guess the seperators correctly
    
    #Delimiters can be | , ; ~
    # If i work based on these assumptions
    # Header rows tend to not contain any misleading delimiters, but it could be hard to correctly identify header rows
    #   when we are trying to GUESS the config settings here
    
    # Something to start with:
    # Parse the 4 delimiters line by line for the first line. As long as one of the liens contain 0 instances of the delimiter class, abort and skip it completely.
    # Tabulate these data into arrays then utilise a concept similar to the one used to deal with headers...
    
    
    
    sdel=$(python -c "import commonfunc; commonfunc.guess_delimiter(\"$files.temp\")" 2> /dev/null)
#    echo "$f_basename: sdel is $sdel"
    tdel=$(python -c "import commonfunc; commonfunc.guess_delimiter(\"$filet.temp\")" 2> /dev/null)
#    echo "$f_basename: tdel is $tdel"
    
    
    
    if [[ -z $sdel ]]
    then
        echo "$f_basename: Unable to find any common delimiters in src report"
        return 1 #Function "exit" error code to skip this file due to unexpected errors
    fi
    
    if [[ -z $tdel ]]
    then
        echo "$f_basename: Unable to find any common delimiter in tgt report"
        return 1
    else
        sSep_line=$( grep -n "Source_Separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 1 )
        tSep_line=$( grep -n "Target_Separator" $OUTDIR/$f_basename.cfg | cut -d ":" -f 1 )
        
#                    echo "sSep is $sSep"
#                    echo "tSep is $tSep"
        
        sed -e "${sSep_line}s#\$#$sdel#" -e "${tSep_line}s#\$#$tdel#" -i $OUTDIR/$f_basename.cfg
        
        # Maybe here we can Try to guess unique keys and source key lookup
        
        #Guess sklookup - TRADE ID variants
        # 1. Too many variants? - even TRADE also considered, see COMPONENT_ID too
        #grep -o "${del}*TRADE[ _][ID|NO|NUMBER]*${del}" sample.txt
    fi
}

vST_sub_parse_ukey () {
    
#    echo "enter func"
    
    #General flow:
    # First check against common unique key names
    # Then parse each awk NF for alphabatical only fields
    # Try to ensure it doesnt surpass some arbitrary number
    
    uskey_line=$(grep -n 'Source_Key:' ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
    utkey_line=$(grep -n 'Target_Key:' ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
    slookup_line=$( grep -n 'Src_Keys_Lookup:' ConfigTool/$f_basename.cfg | cut -d ":" -f 1 )
    mapping_line=$(( $( grep -n 'Mapping:' ConfigTool/$f_basename.cfg | cut -d ":" -f 1 ) + 1 ))
    
    # Before all else: Verify that current Unique keys (if exists) is still valid with new mapping
    uniq_skey=$( grep "Source_Key" ConfigTool/$f_basename.cfg | cut -d ":" -f 2 )
    if [[ ! -z $uniq_skey ]]
    then
#    echo "L428: uniq_skey wasn't zero"
        IFS=,
        for key in $uniq_skey #Loop through every Source Key entry, 
        do
            inkey=$( tail -n +${mapping_line} ConfigTool/$f_basename.cfg | grep -w $key ) #Search for skey in mapping and get its corresponding tgt map column
            if [[ -z $inkey ]]
            then
                echo "$f_basename: invalid key found, regenerating source keys from scratch"
                uk_regen=true
                break
            fi
        done
        unset IFS
        
#        echo "uk_regen is $uk_regen"
    
        if [[ $uk_regen == true ]]
        then
#            echo "L444: uk_regen true: clearing"
            # Clear all the unique key values
            sed -i "${uskey_line}s#Source_Key:.*\$#Source_Key:#" ConfigTool/$f_basename.cfg
            sed -i "${utkey_line}s#Target_Key:.*\$#Target_Key:#" ConfigTool/$f_basename.cfg
            sed -i "${slookup_line}s#Src_Keys_Lookup:.*\$#Src_Keys_Lookup:#" ConfigTool/$f_basename.cfg
        else
#            echo "L444: uk_regen not true: returning"
            return
        fi
        unset uk_regen
    fi  
    
    # Part 1: First check for common unique keys found
    shopt -s nocasematch
#    echo "src_head is $src_head"
    case $src_head in
    *TRADE*|*Component*)
        
        # Regex Explanation:
        # It looks for any variant of <Trade>< ><Id>, <Component><_><number>, catching them in 3 seperate blocks
        # then searches in front of the first block <Trade..> matching any letter,digit,space or underscore denoted by [\w ]
        # stopping at the first encountered character that doesn't fulfill criteria (*), but checks from right to left (? - regex lazy denonation)
        # this regex can matche instances like "Mega Long Mix_of_Trade id"
        inkey=$(grep -oiP "\b[\w ]{0,4}?(Trade|Component|(Exer.*[\w ])?Deal)[ _](id|no|number)\b" <<< $src_head | head -n 1 | tr '\n' ',' )
#        echo "Trade case: inkey is $inkey"
        sed -i "${uskey_line}s#\$#$inkey#" ConfigTool/$f_basename.cfg
        sed -i -e "${slookup_line}s#\$#$inkey#" -e "${slookup_line}s#,\$##" ConfigTool/$f_basename.cfg #Append to src key lookup too.
        ;;&
    *Counterpart*|*PORTFOLIO*)        
        inkey=$(grep -oiP '\b[\w ]*?(Counterpart[y]?|PORTFOLIO)[\w ]*?\b' <<< $src_head | tr '\n' ',' ) #Match portfolio and any words that comes after (ie. portfolio_label if is there, would match too)
#        echo "run CCP,PORTFOLIO case: inkey is $inkey"
        sed -i "${uskey_line}s#\$#$inkey#" ConfigTool/$f_basename.cfg
        ;;& #DOn't break, continue on in switch case
    *TYPOLOGY*)        
        inkey=$(grep -oiP "[^${sdel}]*TYPOLOGY\b" <<< $src_head | tr '\n' ',' ) #Match partial string 'typology' and return the full word (ie. COntract Typology, Product Typology etc would match)
#        echo "typlogy case: inkey is $inkey"
        sed -i "${uskey_line}s#\$#$inkey#" ConfigTool/$f_basename.cfg
        ;;&
    *Family*|*Group*|*Type*)        
        inkey=$(grep -oiP "[^${sdel}]*(Family|Group|Type)\b" <<< $src_head | tr '\n' ',' )
#        echo "F/G/T case: inkey is $inkey"
        sed -i "${uskey_line}s#\$#$inkey#" ConfigTool/$f_basename.cfg
        ;;&
    *CCY|*Currency*) # Need to redesign this regex       
        inkey=$(grep -oiP "[^${sdel}]*(Currency|CCY)\b" <<< $src_head | tr '\n' ',' )
#        echo "CCY case: inkey is $inkey"
        sed -i "${uskey_line}s#\$#$inkey#" ConfigTool/$f_basename.cfg
        ;;&
    esac
    
    shopt -u nocasematch
    uniq_skey_count=$( sed -n "${uskey_line}p" ConfigTool/$f_basename.cfg | awk -F ',' '{print NF}' )
    
#    echo "FIrst part done, put $uniq_skey_count fields"
    
    #Part 2: iterate through each column (with awk print) and find (alphabatical data) -can include sort -u functonality too.
#    echo "sDel is $sdel"
    no_col=$( awk -F "${sdel}" '{print NF}' $files.temp | head -n 1 )
    no_line=$( wc -l < $files.temp )
    
#    echo "no_col is $no_col"
    for i in $( seq 1 $no_col )
    do
        sect_head=$( awk -F "${sdel}" -v tgt=$i '{print $tgt}' $files.temp | head -n 1 )
        if [[ ! -z $( sed -n "${uskey_line},${uskey_line}p" ConfigTool/$f_basename.cfg | grep -w "$sect_head" ) ]]
        then
#            echo "L467: $sect_head is already a unique key, skipping"
            continue
        else
            if [[ $( awk -F "${sdel}" -v tgt="$i" '{print $tgt}' $files.temp | tail -n +2 ) =~ [A-Za-z] ]] #Leave it at matching only alphabets. 
            then
#                echo "L472: Added $sect_head to unique key"
                sed -i "${uskey_line}s#\$#$sect_head,#" ConfigTool/$f_basename.cfg
#            else
#                echo "$sect_head: nope"
            fi
        fi
    done
    unset no_col no_line sect_head
    
    # Tidy up src key then copy contents to tgt_key
    
    uniq_skey=$( grep "Source_Key" ConfigTool/$f_basename.cfg | cut -d ":" -f 2 | tr ',' '\n' | uniq -u | tr '\n' ',' | sed 's#,*$##' )
#    echo "L564: $( grep "Source_Key" ConfigTool/$f_basename.cfg | cut -d ":" -f 2 | tr ',' '\n' | uniq -u )"
#    echo "L565: $uniq_skey"
    sed -i "${uskey_line}s#Source_Key:.*\$#Source_Key:${uniq_skey}#" ConfigTool/$f_basename.cfg
#    sed -i "${uskey_line}s#,*\$##" ConfigTool/$f_basename.cfg #Remove , at end of line    
    IFS=,
    for key in $uniq_skey #Loop through every Source Key entry, 
    do
        inkey=$( tail -n +${mapping_line} ConfigTool/$f_basename.cfg | grep -w "=> $key$" | head -n 1 | sed 's#^.*=> ##' ) #Search for skey in mapping and get its corresponding tgt map column
        sed -i "${utkey_line}s#\$#$inkey,#" ConfigTool/$f_basename.cfg
    done
    unset IFS
#    echo "L575: $( grep "Target_Key" ConfigTool/$f_basename.cfg | cut -d ":" -f 2 ) "
    sed -i "${utkey_line}s#,*\$##" ConfigTool/$f_basename.cfg #Remove , at end of line for tgt uniq key
}

updateNames () {
    cfg=$1
    basename=$2
    field=$3
    
#    echo "cfg is $cfg, basename is $basename, field is $field"
    if [[ $field == "Source_File" || $field == "Target_File" ]]
    then

        getfield=$( grep "$field" "$cfg" | awk -F '[:/.]' '{print $(NF-1)}' )
#        echo "$field: getfield is $getfield"
        if [[ ! -z $getfield && $getfield != $basename ]] #What happens if SOurce_File is not there? i guess unlikely
        then
            getfieldline=$( grep -n "$field" $cfg | cut -d ":" -f 1 )
#            echo "$field: getfieldline is $getfieldline"
            sed -i "${getfieldline}s#$getfield#$basename#" $cfg
            c_trigger=true
        fi
    else

        getfield=$( grep "$field" "$cfg" | awk -F '[:/]' '{print $NF}' )
#        echo "$field: getfield is $getfield"
        if [[ ! -z $getfield && $getfield != $basename ]] #What happens if SOurce_File is not there? i guess unlikely
        then
            getfieldline=$( grep -n "$field" $cfg | cut -d ":" -f 1 )
#            echo "$field: getfieldline is $getfieldline"
            sed -i "${getfieldline}s#$getfield#$basename#" $cfg
            c_trigger=true
        fi
    fi    
}

update_split () {    
    CONFIG_DIR="$HOMEDIR/config"
    # Search files with _aa in their names, and note down the base name, remove last 7 chars (typical 'report_aa.ext' -> 'report' ) then remove all '/' before files
    if [[ ! -z $( find $REPORTDIR/src_reports -maxdepth 2 -type f -name "*_aa.*" ) ]]
    then
        split_list=$( find $REPORTDIR/src_reports -maxdepth 2 -type f -name "*_aa.*" | sed 's#.\{7\}$##' | awk -F '/' '{print $NF}' )
        for file in $split_list
        do
            if [[ -f $CONFIG_DIR/$file.cfg ]]
            then
#                echo "L586: file is $file"
                for split in $(find $REPORTDIR/src_reports -maxdepth 2 -type f -name "${file}_*" | sed 's#.\{4\}$##' | awk -F '/' '{print $NF}' )
                do
#                echo "L588: split is $split"
                    sed -e "s/$file/$split/g" $CONFIG_DIR/$file.cfg > $CONFIG_DIR/$split.cfg
                done
                echo "$file: split file configs updated"
            else
                echo "$file: Config not found, unable to update split files"
            fi
        done
    else
        echo "config_tool.sh did not find any _aa type files for config updates"
    fi
}
    
main "$@"    