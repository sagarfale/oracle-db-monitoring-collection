awk 'BEGIN {
    split("80,80,150,150,", widths, ",")
    print "<style>\
        .my_table {font-size:8.0pt; font-family:\"Verdana\",\"sans-serif\"; border-bottom:3px double black; border-collapse: collapse; }\n\
        .my_table tr.header{border-bottom:3px double black;}\n\
        .my_table th {text-align: left;}\
    </style>"
    print "<table class=\"my_table\">"
}
NR == 1{
    print "<tr class=\"header\">"
    tag = "th"
}
NR != 1{
    print "<tr>"
    tag = "td"
}
{
    for(i=1; i<=NF; ++i) print "<" tag " width=\"" widths[i] "\">" $i "</" tag ">"
    print "</tr>"
}
END { print "</table>"}'  file-system-usage.temp  > file-system-usage.html
