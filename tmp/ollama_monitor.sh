"#!/bin/bash

LOG_FILE=\"/tmp/ollama_diagnostic.log\"
echo \"Timestamp | AvailRAM | SwapUsed | Runner_RSS(KB) | Runner_CPU%\" > \"$LOG_FILE\"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Memory info
    AVAIL_RAM=$(free -h | awk '/^Mem:/ {print $7}')
    SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
    
    # Find the llama-server process (the actual model runner)
    RUNNER_PID=$(pgrep -f \"llama-server\" | head -n 1)
    
    if [ -z \"$RUNNER_PID\" ]; then
        OLLAMA_RSS=\"N/A\"
        OLLAMA_CPU=\"N/A\"
    else
        OLLAMA_RSS=$(ps -p \"$RUNNER_PID\" -o rss= | tr -d ' ')
        OLLAMA_CPU=$(ps -p \"$RUNNER_PID\" -o %cpu= | tr -d ' ')
    fi

    echo \"$TIMESTAMP | $AVAIL_RAM | $SWAP_USED | $OLLAMA_RSS | $OLLAMA_CPU\" >> \"$LOG_FILE\"
    sleep 2
done"