#!/usr/bin/perl
package ConfigPrep;

# Latest CHange 9 Sep 2018: Introduced if conditions to handle situations where $idx and $jdx are not found.

#Legacy Code Reference
sub writeToConfig {

    my $refFile = $_[1] or die "Reference xlsx file not specified";
#    print "$refFile\n";

    use FindBin;
    use lib "$FindBin::/home/ownccr/rgClient/pl5lib"; #That directory contains various custom installed perl libraries

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
        open($fh, '>', "/home/ownccr/rgClient/ConfigTool/$cfgname.cfg"); #Open file, writing (">" form) to it

        
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
    use lib "$FindBin::/home/ownccr/rgClient/pl5lib";

    use strict;
    use warnings;

    use Excel::Writer::XLSX;
    
    my $workbook = Excel::Writer::XLSX->new("/home/ownccr/rgClient/ConfigTool/configr.xlsx");
    
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
        my @list = split (/\`/, $_);
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
            # Check if Src Keys Lookup exists in Source Key
            elsif ( $x > 0 && $y ==12 && $list[16] ne "" && $c !~ $list[16] ) {
                $worksheet->write($x, $y++, $c, $textFormat1);
            }            
            # Check if Src Keys Lookup should exist but isn't (Certain columns present in Src key)
            elsif ( $x > 0 && $y ==16 && $c eq "" && $list[12] =~ /trade[ _]n|trade[ _]i|component[ _]i|deal[ _]n/i ) {
                $worksheet->write($x, $y++, $c, $bgFormat);
            }
            # Check if Lookup file is missing/wrong when Src Keys Lookup is available (wrong: != /home/ownccr/rgClient/lookup/*id_lookup.csv regex)
#            elsif ( $x > 0 && $y ==20 && $list[16] ne "" && $c !~ /\/home\/ownccr\/rgClient\/lookup\/[ct]id_lookup.csv/ ) {
            elsif ( $x > 0 && $y ==20 ) {
                # we consider 2 scenarios: src key lookup is defined but keylookup file is wrong:
                if ( $list[16] ne "" && $c !~ /\/home\/ownccr\/rgClient\/lookup\/[ct]id_lookup.csv/ ) {
                    $worksheet->write($x, $y++, $c, $bgFormat1);
                }
                # and src key lookup is empty and key lookup file line is wrongly formatted
                elsif ( $list[16] eq "" && ( $c !~ /\/home\/ownccr\/rgClient\/lookup\/[ct]id_lookup.csv/ && $c ne "" ) ) {
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
    use lib "$FindBin::/home/ownccr/rgClient/pl5lib";

    use strict;
    use warnings;
    use Data::Dumper;
    use utf8;
    
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
    @srcHead = grep(!/[ _]TIME/i, @srcHead );
    @tgtHead = grep(!/[ _]TIME/i, @tgtHead );
    print "srcHead_1 is $srcHead[0]\n";
    print "srcHead_1 is $srcHead[1]\n";
    print "srcHead_1 is $srcHead[2]\n";
    print "tgtHead_1 is $tgtHead[1]\n";
    
    my @srcHeadFinal = @srcHead;
    my @tgtHeadFinal = @tgtHead;
    my $mapping;
    `dos2unix -k -q col_ref.csv`;
    for my $i (0 .. $#srcHead) {
        print "i is $i\n";
        print "srcHead is $srcHead[$i], tgtHead is $tgtHead[$i]\n";
        #If just nice headers from src,tgt aligned in same index, great!
        if ( $srcHead[$i] eq $tgtHead[$i] ) {
            print "L180 $srcHead[$i]: found srcHead i = tgtHead i\n";
            $mapping .= $srcHead[$i] . ':' . $tgtHead[$i] . ';'; #Append these stuff to string in the format "srcarr:tgtarr;"
            undef $srcHeadFinal[$i];
            undef $tgtHeadFinal[$i];
        }
        #But unfortunately maybe tgt has extra column misaligning everything, then we need this
        elsif ( grep( /^$srcHead[$i]/, @tgtHead ) ) {
            print "L187 $srcHead[$i]: grep for srchead i in tgthead\n";
            my ($idx) = grep { $tgtHead[$_] eq $srcHead[$i] } 0..$#tgtHead; #Search in @tgthead for $srcHead[$i], if found get index
            if ( (defined $idx) && ($idx ne '') ) {
                $mapping .= $srcHead[$i] . ':' . $tgtHead[$idx] . ';';
                undef $srcHeadFinal[$i];
                undef $tgtHeadFinal[$idx];
                undef $idx;
            }
            
        }
        
        #Lastly: For situations where src and tgt MAY BE different but supposed to map together
        # Custom mapping file will contain src_col~tgt_col entries, working similarly to tid_lookup.csv
        # We search for src_col and get corresponding tgt_col values, using an array to manage duplicates
        # then search the tgt_col to see if exists in @tgt_head, if found then map it.
        
        elsif ( `grep "$srcHead[$i]" /home/ownccr/rgClient/lookup/col_ref.csv` ) { #If mapref has a custom mapping available
            print "L200 $srcHead[$i]: refering to external file\n";
            my @srcMap = split(/^/m,`grep "$srcHead[$i]" /home/ownccr/rgClient/lookup/col_ref.csv | cut -d '~' -f 2`); #Bad to repeat myself but bleh
            chomp @srcMap;
            print "$srcMap[0]\n";
            print "$srcMap[1]\n";
            for my $j (0 .. $#srcMap) {
                if ( grep( /^$srcMap[$j]/, @tgtHead ) ) {
                    my ($jdx) = grep { $tgtHead[$_] eq $srcMap[$j] } 0..$#tgtHead;
                    if ( (defined $jdx) && ($jdx ne '') ) {
                        $mapping .= $srcHead[$i] . ':' . $tgtHead[$jdx] . ';';
                        undef $srcHeadFinal[$i];
                        undef $tgtHeadFinal[$jdx];
                        undef $jdx;
                    }
                    
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
        print "srcHead_1st is $srcHeadFinal[0]\n";
        print "srcHead_2 is $srcHeadFinal[1]\n";
        print "tgtHead_1st is $tgtHeadFinal[0]\n";
        print "tgtHead_2 is $tgtHeadFinal[1]\n";
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