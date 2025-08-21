# Simple DNS logger

At one point I needed to track DNS record change propagation, and got tired of point dig and friends directly. Dig is fine, but to get results over time you need to run it repeatedly. 

This script can be run via cron, will write a log file and preserve the results from queries with a timestamp. 

Say, you have this workflow:

* start the script, point it at your domain (and optionally nameserver) of choice
* track various common entries A, AAAA, NS, SOA, TXT into a file
* trigger a DNS record change
* check when the change shows up in different places by different --nameserver values
* have logs that show where you asked, when that was, and which domain you queried

This is meant to be scriptable and may improve in the future. 

Have fun.

