#!/usr/bin/python

# Contains various python functions, each used to support various different scripts in eCompare

# Used in reconcile.sh: handle headers sub, from a provided range from mapping lines to end of file, select 1 at random
def randmap_row(maprows):
    import random
    
    count = int(maprows)
    end = count + 23
    print random.randint(24,end)

# Used in reconcile.sh: handle headers sub, input 5 values into an array and determine the most element
def list_gmf(index0,index1,index2,index3,index4):    
    lst = [index0,index1,index2,index3,index4]

    print max(set(lst), key=lst.count)

# Used in config_tool: update sub, this python function will parse the file and try to guess the delimiter
def guess_delimiter(file):
    import csv

    with open(file, 'rb') as csvfile:
        dialect = csv.Sniffer().sniff(csvfile.read(), delimiters='|;~,')        
        print dialect.delimiter