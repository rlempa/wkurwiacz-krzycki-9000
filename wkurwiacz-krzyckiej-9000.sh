#!/bin/bash

# Parse command-line arguments
declare -A PARAMS=([poll]=1898 [option]=6830 [sleep-running]=0.5 [sleep-waiting]=2 [graph-height]=15 [graph-width]=60 [history-size]=120 [graph-interval]=10 [sleep-randomness]=0)

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --poll=*) POLL_ID="${1#*=}" ;;
        --option=*) OPTION_ID="${1#*=}" ;;
        --sleep-running=*) SLEEP_RUNNING="${1#*=}" ;;
        --sleep-waiting=*) SLEEP_WAITING="${1#*=}" ;;
        --sleep-randomness=*) SLEEP_RANDOMNESS="${1#*=}" ;;
        --graph-height=*) GRAPH_HEIGHT="${1#*=}" ;;
        --graph-width=*) GRAPH_WIDTH="${1#*=}" ;;
        --history-size=*) HISTORY_SIZE="${1#*=}" ;;
        --graph-interval=*) GRAPH_INTERVAL="${1#*=}" ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --poll=ID              Poll ID (default: 1898)"
            echo "  --option=ID            Option ID to vote for (default: 6830)"
            echo "  --sleep-running=N      Sleep duration in seconds when running (default: 0.5)"
            echo "  --sleep-waiting=N      Sleep duration in seconds when waiting (default: 2)"
            echo "  --sleep-randomness=P   Random variation percentage for sleep (0-100, default: 0)"
            echo "  --graph-height=N       Height of the ASCII graph (default: 15)"
            echo "  --graph-width=N        Width of the ASCII graph (default: 60)"
            echo "  --history-size=N       Number of data points to keep (default: 120)"
            echo "  --graph-interval=N     Show graph every N iterations (default: 10)"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Set parameters with defaults if not specified through command line
POLL_ID=${POLL_ID:-${PARAMS[poll]}}
OPTION_ID=${OPTION_ID:-${PARAMS[option]}}
SLEEP_RUNNING=${SLEEP_RUNNING:-${PARAMS[sleep-running]}}
SLEEP_WAITING=${SLEEP_WAITING:-${PARAMS[sleep-waiting]}}
SLEEP_RANDOMNESS=${SLEEP_RANDOMNESS:-${PARAMS[sleep-randomness]}}
GRAPH_HEIGHT=${GRAPH_HEIGHT:-${PARAMS[graph-height]}}
GRAPH_WIDTH=${GRAPH_WIDTH:-${PARAMS[graph-width]}}
HISTORY_SIZE=${HISTORY_SIZE:-${PARAMS[history-size]}}
GRAPH_INTERVAL=${GRAPH_INTERVAL:-${PARAMS[graph-interval]}}

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
echo "Using: Poll ID=$POLL_ID, Option ID=$OPTION_ID, Sleep Running=$SLEEP_RUNNING, Sleep Waiting=$SLEEP_WAITING, Randomness=$SLEEP_RANDOMNESS%"
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
iteration_count=0

# Initialize arrays for historical data
declare -a option1_history
declare -a option2_history
declare -a timestamps

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

# Function to add randomness to sleep duration
apply_sleep_randomness() {
    local base_duration=$1

    if [ "$SLEEP_RANDOMNESS" -eq 0 ]; then
        echo "$base_duration"
        return
    fi

    # Generate random value between -SLEEP_RANDOMNESS and +SLEEP_RANDOMNESS percent
    local rand_percent=$(( (RANDOM % (2 * SLEEP_RANDOMNESS + 1)) - SLEEP_RANDOMNESS ))

    # Apply the percentage to the base duration
    echo "scale=3; $base_duration * (1 + $rand_percent / 100.0)" | bc
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

# Function to draw an ASCII graph
draw_graph() {
    local width=$GRAPH_WIDTH
    local height=$GRAPH_HEIGHT
    local count=${#option1_history[@]}

    # Print current stats
    echo ""
    echo "===== Vote History Graph ====="
    echo "Time span: $(format_duration $(($(date +%s) - script_start_time)))"

    if [ $count -eq 0 ]; then
        echo "No data collected yet. Starting to collect data..."
        echo "Current diff: Not available yet"
        echo ""

        # Create an empty graph framework
        for y in $(seq 0 $((height-1))); do
            printf "%8s |" ""
            for x in $(seq 1 $width); do
                printf " "
            done
            echo ""
        done

        # Print x-axis
        printf "         +"
        for x in $(seq 1 $width); do
            printf "-"
        done
        printf "\n"

        # Print legend
        echo -e "         Legend: \033[1;32m+\033[0m Option 1, \033[1;31mo\033[0m Option 2"
        echo ""
        return
    fi

    # Find min and max values for scaling
    local min_value=999999999
    local max_value=0

    # Get min/max values for scaling
    for i in $(seq 0 $((count-1))); do
        if [ ${option1_history[$i]} -lt $min_value ]; then min_value=${option1_history[$i]}; fi
        if [ ${option2_history[$i]} -lt $min_value ]; then min_value=${option2_history[$i]}; fi
        if [ ${option1_history[$i]} -gt $max_value ]; then max_value=${option1_history[$i]}; fi
        if [ ${option2_history[$i]} -gt $max_value ]; then max_value=${option2_history[$i]}; fi
    done

    # Add some padding
    local range=$((max_value - min_value))
    if [ $range -eq 0 ]; then range=1; fi
    min_value=$((min_value - range / 10))
    max_value=$((max_value + range / 10))
    range=$((max_value - min_value))

    echo "Min votes: $min_value, Max votes: $max_value"
    echo "Current diff: Option 1 - Option 2 = $((last_option1 - last_option2)) votes"
    echo ""

    # Create an empty graph canvas
    local graph=()
    for y in $(seq 0 $((height-1))); do
        graph[$y]=""
        for x in $(seq 1 $width); do
            graph[$y]="${graph[$y]} "
        done
    done

    # Calculate effective width based on data points
    local effective_width=0
    if [ $count -gt 1 ]; then
        # Use at most width, but for small counts, use just enough space
        effective_width=$(( count < width ? count : width ))
    else
        effective_width=1  # For single point, use minimal width
    fi

    # Plot points across the used width
    for i in $(seq 0 $((count-1))); do
        # Calculate exact position based on the effective width
        local x=0
        if [ $count -gt 1 ]; then
            x=$(( i * (effective_width-1) / (count-1) ))
            if [ $x -ge $effective_width ]; then x=$((effective_width-1)); fi
        fi

        # Calculate y position for option1
        local option1_val=${option1_history[$i]}
        local y1=$(( height - 1 - (option1_val - min_value) * (height-1) / range ))
        if [ $y1 -lt 0 ]; then y1=0; fi
        if [ $y1 -ge $height ]; then y1=$((height-1)); fi

        # Place green symbol for option1 (fixed)
        local line=${graph[$y1]}
        graph[$y1]="${line:0:$x}+${line:$((x+1))}"

        # Calculate y position for option2
        local option2_val=${option2_history[$i]}
        local y2=$(( height - 1 - (option2_val - min_value) * (height-1) / range ))
        if [ $y2 -lt 0 ]; then y2=0; fi
        if [ $y2 -ge $height ]; then y2=$((height-1)); fi

        # Place red symbol for option2 (fixed)
        local line=${graph[$y2]}
        graph[$y2]="${line:0:$x}o${line:$((x+1))}"
    done

    # Add y-axis labels and draw graph with colored symbols
    for y in $(seq 0 $((height-1))); do
        local value=$((min_value + (height - 1 - y) * range / (height-1)))
        local line=${graph[$y]}

        # Create a temporary file to process line with proper colors
        temp_file=$(mktemp)
        echo "$line" > "$temp_file"

        # Process the line with sed to add colors
        processed_line=$(sed 's/+/\\033[1;32m+\\033[0m/g' "$temp_file" | sed 's/o/\\033[1;31mo\\033[0m/g')
        rm "$temp_file"

        # Print the line with proper coloring
        printf "%8d |%s\n" $value "$(echo -e "$processed_line")"
    done

    # Print x-axis
    printf "         +"
    for x in $(seq 1 $width); do
        printf "-"
    done
    printf "\n"

    # Print legend with properly displayed colors
    echo -e "         Legend: \033[1;32m+\033[0m Option 1, \033[1;31mo\033[0m Option 2"
    echo ""
}

# Function to send POST request and get response
send_request() {
    # Create a temporary file to store the response
    temp_file=$(mktemp)

    # Send request and capture both status code and response
    status_code=$(curl -X POST "https://www.wroclaw.pl/api/quiz/api/polls/$POLL_ID/option/$OPTION_ID" \
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

    # Add data to history arrays
    option1_history+=($last_option1)
    option2_history+=($last_option2)
    timestamps+=($(date +%s))

    # Keep arrays at specified size
    if [ ${#option1_history[@]} -gt $HISTORY_SIZE ]; then
        option1_history=("${option1_history[@]:1}")
        option2_history=("${option2_history[@]:1}")
        timestamps=("${timestamps[@]:1}")
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

    # Increment iteration count
    iteration_count=$((iteration_count + 1))

    # Check if we need to redraw the graph (first run or interval reached)
    if [ $iteration_count -eq 1 ] || [ $((iteration_count % GRAPH_INTERVAL)) -eq 0 ]; then
        # Clear screen for graph display
        clear
        draw_graph
    else
        # Clear current line and display updated statistics
        printf "\r\033[K"  # Clear current line
    fi

    # Display all statistics in a single line using last known values, with status first
    if [ "$last_status" = "RUNNING" ]; then
        echo -en "Status: \033[1;32m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [${gain_color1}+$gain1\033[0m] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [${gain_color2}+$gain2\033[0m] | Total: $last_total | Last Wait: $formatted_waiting_duration | Last Run: $formatted_last_running_duration | RPS: $requests_per_second"
    else
        echo -en "Status: \033[1;31m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [${gain_color1}+$gain1\033[0m] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [${gain_color2}+$gain2\033[0m] | Total: $last_total | Last Wait: $formatted_waiting_duration | Last Run: $formatted_last_running_duration | RPS: $requests_per_second"
    fi
}

# Display the empty graph at startup
clear
draw_graph

# Main loop
while true; do
    send_request

    if [ "$last_status" = "RUNNING" ]; then
        sleep $(apply_sleep_randomness $SLEEP_RUNNING)
    else
        sleep $(apply_sleep_randomness $SLEEP_WAITING)
    fi
done
