# Set status based on HTTP response code
if [ "$status_code" -eq 200 ]; then
    last_status="RUNNING"
else
    last_status="WAITING"
    # Sleep for 2 seconds on any non-200 response
    sleep 2
fi 