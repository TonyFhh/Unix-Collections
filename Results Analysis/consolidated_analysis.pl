#!/usr/bin/perl

#Some sensitive information have been removed to protect confidentiality
use FindBin;
use lib "$FindBin::<Dir>/pl5lib";

use strict;
use warnings;
use Data::Dumper; #used for debugging


use Excel::Writer::XLSX;


my $workbook = Excel::Writer::XLSX->new('<Dir>/results_summary.xlsx');
my $worksheet = $workbook ->add_worksheet();

my $textFormat1 = $workbook->add_format(font => 'Calibri', color => 'red', size => 11); # Add a format
my $textFormat1B = $workbook->add_format(font => 'Calibri', color => 'blue', size => 11); # Add a format
my $borderFormat1 = $workbook->add_format(border => '2', border_color => 'red');

my $comparevar;

open(FH,"<Dir>/results_summary.csv")
    or die "File unavailable: $!\n";
my ($x,$y) = (0,0);
while (<FH>){
    chomp;
#    print "$_\n";
    my @list = split (/\|/, $_);
 #   print join(", ", @list);
 #   print "\nnext line\n";
    my $linecount = 1;
    foreach my $c (@list){
 #       chomp $c;
        $c =~ s/,[\r\n]+$//;
        
        #First <do #1>
        if ( $y == 13 ) {
            $worksheet->write($x, $y++, $c, $textFormat1B);
        }
    
        # Then Starting from the 2nd line, we start to do <#2>
        
        # This will test <condition1>
        elsif ( $x > 0 && $y == 4 && $list[6] != 0 && $c >= int($list[6]*0.5)) {
            $worksheet->write($x, $y++, $c, $textFormat1);
        }
        elsif ( $x > 0 && $y == 5 && $list[7] != 0 && $c >= int($list[7]*0.5) ) {
            $worksheet->write($x, $y++, $c, $textFormat1);
        }
        
        #This will test <condition2>
        elsif ( $x > 0 && $y == 11 && $list[9] - $c >= 3 ) {
            
            $worksheet->write($x, $y++, $c, $textFormat1);
        }
        
        # This will test <condition3>
        elsif ( $x > 0 && $y == 14 && $c =~ /<pattern>/i ) {
            $worksheet->write($x, $y++, $c, $textFormat1);
        }
        
        elsif ( $x > 0 && $y == 12 && $c eq "" && $list[13] =~ /<pattern>/i ) {
            $worksheet->write($x, $y++, $c, $borderFormat1);
        }
        
            
        else {
        $worksheet->write($x, $y++, $c);
        }
    }
#    $linecount++;
    $x++; $y=0;
}
close(FH);
$workbook->close(); 





