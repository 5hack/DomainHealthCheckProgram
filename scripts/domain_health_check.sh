#!/bin/bash

# MongoDB connection details
MONGO_URL="mongodb://admin:password@mongodb:27017"
DATABASE="domain_monitor"
COLLECTION="domains"

# Get the current calendar month and date
current_month=$(date -u "+%Y-%m")
current_date=$(date -u "+%Y-%m-%d")

# Function to retrieve domains from MongoDB
get_domains_from_mongo() {
    mongo --quiet --eval "
        db = db.getSiblingDB('$DATABASE');
        db.$COLLECTION.find({}, { domain: 1, _id: 0 }).toArray().map(function(doc) { return doc.domain; });
    " $MONGO_URL
}

# Function to get the expiry date from whois output
get_expiry_date() {
    local domain=$1
    local domain_info
    domain_info=$(whois "$domain")
    echo "$domain_info" | grep -i "Registry Expiry Date" | awk -F ':' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -dT -f1
}

# Function to insert or update domain in MongoDB
insert_or_update_domain() {
    local domain=$1
    local expiry_date=$2
    local days_to_expiry
    days_to_expiry=$((($(date -d "$expiry_date" +%s) - $(date -u +%s)) / 86400))

    local domain_record="{\"domain\": \"$domain\", \"expiry_date\": \"$expiry_date\", \"days_to_expiry\": $days_to_expiry}"

    mongo --eval "
        db = db.getSiblingDB('$DATABASE');
        db.$COLLECTION.updateOne({ domain: \"$domain\" }, { \$set: $domain_record }, { upsert: true });
    " $MONGO_URL
}

# Function to handle expired and soon-to-expire domains
handle_expiry() {
    local domain=$1
    local expiry_date=$2
    local domain_status_file=$3

    if [[ "$expiry_date" < "$current_date" ]]; then
        echo "Domain: $domain\nDate: $expiry_date\n----" >> "$domain_status_file"
    elif [[ "$expiry_date" == *"$current_month"* ]]; then
        echo "Domain: $domain\nDate: $expiry_date\n----" >> "$domain_status_file"
    fi
}

# Main script
domains=$(get_domains_from_mongo)

# Process each domain
for domain in $domains; do
    echo "Checking domain: $domain"

    expiry_date=$(get_expiry_date "$domain")

    if [ -z "$expiry_date" ]; then
        echo "Error: Unable to retrieve expiry date for domain: $domain"
        continue
    fi

    # Insert or update domain in MongoDB
    insert_or_update_domain "$domain" "$expiry_date"

    # Handle expired and soon-to-expire domains
    handle_expiry "$domain" "$expiry_date" "expired.domains.txt"
    handle_expiry "$domain" "$expiry_date" "expires.soon.txt"
done

# Insert expired domains into MongoDB
if [ -s "expired.domains.txt" ]; then
    echo "Inserting expired domains into MongoDB..."
    mongo --eval "
        db = db.getSiblingDB('$DATABASE');
        db.$COLLECTION.insertMany([$(cat expired.domains.txt)]);
    " $MONGO_URL
fi

# Insert soon-to-expire domains into MongoDB
if [ -s "expires.soon.txt" ]; then
    echo "Inserting soon-to-expire domains into MongoDB..."
    mongo --eval "
        db = db.getSiblingDB('$DATABASE');
        db.$COLLECTION.insertMany([$(cat expires.soon.txt)]);
    " $MONGO_URL
fi

exit
