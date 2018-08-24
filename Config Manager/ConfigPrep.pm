#!/usr/bin/perl
package ConfigPrep;

# Many of the sensitive content have been omitted to protect the confidentiality of the company.

#Legacy Code Reference
sub writeToConfig {

    my $refFile = $_[1] or die "Reference xlsx file not specified";
#    print "$refFile\n";

    use FindBin;
    use lib "$FindBin::<Dir>/pl5lib"; #That directory contains various custom installed perl libraries

    use strict;
    use warnings;

    use Spreadsheet::XLSX; #for .xlsx files

    my $excel = Spreadsheet::XLSX -> new ($refFile);
    my $fh;
    
    #Parse the entire workbook, create a config file with <header row>: <content> format
    # THe resultant file will look like the usual config file assuming the excel file is done correctly
    foreach my $sheet ( @{ $excel->{Worksheet} } ) {
#      printf ( "Sheet: %s\n", $sheet->{Name} );
      $sheet->{MaxRow} ||= $sheet->{MinRow};
      foreach my $row ( 1 .. $sheet->{MaxRow} ) {
        $sheet->{MaxCol} ||= $sheet->{MinCol};

        
        my $cfgname = $sheet->{Cells}[$row][0]->{Val};
#        printf ( "L28: cfgname is %s\n", $cfgname );
        open($fh, '>', "<Dir>/ConfigTool/$cfgname.cfg"); #Open file, writing (">" form) to it

        
        foreach my $col ( 1 .. $sheet->{MaxCol} ) {
          my $header = $sheet->{Cells}[0][$col]->{Val};
          my $cell = $sheet->{Cells}[$row][$col]->{Val};
    #      print "L37: cell is $cell";
            if (defined $cell && $cell ne '') {
                # If this is the mapping column
                if ( $col eq 23 ) {
                    print $fh "$header:\n";
                    $cell =~ s/:/ => /g; #Replace all ':' with ' => '
                    $cell =~ s/;/\n/g; #Replace all ';' with newline (\n)
                    print $fh "$cell";
                } else {
                    printf $fh "%s:%s\n", $header, $cell;
                }
            } else {
                printf $fh "%s:\n", $header; #if empty then just print "<header row>:"
            }
        }
        close $fh;
      }
    }
}

sub retrieveConfig {

    use FindBin;
    use lib "$FindBin::<Dir>/pl5lib";

    use strict;
    use warnings;

    use Excel::Writer::XLSX;
    
    my $workbook = Excel::Writer::XLSX->new("<Dir>/ConfigTool/configr.xlsx");
    
    my $worksheet = $workbook ->add_worksheet();
    
    my $textFormat1 = $workbook->add_format(font => 'Calibri', color => 'red', size => 11); # Add a format
    my $textFormat1B = $workbook->add_format(font => 'Calibri', color => 'blue', size => 11); # Add a format
    my $bgFormat = $workbook->add_format(bg_color => 'yellow');
    my $bgFormat1 = $workbook->add_format(font => 'Calibri', color => 'red', size => 11, bg_color => 'yellow');
    
    open(FH,"configr.csv")
    or die "File unavailable: $!\n";
    my ($x,$y) = (0,0);
    while (<FH>){
        chomp;
#        print "$_\n";
        my @list = split (/\~/, $_);
#        print join(", ", @list);
#        print "\nnext line\n";
        my $linecount = 1;
        foreach my $c (@list){

#            $c =~ s/,[\r\n]+$//;
            #Check if the directory paths and file name doesn't seem right (incorrect file ext, non matching etc)
            if ( $x > 0 && $y ==4 && $c !~ $list[0] && substr($c, -3) !~ /txt|csv|CSV/ ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            elsif ( $x > 0 && $y ==5 && $c !~ $list[0] && substr($c, -3) !~ /txt|csv|CSV/ ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            elsif ( $x > 0 && $y ==6 && $c ne $list[0] ) { #if != config name
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            elsif ( $x > 0 && $y ==7 && $c ne $list[0] ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            
            #Check if Src Separator and Tgt Separator are the same, else highlight
            # --------------------------------------------------------------------
            elsif ( $x > 0 && $y ==10 && $c ne $list[11] ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            elsif ( $x > 0 && $y ==11 && $c ne $list[10] ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }
            
            # Check Src Keys Lookup exists Corresponding Key Lookup File (and vice versa), and whether it exists in Src Key
            # -------------------------------------------------------------------------------------
            # Check if <Condition1>
            elsif ( $x > 0 && $y ==12 && $list[16] ne "" && $c !~ $list[16] ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }            
            # Check if <Condition2>
            elsif ( $x > 0 && $y ==16 && $c eq "" && $list[12] =~ /<pattern>/i ) {
                $worksheet->write($x, $y++, $c, $bgFormat);
            }
            # Check if <Condition3>
            elsif ( $x > 0 && $y ==20 ) {
                # we consider 2 scenarios: <scenario1>:
                if ( $list[16] ne "" && $c !~ /<pattern>/ ) {
                    $worksheet->write($x, $y++, $c, $bgFormat1);
                }
                # and <scenario2>
                elsif ( $list[16] eq "" && ( $c !~ /<pattern>/ && $c ne "" ) ) {
                    $worksheet->write($x, $y++, $c, $bgFormat1);
                }
                else {
                    $worksheet->write($x, $y++, $c);
                }
            }
                
            else {
            $worksheet->write($x, $y++, $c);
            }
        }
    #    $linecount++;
        $x++; $y=0;
    }
    close(FH);
    $worksheet->freeze_panes( 1,0 );
    $workbook->close(); 
    
}

sub getMapping {
    
    use FindBin;
    use lib "$FindBin::<Dir>";

    use strict;
    use warnings;
    use Data::Dumper;
    
    #Get the unix variables ( 1- src head 2- tgt head 3- src del 4- tgt del)
    my $srcHeadString = $_[1] or die "Source Headers unspecified";
    my $tgtHeadString = $_[2] or die "Target Headers unspecified";
    my $sDel = $_[3] or die "Source Delimiter unspecified";
    my $tDel = $_[4] or die "Target Delimiter unspecified";
    
    print "srcHeadString is $srcHeadString\n";
    print "tgtHeadString is $tgtHeadString\n";
    print "sDel is $sDel\n";
    print "tDel is $tDel\n";
    
    my @srcHead = split /\Q$sDel/, $srcHeadString; #\Q ensure it escapes properly
    my @tgtHead = split /\Q$tDel/, $tgtHeadString;
    print "srcHead_1 is $srcHead[0]\n";
    print "srcHead_1 is $srcHead[1]\n";
    print "srcHead_1 is $srcHead[2]\n";
    print "tgtHead_1 is $tgtHead[1]\n";
    
    my @srcHeadFinal = @srcHead;
    my @tgtHeadFinal = @tgtHead;
    my $mapping;
    `dos2unix -q col_ref.csv`;
    for my $i (0 .. $#srcHead) {
        print "i is $i\n";
        print "srcHead is $srcHead[$i], tgtHead is $tgtHead[$i]\n";
        #If just nice <perfect situation>
        if ( $srcHead[$i] eq $tgtHead[$i] ) {
            print "L180 $srcHead[$i]: found srcHead i = tgtHead i\n";
            $mapping .= $srcHead[$i] . ':' . $tgtHead[$i] . ';'; #Append these stuff to string in the format "srcarr:tgtarr;"
            undef $srcHeadFinal[$i];
            undef $tgtHeadFinal[$i];
        }
        #But unfortunately <less than ideal but doable situation>
        elsif ( grep( /^$srcHead[$i]/, @tgtHead ) ) {
            print "L187 $srcHead[$i]: grep for srchead i in tgthead\n";
            my ($idx) = grep { $tgtHead[$_] eq $srcHead[$i] } 0..$#tgtHead; #Search in @tgthead for $srcHead[$i], if found get index
            $mapping .= $srcHead[$i] . ':' . $tgtHead[$idx] . ';';
            undef $srcHeadFinal[$i];
            undef $tgtHeadFinal[$idx];
        }
        
        #Lastly: For <bad situations>
        # Custom mapping file will contain src_col~tgt_col entries, working similarly to tid_lookup.csv
        # We search for src_col and get corresponding tgt_col values, using an array to manage duplicates
        # then search the tgt_col to see if exists in @tgt_head, if found then map it.
        
        elsif ( `grep "$srcHead[$i]" <Dir>/lookup/col_ref.csv` ) { #If mapref has a custom mapping available
            print "L200 $srcHead[$i]: refering to external file\n";
            my @srcMap = split(/^/m,`grep "$srcHead[$i]" <Dir>/lookup/col_ref.csv | cut -d '~' -f 2`); #Bad to repeat myself but bleh
            chomp @srcMap;
            print "$srcMap[0]\n";
            print "$srcMap[1]\n";
            for my $j (0 .. $#srcMap) {
                if ( grep( /^$srcMap[$j]/, @tgtHead ) ) {
                    my ($jdx) = grep { $tgtHead[$_] eq $srcMap[$j] } 0..$#tgtHead;
                    $mapping .= $srcHead[$i] . ':' . $tgtHead[$jdx] . ';';
                    undef $srcHeadFinal[$i];
                    undef $tgtHeadFinal[$jdx];
                    last; #Break out of for loop
                }
            } #End sub for loop
        }
        else {
            print "Unable to find matching tgt col for $srcHead[$i]\n";
        }
    } #End for loop srcHeaders
    
    
    @srcHeadFinal = grep defined, @srcHeadFinal;
    @tgtHeadFinal = grep defined, @tgtHeadFinal;
    if (@srcHeadFinal && @tgtHeadFinal) { #if array still contain stuff/ not all is mapped
        print "nokori array da na\n";
        $mapping="error";
    }
    
    print "$mapping\n"; #Return this string, unix will deal with the rest
    return;

} #End sub

unless (caller) {
    print shift->(@ARGV);
}
1;