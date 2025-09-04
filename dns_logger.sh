#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 --domain <domain> [--nameserver <nameserver>]"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$1" != "--domain" ]; then
    usage
fi

# Get the domain from the command line argument
DOMAIN="$2"

# Check for optional nameserver argument
if [ "$#" -eq 4 ] && [ "$3" == "--nameserver" ]; then
    NAMESERVER="$4"
else
    NAMESERVER=""
fi

# Create a log file named after the domain and nameserver (if provided)
if [ -n "$NAMESERVER" ]; then
    LOGFILE="dns_log_${DOMAIN//./_}_${NAMESERVER//./_}_$(date +%Y%m%d).log"
else
    LOGFILE="dns_log_${DOMAIN//./_}_system_$(date +%Y%m%d).log"
fi

# Define the record types you want to query
RECORD_TYPES=("A" "AAAA" "CNAME" "MX" "NS" "TXT" "SOA" "SPF")

# Function to log DNS records
log_dns_records() {
    if [ -n "$NAMESERVER" ]; then
        echo "Logging DNS records for $DOMAIN using nameserver $NAMESERVER" | tee -a "$LOGFILE"
    else
        echo "Logging DNS records for $DOMAIN using system DNS" | tee -a "$LOGFILE"
    fi
    echo "Timestamp: $(date)" | tee -a "$LOGFILE"
    echo "----------------------------------------" | tee -a "$LOGFILE"

    for RECORD_TYPE in "${RECORD_TYPES[@]}"; do
        CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
        
        if [ -n "$NAMESERVER" ]; then
            DNS_OUTPUT=$(dig +multiline "$RECORD_TYPE" "$DOMAIN" @"$NAMESERVER")
        else
            DNS_OUTPUT=$(dig +multiline "$RECORD_TYPE" "$DOMAIN")
        fi
        
        # Extract the ANSWER SECTION
        ANSWER_SECTION=$(echo "$DNS_OUTPUT" | awk '/ANSWER SECTION:/,/;; Query time:/ {if (!/ANSWER SECTION:/ && !/;; Query time:/) print}')
        
        # Process each line in the ANSWER SECTION
        while IFS= read -r line; do
            TTL=$(echo "$line" | awk '{print $2}')
            RECORD_DATA=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | xargs)  # Remove the first three fields and trim whitespace
            
            echo "$CURRENT_TIME - $RECORD_TYPE: $RECORD_DATA (TTL: $TTL)" | tee -a "$LOGFILE"
        done <<< "$ANSWER_SECTION"
	
	# Special handling for SOA record to extract the serial number
	if [ "$RECORD_TYPE" == "SOA" ]; then
	    # Extract the complete multiline SOA record from DNS output
	    SOA_MULTILINE=$(echo "$DNS_OUTPUT" | awk '
	        BEGIN { in_soa = 0; soa_record = "" }
	        /IN SOA/ { 
	            in_soa = 1
	            soa_record = $0
	            if (index($0, ")") > 0) {
	                print soa_record
	                exit
	            }
	            next
	        }
	        in_soa == 1 {
	            soa_record = soa_record " " $0
	            if (index($0, ")") > 0) {
	                print soa_record
	                exit
	            }
	        }
	    ')
    
	    if [ -n "$SOA_MULTILINE" ]; then
	        # Clean the multiline SOA: remove parentheses, newlines, and extra spaces
	        SOA_CLEAN=$(echo "$SOA_MULTILINE" | tr -d '\n()' | sed 's/  */ /g' | xargs)
	        
	        # Parse the cleaned SOA record: DOMAIN TTL IN SOA MNAME RNAME SERIAL REFRESH RETRY EXPIRE MINIMUM
	        read -r DOMAIN_NAME TTL_VAL IN_CLASS SOA_TYPE MNAME RNAME SERIAL REFRESH RETRY EXPIRE MINIMUM <<< "$SOA_CLEAN"
	        
	        # Validate that SERIAL is numeric
	        if [[ "$SERIAL" =~ ^[0-9]+$ ]]; then
	            echo "$CURRENT_TIME - SOA: $MNAME $RNAME $SERIAL $REFRESH $RETRY $EXPIRE $MINIMUM (TTL: $TTL_VAL)" | tee -a "$LOGFILE"
	            echo "$CURRENT_TIME - SOA Serial Number: $SERIAL" | tee -a "$LOGFILE"
	        else
	            echo "$CURRENT_TIME - SOA: Parse error - serial number not found: '$SERIAL'" | tee -a "$LOGFILE"
	        fi
	    else
	        echo "$CURRENT_TIME - SOA: No SOA record found" | tee -a "$LOGFILE"
	    fi
	fi
	
        echo "----------------------------------------" | tee -a "$LOGFILE"
    done

    echo "DNS records logged successfully." | tee -a "$LOGFILE"
}

# Run the logging function
log_dns_records

# Querying the log file post-creation
# 
# To analyze the log file for changes in IP addresses, you can use the following command-line tools and techniques:
# 
#    View the Log File:
#  To view the log file, you can use:
#
#bash
#
#cat dns_log_YYYYMMDD.log
#
#Replace YYYYMMDD with the actual date of the log file.
#
#Extract Unique IP Addresses:
#To extract unique IP addresses from the log file, you can use:
#
#bash
#
#grep "A:" dns_log_YYYYMMDD.log | awk '{print $NF}' | sort -u
#
#This command will:
#
#    Search for lines containing "A:".
#    Use awk to print the last field (the IP address).
#    Sort the results and show unique entries.
#
#Compare Old and New IP Addresses:
#If you have a previous log file (e.g., dns_log_old.log), you can compare it with the current log file:
#
#bash
#
#echo "Old IPs:"
#grep "A:" dns_log_old.log | awk '{print $NF}' | sort -u
#
#echo "New IPs:"
#grep "A:" dns_log_YYYYMMDD.log | awk '{print $NF}' | sort -u
#
#Output Time of Day for Changes:
#To find out when the IP addresses changed, you can use:
#
#bash
#
#awk '/A:/ {print $1, $2, $3}' dns_log_YYYYMMDD.log | sort
#
#This will print the timestamp along with the record type, allowing you to see when each IP address was logged.
#
