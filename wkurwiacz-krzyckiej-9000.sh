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
echo "Press Ctrl+C (Windows/Linux) or Command+C (Mac) to exit."
echo "" # Empty line for spacing

# Initialize variables to store last known values
last_option1=0
last_option2=0
last_total=0
last_status="WAITING"
waiting_start_time=$(date +%s)  # Initialize with current time
last_waiting_duration=0
running_start_time=0
last_running_duration=0
script_start_time=$(date +%s)
start_option1=0
start_option2=0
start_total=0
last_completed_gain1=0
last_completed_gain2=0
request_count=0
last_request_time=$(date +%s)
requests_per_second=0

# Function to calculate percentage
calculate_percentage() {
    local value=$1
    local total=$2
    if [ "$total" -eq 0 ]; then
        echo "0.00"
    else
        echo "scale=2; ($value * 100) / $total" | bc
    fi
}

# Function to format duration in seconds to human readable format
format_duration() {
    local seconds=$1
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    else
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        if [ "$minutes" -lt 60 ]; then
            echo "${minutes}m ${remaining_seconds}s"
        else
            local hours=$((minutes / 60))
            local remaining_minutes=$((minutes % 60))
            echo "${hours}h ${remaining_minutes}m ${remaining_seconds}s"
        fi
    fi
}

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
    
    # Update request count and calculate requests per second
    request_count=$((request_count + 1))
    current_time=$(date +%s)
    if [ "$current_time" -gt "$last_request_time" ]; then
        requests_per_second=$((request_count / (current_time - last_request_time)))
    fi
    
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
        if [ "$last_status" = "WAITING" ]; then
            # Calculate waiting duration when transitioning from WAITING to RUNNING
            last_waiting_duration=$((current_time - waiting_start_time))
            running_start_time=$current_time  # Start new running period
            # Store the starting values for this running period
            start_option1=$last_option1
            start_option2=$last_option2
            start_total=$last_total
        fi
        last_status="RUNNING"
    else
        if [ "$last_status" = "RUNNING" ]; then
            # Calculate and store the last running duration when transitioning from RUNNING to WAITING
            last_running_duration=$((current_time - running_start_time))
            # Store the gains from the completed run
            last_completed_gain1=$((last_option1 - start_option1))
            last_completed_gain2=$((last_option2 - start_option2))
            # Start tracking waiting time
            waiting_start_time=$current_time
        fi
        last_status="WAITING"
    fi
    
    # Calculate percentages
    percent1=$(calculate_percentage $last_option1 $last_total)
    percent2=$(calculate_percentage $last_option2 $last_total)
    
    # Calculate vote gains from the start of the running period
    if [ "$last_status" = "RUNNING" ]; then
        gain1=$((last_option1 - start_option1))
        gain2=$((last_option2 - start_option2))
    else
        # Use the gains from the last completed run
        gain1=$last_completed_gain1
        gain2=$last_completed_gain2
    fi
    
    # Clear current line and display updated statistics
    printf "\r\033[K"  # Clear current line
    
    # Determine colors based on which option is leading in total votes
    if [ "$last_option1" -gt "$last_option2" ]; then
        color1="\033[1;32m"  # Green for option 1
        color2="\033[0m"     # Default for option 2
    elif [ "$last_option2" -gt "$last_option1" ]; then
        color1="\033[0m"     # Default for option 1
        color2="\033[1;31m"  # Red for option 2
    else
        color1="\033[0m"     # Default color for option 1
        color2="\033[0m"     # Default color for option 2
    fi
    
    # Determine colors for gains
    if [ "$gain1" -gt "$gain2" ]; then
        gain_color1="\033[1;32m"  # Green for gain 1
        gain_color2="\033[0m"     # Default for gain 2
    elif [ "$gain2" -gt "$gain1" ]; then
        gain_color1="\033[0m"     # Default for gain 1
        gain_color2="\033[1;31m"  # Red for gain 2
    else
        gain_color1="\033[0m"     # Default color for gain 1
        gain_color2="\033[0m"     # Default color for gain 2
    fi
    
    # Format durations
    formatted_waiting_duration=$(format_duration $last_waiting_duration)
    formatted_last_running_duration=$(format_duration $last_running_duration)
    
    # Display all statistics in a single line using last known values, with status first
    if [ "$last_status" = "RUNNING" ]; then
        echo -en "Status: \033[1;32m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [${gain_color1}+$gain1\033[0m] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [${gain_color2}+$gain2\033[0m] | Total: $last_total | Last Wait: $formatted_waiting_duration | Last Run: $formatted_last_running_duration | RPS: $requests_per_second"
    else
        echo -en "Status: \033[1;31m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [${gain_color1}+$gain1\033[0m] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [${gain_color2}+$gain2\033[0m] | Total: $last_total | Last Wait: $formatted_waiting_duration | Last Run: $formatted_last_running_duration | RPS: $requests_per_second"
    fi
}

# Main loop
while true; do
    send_request
done 