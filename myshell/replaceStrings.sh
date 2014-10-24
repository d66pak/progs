#!/bin/awk -f

 awk 'FILENAME == ARGV[1] { listA[$1] = FNR; next } FILENAME == ARGV[2] { listB[FNR] = $1; next } { for (i = 1; i <= NF; i++) { if ($i in listA) { $i = listB[listA[$i]] } } print }'
