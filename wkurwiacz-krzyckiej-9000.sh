#!/bin/bash

# Display beautiful ASCII art logo
echo -e "\033[1;31m"
echo "██╗    ██╗██╗  ██╗    ██████╗  ██████╗  ██████╗  ██████╗ "
echo "██║    ██║██║ ██╔╝    ██╔═══██╗██╔═══██╗██╔═══██╗██╔═══██╗"
echo "██║ █╗ ██║█████╔╝     ╚█████╔╝██║   ██║██║   ██║██║   ██║"
echo "██║███╗██║██╔═██╗      ╚═══██╗██║   ██║██║   ██║██║   ██║"
echo "╚███╔███╔╝██║  ██╗    ██████╔╝╚██████╔╝╚██████╔╝╚██████╔╝"
echo " ╚══╝╚══╝ ╚═╝  ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝  ╚═════╝ "
echo -e "\033[0m"
echo "Press ESC to exit."
echo "" # Empty line for spacing

# Initialize variables to store last known values
last_option1=0
last_option2=0
last_total=0
last_status="WAITING"

# Function to send POST request and get response
send_request() {
    # Create a temporary file to store the response
    temp_file=$(mktemp)
    
    # Send request and capture both status code and response
    status_code=$(curl -X POST "https://www.wroclaw.pl/api/quiz/api/polls/1898/option/6830" \
    -H "Content-Type: application/json" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
    -H "Accept: application/json" \
    -H "Origin: https://www.wroclaw.pl" \
    -H "Referer: https://www.wroclaw.pl/" \
    -d '{}' \
    -s -w "%{http_code}" \
    -o "$temp_file")
    
    response=$(cat "$temp_file")
    rm "$temp_file"
    
    # Parse statistics, using last known values if parsing fails
    new_option1=$(echo $response | grep -o '"count":[0-9]*' | head -1 | cut -d':' -f2)
    new_option2=$(echo $response | grep -o '"count":[0-9]*' | tail -1 | cut -d':' -f2)
    new_total=$(echo $response | grep -o '"statistics":[0-9]*' | cut -d':' -f2)
    
    # Update values only if we got valid numbers
    if [[ "$new_option1" =~ ^[0-9]+$ ]] && [[ "$new_option2" =~ ^[0-9]+$ ]] && [[ "$new_total" =~ ^[0-9]+$ ]]; then
        last_option1=$new_option1
        last_option2=$new_option2
        last_total=$new_total
    fi
    
    # Set status based on HTTP response code
    if [ "$status_code" -eq 200 ]; then
        last_status="RUNNING"`
    else
        last_status="WAITING"
        # Sleep for 5 seconds on any non-200 response
        sleep 5
    fi
    
    # Clear current line and display updated statistics
    printf "\r\033[K"  # Clear current line
    
    # Display all statistics in a single line using last known values, with status first
    if [ "$last_status" = "RUNNING" ]; then
        echo -en "Status: \033[1;32m$last_status\033[0m | Option 1: $last_option1 | Option 2: $last_option2 | Total: $last_total"
    else
        echo -en "Status: \033[1;31m$last_status\033[0m | Option 1: $last_option1 | Option 2: $last_option2 | Total: $last_total"
    fi
}

# Main loop
while true; do
    send_request
    sleep 0.2
    
    # Check for ESC key press without blocking
    if read -t 1 -n 1 key; then
        if [[ "$key" == $'\e' ]]; then
            echo -e "\nExiting script..."
            exit 0
        fi
    fi
done 