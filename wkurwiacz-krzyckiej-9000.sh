#!/bin/bash

# Get terminal width with adjustment for left margin (8 spaces + "|" + space = 10 chars) plus 1 extra char
TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)
GRAPH_HEIGHT_SET=0
GRAPH_WIDTH_SET=0

# Parse command-line arguments
declare -A PARAMS=([poll]=1898 [option]=6830 [sleep-running]=2 [sleep-waiting]=10 [graph-height]=30 [graph-width]=$(($TERM_WIDTH - 30)) [history-size]=120 [graph-interval]=1 [sleep-randomness]=50 [debug]=0 [auto-adjust]=0 [log-dir]="/var/log/wkurwiacz_logs")

# Process command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --poll=*) POLL_ID="${1#*=}" ;;
        --option=*) OPTION_ID="${1#*=}" ;;
        --sleep-running=*) SLEEP_RUNNING="${1#*=}" ;;
        --sleep-waiting=*) SLEEP_WAITING="${1#*=}" ;;
        --sleep-randomness=*) SLEEP_RANDOMNESS="${1#*=}" ;;
        --graph-height=*) GRAPH_HEIGHT="${1#*=}"; GRAPH_HEIGHT_SET=1 ;;
        --graph-width=*) GRAPH_WIDTH="${1#*=}"; GRAPH_WIDTH_SET=1 ;;
        --history-size=*) HISTORY_SIZE="${1#*=}" ;;
        --graph-interval=*) GRAPH_INTERVAL="${1#*=}" ;;
        --log-dir=*) LOG_DIR="${1#*=}" ;;
        --debug) DEBUG_MODE=1 ;;
        --auto-adjust) AUTO_ADJUST=1 ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --poll=ID              Poll ID (default: 1898)"
            echo "  --option=ID            Option ID to vote for (default: 6830)"
            echo "  --sleep-running=N      Sleep duration in seconds when running (default: 0.5)"
            echo "  --sleep-waiting=N      Sleep duration in seconds when waiting (default: 2)"
            echo "  --sleep-randomness=P   Random variation percentage for sleep (0-100, default: 0)"
            echo "  --graph-height=N       Height of the ASCII graph (default: 30)"
            echo "  --graph-width=N        Width of the ASCII graph (default: 240)"
            echo "  --history-size=N       Number of data points to keep (default: 120)"
            echo "  --graph-interval=N     Show graph every N iterations (default: 10)"
            echo "  --log-dir=PATH         Directory for log files (default: /var/log/wkurwiacz_logs)"
            echo "  --debug                Enable debug mode (more verbose output)"
            echo "  --auto-adjust          Automatically adjust sleep duration based on network latency"
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
DEBUG_MODE=${DEBUG_MODE:-${PARAMS[debug]}}
LOG_DIR=${LOG_DIR:-${PARAMS[log-dir]}}

# Set up logging
mkdir -p "$LOG_DIR"
MAIN_LOG="$LOG_DIR/main.log"
DEBUG_LOG="$LOG_DIR/debug.log"

# Initialize logs
echo "=== WKURWIACZ KRZYCKI 9000 LOG STARTED AT $(date +'%Y-%m-%d %H:%M:%S') ===" > "$MAIN_LOG"
echo "=== DEBUG LOG STARTED AT $(date +'%Y-%m-%d %H:%M:%S') ===" > "$DEBUG_LOG"
echo "Debug mode: $DEBUG_MODE" >> "$MAIN_LOG"
echo "Log directory: $LOG_DIR" >> "$MAIN_LOG"

# Function to format timestamp
format_timestamp() {
    local timestamp=$1
    date -d "@$timestamp" +'%H:%M:%S'
}

# Function to log messages
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$MAIN_LOG"
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo -e "[LOG] $1"
    fi
}

# Function to log debug info
log_debug() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$DEBUG_LOG"
        echo -e "[DEBUG] $1"
    fi
}

# Function to clean up on exit
cleanup() {
    log_message "Script terminated by user after running for $(format_duration $(($(date +%s) - script_start_time)))"
    log_message "Final stats - Option 1: $last_option1, Option 2: $last_option2, Total: $last_total"
    log_message "Total requests: $request_count"
    echo -e "\n\033[1;34mScript terminated. Logs saved to $LOG_DIR\033[0m"
    exit 0
}

# Set trap for clean exit
trap cleanup SIGINT SIGTERM

# Function to display the ASCII art logo with quick animations that cycle each time
display_logo() {
    # Get a cycling animation style based on iteration count
    local anim_style=$((iteration_count % 5))

    # Basic logo lines
    local logo=(
        "  ██╗    ██╗██╗  ██╗     █████╗  ██████╗  ██████╗  ██████╗   "
        "  ██║    ██║██║ ██╔╝    ██╔══██╗██╔═══██╗██╔═══██╗██╔═══██╗  "
        "  ██║ █╗ ██║█████╔╝     ╚█████╔╝██║   ██║██║   ██║██║   ██║  "
        "  ██║███╗██║██╔═██╗      ╚═══██╗██║   ██║██║   ██║██║   ██║  "
        "  ╚███╔███╔╝██║  ██╗    ██████╔╝╚██████╔╝╚██████╔╝╚██████╔╝  "
        "   ╚══╝╚══╝ ╚═╝  ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝  ╚═════╝   "
    )

    # Always start with a newline for consistent spacing
    echo ""

    # Quickly apply different visual styles based on the current iteration
    case $anim_style in
        0) # Standard red
            echo -e "\033[1;31m"
            for line in "${logo[@]}"; do
                echo "$line"
            done
            echo -e "\033[0m"
            ;;

        1) # Color pulse - gradient red to yellow
            echo -e "\033[1;31m"
            for i in {0..5}; do
                # Color gradient from red to yellow
                local color=$((31 + (i % 2)))
                echo -e "\033[1;${color}m${logo[$i]}\033[0m"
            done
            echo ""  # Add a newline after logo
            ;;

        2) # Inverted colors
            echo -e "\033[7;31m"  # Reverse video (inverted)
            for line in "${logo[@]}"; do
                echo "$line"
            done
            echo -e "\033[0m"
            ;;

        3) # Bold flashing effect
            echo -e "\033[1;31m"
            for i in {0..5}; do
                if [ $((i % 2)) -eq 0 ]; then
                    echo -e "\033[1;31m${logo[$i]}\033[0m"  # Bright red
                else
                    echo -e "\033[0;31m${logo[$i]}\033[0m"  # Normal red
                fi
            done
            echo ""  # Add a newline after logo
            ;;

        4) # Cool blue variation
            echo -e "\033[1;31m"
            for line in "${logo[@]}"; do
                echo "$line"
            done
            echo -e "\033[0m"
            ;;
    esac

    # Always add another newline after the logo
    echo ""

    # Print the standard info text without animation
    echo "Press Ctrl+C (Windows/Linux) or Command+C (Mac) to exit."
    echo "Using: Poll ID=$POLL_ID, Option ID=$OPTION_ID, Sleep Running=$SLEEP_RUNNING, Sleep Waiting=$SLEEP_WAITING, Randomness=$SLEEP_RANDOMNESS%"

    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo -e "\033[1;33mDEBUG MODE ENABLED\033[0m"
    fi

    echo -e "\033[1;34mLogging enabled. Check $LOG_DIR directory for logs.\033[0m"
    echo "" # Empty line for spacing
}

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
vote_start_time=$(date +%s)
vote_start_count=0
votes_contributed=0
request_errors=0
# Array of valid User-Agents
user_agents=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:90.0) Gecko/20100101 Firefox/90.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36 Edg/91.0.864.59"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 OPR/77.0.4054.254"
    "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
    "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:90.0) Gecko/20100101 Firefox/90.0"
    "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36 Edg/91.0.864.48"
    "Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
)

# Initialize arrays for historical data
declare -a option1_history=()
declare -a option2_history=()
declare -a timestamps=()

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

# Function to display simple data for debugging
draw_simple_graph() {
    if [ "$DEBUG_MODE" -eq 1 ] || [ "${1:-}" = "force" ]; then
        echo "===== Data Debug ====="
        echo "Total data points: ${#option1_history[@]}"

        if [ ${#option1_history[@]} -eq 0 ]; then
            echo "No data available yet."
            return
        fi

        echo "Latest 5 data points (Option1 / Option2) [Time]:"
        local start=$(( ${#option1_history[@]} > 5 ? ${#option1_history[@]} - 5 : 0 ))

        for ((i=start; i<${#option1_history[@]}; i++)); do
            local time_str=$(format_timestamp ${timestamps[$i]})
            echo "  [$i] ${option1_history[$i]} / ${option2_history[$i]} [$time_str]"
        done

        if [ ${#option1_history[@]} -gt 5 ]; then
            local first_time=$(format_timestamp ${timestamps[0]})
            echo "First data point: ${option1_history[0]} / ${option2_history[0]} [$first_time]"
        fi
        echo "===== End Debug ====="
    fi
}

# Function to check poll status
check_poll_status() {
    log_message "Checking poll status for ID=$POLL_ID"
    status_log="$LOG_DIR/poll_status_$(date +%Y%m%d_%H%M%S).log"

    random_user_agent="${user_agents[RANDOM % ${#user_agents[@]}]}"

    # Try to get poll information with a GET request
    poll_info=$(curl -s -v "https://www.wroclaw.pl/api/quiz/api/polls/$POLL_ID" \
    -H "Accept: application/json" \
    -H "User-Agent: $random_user_agent" \
    2> "$status_log")

    echo "$poll_info" > "${status_log}_response.json"

    if [ -n "$poll_info" ]; then
        log_message "Successfully retrieved poll information"
        log_debug "Poll info: $poll_info"

        # Check if the poll is active
        if echo "$poll_info" | grep -q '"active":true'; then
            log_message "Poll $POLL_ID is currently active"
            return 0
        else
            log_message "ERROR: Poll $POLL_ID appears to be inactive"
            echo -e "\n\033[1;31mError: Poll $POLL_ID is not active. Voting may not be possible.\033[0m"
            return 1
        fi
    else
        log_message "ERROR: Failed to retrieve poll information"
        echo -e "\n\033[1;31mError: Could not retrieve poll information. The API endpoint may have changed.\033[0m"
        return 2
    fi
}

# Function to draw an ASCII graph
draw_graph() {
    clear
    display_logo

    if [ "$GRAPH_WIDTH_SET" -eq 1 ]; then
        local width=$GRAPH_WIDTH
    else
        local width=$(( (GRAPH_WIDTH * 60) / 100 ))
    fi

    if [ "$GRAPH_HEIGHT_SET" -eq 1 ]; then
        local height=$GRAPH_HEIGHT
    else
        local height=$(( (GRAPH_HEIGHT * 60) / 100 ))
    fi

    local count=${#option1_history[@]}

    # Ensure height is not zero
    if [ "$height" -le 0 ]; then
        height=30
        log_debug "WARNING: Graph height was invalid, reset to $height"
    fi  # Fixed the syntax error: } -> fi

    log_debug "Drawing graph with dimensions: width=$width, height=$height, data points=$count"

    # Print current stats
    echo ""
    echo "===== Vote History Graph ====="
    echo "Time span: $(format_duration $(($(date +%s) - script_start_time)))"
    echo "Data points collected: $count"

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

        # Show debug graph if in debug mode
        draw_simple_graph
        return
    fi

    # Find min and max values for y-axis scaling
    local max_option1=0
    local max_option2=0
    local min_option1=${option1_history[0]}
    local min_option2=${option2_history[0]}

    for i in $(seq 0 $((count-1))); do
        # Update max values
        if [ ${option1_history[$i]} -gt $max_option1 ]; then
            max_option1=${option1_history[$i]}
        fi
        if [ ${option2_history[$i]} -gt $max_option2 ]; then
            max_option2=${option2_history[$i]}
        fi

        # Update min values
        if [ ${option1_history[$i]} -lt $min_option1 ]; then
            min_option1=${option1_history[$i]}
        fi
        if [ ${option2_history[$i]} -lt $min_option2 ]; then
            min_option2=${option2_history[$i]}
        fi
    done

    # Use the overall min and max for the graph with padding to improve visualization
    local min_val=$(( min_option1 < min_option2 ? min_option1 : min_option2 ))
    local max_val=$(( max_option1 > max_option2 ? max_option1 : max_option2 ))

    # Add a small margin to min/max using integer arithmetic
    local range_padding=$(( (max_val - min_val) / 10 ))
    if [ "$range_padding" -eq "0" ]; then
        range_padding=10  # Minimum padding
    fi

    min_val=$((min_val - range_padding))
    max_val=$((max_val + range_padding))

    # Calculate vote trends
    local trend_option1="STABLE"
    local trend_option2="STABLE"
    local trend_threshold=10

    if [ $count -gt 5 ]; then
        # Get the last few data points to detect trends
        local recent_option1=${option1_history[$((count-1))]}
        local older_option1=${option1_history[$((count-5))]}
        local recent_option2=${option2_history[$((count-1))]}
        local older_option2=${option2_history[$((count-5))]}

        # Calculate change rates
        local change_rate1=$((recent_option1 - older_option1))
        local change_rate2=$((recent_option2 - older_option2))

        # Determine trends
        if [ $change_rate1 -gt $trend_threshold ]; then
            trend_option1="↑ RISING"
        elif [ $change_rate1 -lt $((-trend_threshold)) ]; then
            trend_option1="↓ FALLING"
        fi

        if [ $change_rate2 -gt $trend_threshold ]; then
            trend_option2="↑ RISING"
        elif [ $change_rate2 -lt $((-trend_threshold)) ]; then
            trend_option2="↓ FALLING"
        fi

        # Display trends in status line
        echo -e "Trends - Option 1: \033[1;36m$trend_option1\033[0m, Option 2: \033[1;36m$trend_option2\033[0m"
    fi

    # Ensure min and max are not the same to avoid division by zero
    if [ $min_val -eq $max_val ]; then
        min_val=$((min_val - 10))
        max_val=$((max_val + 10))
    fi

    # Calculate the range and value per row
    local range=$((max_val - min_val))

    # Display the difference between options
    local diff=$((last_option1 - last_option2))
    if [ $diff -gt 0 ]; then
        echo -e "Current diff: \033[1;32m+$diff\033[0m (Option 1 leading)"
    elif [ $diff -lt 0 ]; then
        echo -e "Current diff: \033[1;31m$diff\033[0m (Option 2 leading)"
    else
        echo -e "Current diff: $diff (Tied)"
    fi
    echo ""

    # Initialize the graph grid
    declare -A grid
    for y in $(seq 0 $((height-1))); do
        for x in $(seq 0 $((width-1))); do
            grid[$y,$x]=" "
        done
    done

    # Calculate x positions - place points consecutively
    # Use the rightmost part of the graph for newest points
    local start_x=0
    if [ $count -gt $width ]; then
        start_x=$((count - width))
    fi

    # Plot the data points for option 1 and option 2
    for i in $(seq 0 $((count-1))); do
        # Calculate x coordinate - consecutive placement
        if [ $i -lt $start_x ]; then
            continue  # Skip points that won't fit in the graph width
        fi

        local x=$((i - start_x))
        if [ $x -ge $width ]; then
            continue  # Safety check
        fi

        # Calculate y coordinates safely with integer math when possible
        # First attempt with bc but ensure we get an integer by removing decimal part
        local y1_calc=$(echo "scale=0; ($height - 1) - (${option1_history[$i]} - $min_val) * ($height - 1) / $range" | bc | sed 's/\..*//')
        local y1=$y1_calc
        if [ -z "$y1" ] || [ "$y1" = "" ]; then
            # Fallback to bash integer math if bc has issues
            y1=$(( (height - 1) - (${option1_history[$i]} - min_val) * (height - 1) / range ))
        fi

        # Apply bounds checking
        if [ $y1 -lt 0 ]; then y1=0; fi
        if [ $y1 -ge $height ]; then y1=$((height-1)); fi

        # Repeat for option 2
        local y2_calc=$(echo "scale=0; ($height - 1) - (${option2_history[$i]} - $min_val) * ($height - 1) / $range" | bc | sed 's/\..*//')
        local y2=$y2_calc
        if [ -z "$y2" ] || [ "$y2" = "" ]; then
            # Fallback to bash integer math
            y2=$(( (height - 1) - (${option2_history[$i]} - min_val) * (height - 1) / range ))
        fi

        # Apply bounds checking
        if [ $y2 -lt 0 ]; then y2=0; fi
        if [ $y2 -ge $height ]; then y2=$((height-1)); fi

        # Plot points with appropriate symbols
        grid[$y1,$x]="+"  # Option 1
        grid[$y2,$x]="o"  # Option 2
    done

    # Draw the graph grid
    for y in $(seq 0 $((height-1))); do
        # Calculate the value for this row safely
        local value_calc=$(echo "scale=0; $max_val - ($y * $range / ($height - 1))" | bc | sed 's/\..*//')
        local value=$value_calc
        if [ -z "$value" ] || [ "$value" = "" ]; then
            # Fallback to bash integer math
            value=$(( max_val - (y * range / (height - 1)) ))
        fi

        # Y-axis labels (show values at certain intervals - every 5 lines or at first/last)
        if [ $y -eq 0 ] || [ $y -eq $((height-1)) ] || [ $((y % 5)) -eq 0 ]; then
            printf "%8s |" "$value"
        else
            printf "%8s |" ""
        fi

        # Draw the actual data for this row
        for x in $(seq 0 $((width-1))); do
            local char="${grid[$y,$x]}"
            if [ "$char" = "+" ]; then
                printf "\033[1;32m+\033[0m"  # Green for option 1
            elif [ "$char" = "o" ]; then
                printf "\033[1;31mo\033[0m"  # Red for option 2
            else
                printf " "
            fi
        done
        printf "\n"
    done

    # Print x-axis
    printf "         +"
    for x in $(seq 1 $width); do
        printf "-"
    done
    printf "\n"

    # Calculate times for x-axis labeling
    local first_idx=$start_x
    local middle_idx=$((start_x + (count - start_x) / 2))
    local last_idx=$((count - 1))

    # Ensure indexes are valid
    if [ $first_idx -lt 0 ]; then first_idx=0; fi
    if [ $middle_idx -ge $count ]; then middle_idx=$((count-1)); fi
    if [ $last_idx -ge $count ]; then last_idx=$((count-1)); fi

    # Get timestamps
    local first_time=$(format_timestamp ${timestamps[$first_idx]})
    local middle_time=$(format_timestamp ${timestamps[$middle_idx]})
    local last_time=$(format_timestamp ${timestamps[$last_idx]})

    # Calculate positions for the time labels
    local first_pos=0
    local middle_pos=$((width / 2))
    local last_pos=$((width - 1))

    # Print the three labels with appropriate spacing
    printf "         %s" "$first_time"
    if [ $count -gt 1 ]; then
        printf "%*s%s" $(( middle_pos - ${#first_time} - ${#middle_time}/2 )) "" "$middle_time"
        printf "%*s%s\n" $(( last_pos - middle_pos - ${#middle_time}/2 - ${#last_time} )) "" "$last_time"
    else
        printf "\n"
    fi

    # Print legend with properly displayed colors
    echo -e "         Legend: \033[1;32m+\033[0m Option 1, \033[1;31mo\033[0m Option 2"
    echo ""

    echo "Votes contributed: $votes_contributed (Rate: $votes_per_minute votes/min)"

    # Show simple graph for debugging
    draw_simple_graph
}

# Function to send POST request and get response
send_request() {
    # Log the request attempt
    log_message "Sending request to Poll ID=$POLL_ID, Option ID=$OPTION_ID"

    # Create a temporary file to store the response
    temp_file=$(mktemp)
    request_log="$LOG_DIR/request_$(date +%Y%m%d_%H%M%S).log"

    # Log the full curl command
    log_debug "Executing curl request: curl -X POST 'https://www.wroclaw.pl/api/quiz/api/polls/$POLL_ID/option/$OPTION_ID' -H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0...' -d '{}'"

    random_user_agent="${user_agents[RANDOM % ${#user_agents[@]}]}"

    # Send request with verbose output to log file and capture both status code and response
    status_code=$(curl -X POST "https://www.wroclaw.pl/api/quiz/api/polls/$POLL_ID/option/$OPTION_ID" \
    -H "Content-Type: application/json" \
    -H "User-Agent: $random_user_agent" \
    -H "Accept: application/json" \
    -H "Origin: https://www.wroclaw.pl" \
    -H "Referer: https://www.wroclaw.pl/" \
    -d '{}' \
    -v \
    -s -w "%{http_code}" \
    -o "$temp_file" 2> "$request_log")

    if [ "$AUTO_ADJUST" -eq 1 ] && [ "$last_status" = "RUNNING" ]; then
        # Check if we're getting too many errors
        local error_rate=$((100 * request_errors / (request_count + 1)))

        if [ $error_rate -ge 5 ]; then
            # Too many errors, increase sleep time
            SLEEP_RUNNING=$(echo "scale=2; $SLEEP_RUNNING * 1.5" | bc)
            log_message "Auto-adjusted sleep time to $SLEEP_RUNNING due to high error rate"
        elif [ $error_rate -lt 5 ] && (( $(echo "$SLEEP_RUNNING > 0.2" | bc -l) )); then
            # Very few errors, try to speed up slightly
            SLEEP_RUNNING=$(echo "scale=2; $SLEEP_RUNNING * 0.9" | bc)
            log_message "Auto-adjusted sleep time to $SLEEP_RUNNING due to low error rate"
        fi
    fi

    if [ "$status_code" -ne 200 ] && [ "$AUTO_RETRY" -eq 1 ]; then
        local retry_count=0
        local max_retries=3

        while [ "$status_code" -ne 200 ] && [ "$retry_count" -lt "$max_retries" ]; do
            log_message "Request failed with status $status_code. Retrying ($((retry_count+1))/$max_retries)..."
            sleep 1

            # Retry the request
            status_code=$(curl -X POST "https://www.wroclaw.pl/api/quiz/api/polls/$POLL_ID/option/$OPTION_ID" \
            -H "Content-Type: application/json" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
            -H "Accept: application/json" \
            -H "Origin: https://www.wroclaw.pl" \
            -H "Referer: https://www.wroclaw.pl/" \
            -d '{}' \
            -v \
            -s -w "%{http_code}" \
            -o "$temp_file" 2>> "$request_log")

            retry_count=$((retry_count + 1))
            response=$(cat "$temp_file")
        done

        if [ "$status_code" -eq 200 ]; then
            log_message "Request succeeded after $retry_count retries"
        else
            log_message "Request failed after $retry_count retries"
        fi
    fi

    if [ "$status_code" -eq "200" ] && [ "$DEBUG_MODE" -ne 1 ]; then
      rm -f $request_log
    else
      log_message "Request failed with status code $status_code"
    fi

    response=$(cat "$temp_file")

    # Log the response details
    log_message "Response received - Status: $status_code, Length: ${#response} bytes"
    log_debug "Response body: $response"

    # Clean up temp file
    rm "$temp_file"

    # Update request count and calculate requests per second
    request_count=$((request_count + 1))
    current_time=$(date +%s)
    if [ "$current_time" -gt "$last_request_time" ]; then
        requests_per_second=$((request_count / (current_time - last_request_time)))
    fi
    last_request_time=$current_time

    # Parse statistics, using last known values if parsing fails
    new_option1=$(echo $response | grep -o '"count":[0-9]*' | head -1 | cut -d':' -f2)
    new_option2=$(echo $response | grep -o '"count":[0-9]*' | tail -1 | cut -d':' -f2)
    new_total=$(echo $response | grep -o '"statistics":[0-9]*' | cut -d':' -f2)

    if [[ "$new_option1" =~ ^[0-9]+$ ]] && [[ "$new_option2" =~ ^[0-9]+$ ]]; then
        # Calculate votes contributed
        if [ "$vote_start_count" -eq 0 ]; then
            vote_start_count=$last_total
        else
            votes_contributed=$((last_total - vote_start_count))
        fi

        # Calculate votes per minute
        local elapsed_minutes=$(echo "scale=2; ($(date +%s) - $vote_start_time) / 60" | bc)
        if (( $(echo "$elapsed_minutes > 0" | bc -l) )); then
            votes_per_minute=$(echo "scale=2; $votes_contributed / $elapsed_minutes" | bc)
            # Format to max 2 decimal places
            votes_per_minute=$(printf "%.2f" $votes_per_minute)
        else
            votes_per_minute="0.00"
        fi
    fi

    log_debug "Parsed values - Option 1: $new_option1, Option 2: $new_option2, Total: $new_total"

    # Update values only if we got valid numbers
    if [[ "$new_option1" =~ ^[0-9]+$ ]] && [[ "$new_option2" =~ ^[0-9]+$ ]] && [[ "$new_total" =~ ^[0-9]+$ ]]; then
        last_option1=$new_option1
        last_option2=$new_option2
        last_total=$new_total

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

        log_debug "Added new data point #${#option1_history[@]}: Option1=$last_option1, Option2=$last_option2"
    else
        log_message "ERROR: Failed to parse valid numbers from response"
        log_debug "Invalid response format: $response"

        # If in debug mode, generate dummy data for testing
        if [ "$DEBUG_MODE" -eq 1 ]; then
            log_debug "ADDING DUMMY DATA FOR TESTING"

            # Use incremental dummy data to create a visible pattern
            if [ ${#option1_history[@]} -eq 0 ]; then
                new_option1=1000
                new_option2=800
            else
                new_option1=$((last_option1 + 5 + RANDOM % 10))
                new_option2=$((last_option2 + 3 + RANDOM % 8))
            fi
            new_total=$((new_option1 + new_option2))

            last_option1=$new_option1
            last_option2=$new_option2
            last_total=$new_total

            # Add dummy data to history arrays
            option1_history+=($last_option1)
            option2_history+=($last_option2)
            timestamps+=($(date +%s))

            # Keep arrays at specified size
            if [ ${#option1_history[@]} -gt $HISTORY_SIZE ]; then
                option1_history=("${option1_history[@]:1}")
                option2_history=("${option2_history[@]:1}")
                timestamps=("${timestamps[@]:1}")
            fi

            log_debug "Added dummy data point #${#option1_history[@]}: Option1=$last_option1, Option2=$last_option2"
        fi
    fi

    # Set status based on HTTP response code
    if [ "$status_code" -eq 200 ]; then
        if [ "$last_status" = "WAITING" ]; then
            # Calculate waiting duration when transitioning from WAITING to RUNNING
            last_waiting_duration=$((current_time - waiting_start_time))
            running_start_time=$current_time
            start_option1=$last_option1
            start_option2=$last_option2
            start_total=$last_total
            log_message "State changed: WAITING → RUNNING after $last_waiting_duration seconds"
        fi
        last_status="RUNNING"
    else
        request_errors=$((request_errors + 1))
        log_message "Request failed with status $status_code"

        if [ "$last_status" = "RUNNING" ]; then
            last_running_duration=$((current_time - running_start_time))
            last_completed_gain1=$((last_option1 - start_option1))
            last_completed_gain2=$((last_option2 - start_option2))
            waiting_start_time=$current_time
            log_message "State changed: RUNNING → WAITING after $last_running_duration seconds"
            log_message "Run gains: Option 1 +$last_completed_gain1, Option 2 +$last_completed_gain2"
        fi
        last_status="WAITING"
    fi

    # Increment iteration count
    iteration_count=$((iteration_count + 1))
    log_debug "Iteration count: $iteration_count, Graph interval: $GRAPH_INTERVAL"

    # Calculate percentages
    percent1=$(calculate_percentage $last_option1 $last_total)
    percent2=$(calculate_percentage $last_option2 $last_total)

    # Calculate vote gains
    if [ "$last_status" = "RUNNING" ]; then
        gain1=$((last_option1 - start_option1))
        gain2=$((last_option2 - start_option2))
    else
        gain1=$last_completed_gain1
        gain2=$last_completed_gain2
    fi

    # Determine colors based on which option is leading
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

    # Format durations
    formatted_waiting_duration=$(format_duration $last_waiting_duration)
    formatted_last_running_duration=$(format_duration $last_running_duration)

    local progress_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")  # Simple ASCII spinner characters
    local progress_idx=$((iteration_count % ${#progress_chars[@]}))
    local progress_char=${progress_chars[$progress_idx]}

    # Check if we need to redraw the graph
    if [ $iteration_count -eq 1 ] || [ $((iteration_count % GRAPH_INTERVAL)) -eq 0 ]; then
        log_message "Redrawing graph at iteration $iteration_count"
        draw_graph
    fi

    # Display status line with spinner at the end
    if [ "$last_status" = "RUNNING" ]; then
        echo -en "\rStatus: \033[1;32m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [+$gain1] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [+$gain2] | Total: $last_total | RPS: $requests_per_second  \033[1;36m$progress_char\033[0m\n"
    else
        echo -en "\rStatus: \033[1;31m$last_status\033[0m | Option 1: $last_option1 (${color1}$percent1%\033[0m) [+$gain1] | Option 2: $last_option2 (${color2}$percent2%\033[0m) [+$gain2] | Total: $last_total | RPS: $requests_per_second  \033[1;36m$progress_char\033[0m\n"
    fi
}

read_key_input() {
    if read -t 0.1 -n 1 key; then
        case "$key" in
            q|Q)
                echo "Quitting by user request (q pressed)..."
                cleanup
                ;;
            r|R)
                echo "Forcing graph redraw (r pressed)..."
                draw_graph
                ;;
            c|C)
                echo "Clearing history and starting fresh (c pressed)..."
                option1_history=()
                option2_history=()
                timestamps=()
                draw_graph
                ;;
        esac
    fi
}

# Display initial logo and info
display_logo

# Check poll status (if not in debug mode)
if [ "$DEBUG_MODE" -ne 1 ]; then
    check_poll_status
fi

# Main loop
while true; do
    read_key_input
    send_request

    draw_graph

    if [ "$last_status" = "RUNNING" ]; then
        sleep $(apply_sleep_randomness $SLEEP_RUNNING)
    else
        sleep $(apply_sleep_randomness $SLEEP_WAITING)
    fi
done
