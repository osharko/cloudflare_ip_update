#!/bin/bash

# Set your Cloudflare credentials and zone name
CLOUDFLARE_BEARER="yN5wDakBzqvVnN3943HG6vsOrUHZt4p9d257p_SK"
ZONE_NAME="osharko.it"
X_AUTH_KEY="090dfdc0d81288e10d7b5a7ee48ca6f837c76"
X_AUTH_EMAIL="luigiminopoli3d@gmail.com"

# Function to get the public IP address
get_ip() {
    IP=$(curl -s https://ipinfo.io/ip)
    export IP
    ## echo "IP: $IP"
}

# Function to get the zone ID
get_zones() {
    ZONE_ID=$(curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CLOUDFLARE_BEARER" \
        "https://api.cloudflare.com/client/v4/zones" | \
        jq -r --arg ZONE_NAME "$ZONE_NAME" '.result[] | select(.name == $ZONE_NAME) | .id')
    
    export ZONE_ID
    # echo "zoneId: $ZONE_ID"
}

# Function to get DNS records and update them
get_dns_records() {
    curl -s -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CLOUDFLARE_BEARER" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" | \
        jq -c '.result[] | select(.type == "A")' | while read -r record; do
            ID=$(echo "$record" | jq -r '.id')
            NAME=$(echo "$record" | jq -r '.name')
            # ZONE_ID=$(echo "$record" | jq -r '.zone_id')

            # Prepare the request body
            BODY=$(jq -n \
                --arg type "$(echo "$record" | jq -r '.type')" \
                --arg name "$NAME" \
                --arg id "$ID" \
                --arg zone_id "$ZONE_ID" \
                --arg content "$IP" \
                --arg ttl "120" \
                --arg proxied "true" \
                '{type: $type, name: $name, id: $id, zone_id: $zone_id, content: $content, ttl: ($ttl | tonumber), proxied: ($proxied | test("true"))}')

            # Update the DNS record
            update_dns "$ZONE_ID" "$ID" "$BODY"
        done
}

# Function to update DNS records
update_dns() {
    local zone_id=$1
    local id=$2
    local body=$3

    RESPONSE=$(curl -s -X PUT -H "Content-Type: application/json" \
        -H "X-Auth-Key: $X_AUTH_KEY" \
        -H "X-Auth-Email: $X_AUTH_EMAIL" \
        -d "$body" \
        "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$id")

    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
    NAME=$(echo "$body" | jq -r '.name')
    echo "$(date +"%Y-%m-%d %H:%M:%S") → $NAME : $IP = $SUCCESS"
}

# Main function to execute the script
main() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") → Start"
    get_ip
    get_zones
    get_dns_records
    echo "$(date +"%Y-%m-%d %H:%M:%S") → DONE"
}

main
