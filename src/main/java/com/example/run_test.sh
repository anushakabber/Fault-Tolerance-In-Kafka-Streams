#!/bin/bash

APP_MODE=$1  # "in-memory" or empty for RocksDB
TIMESTAMP=$(date +%s)
LOG_FILE="test-${APP_MODE:-rocksdb}-${TIMESTAMP}.log"
OUTPUT_LOG="output-${APP_MODE:-rocksdb}-${TIMESTAMP}.log"
KAFKA_CONSOLE_CONSUMER="/Users/anushakabber/Desktop/kafka/bin/kafka-console-consumer.sh"

echo "========== Running Kafka Streams App ($APP_MODE) =========="
echo "[$(date)] Starting test run..." | tee "$LOG_FILE"

# Step 1: Produce workload
echo "[$(date)] Producing workload to Kafka..." | tee -a "$LOG_FILE"
python3 producer.py >> "$LOG_FILE" 2>&1

# Step 2: Start Kafka Streams app
echo "[$(date)] Launching Kafka Streams app..." | tee -a "$LOG_FILE"
START_TIME=$(date +%s%3N)  # ms
mvn exec:java -Dexec.mainClass="com.example.App" -Dexec.args="$APP_MODE" >> "$LOG_FILE" 2>&1 &
APP_PID=$!

# Step 3: Let it process for a bit
sleep 120

# Step 4: Kill the app (simulate crash)
echo "[$(date)] Simulating crash..." | tee -a "$LOG_FILE"
kill -9 $APP_PID
sleep 5

# Step 5: Restart app (measure recovery)
echo "[$(date)] Restarting app..." | tee -a "$LOG_FILE"
RECOVERY_START=$(gdate +%s%3N)
mvn exec:java -Dexec.mainClass="com.example.App" -Dexec.args="$APP_MODE" >> "$LOG_FILE" 2>&1 &
APP_PID=$!

# Wait for FIRST_RECORD_AFTER_RESTORE
echo "[$(date)] Waiting for recovery signal in logs..." | tee -a "$LOG_FILE"
while true; do
    if grep -q "FIRST_RECORD_AFTER_RESTORE" "$LOG_FILE"; then
        RECOVERY_END=$(gdate +%s%3N)
        break
    fi
    sleep 0.2
done

# Step 6: Read from output-topic
echo "[$(date)] Waiting for output messages on 'output-topic'..." | tee -a "$LOG_FILE"
$KAFKA_CONSOLE_CONSUMER --bootstrap-server localhost:9092 \
    --topic output-topic --from-beginning --timeout-ms 60000 \
    | tee "$OUTPUT_LOG"

RECOVERY_TIME=$((RECOVERY_END - RECOVERY_START))

# Step 7: Print metrics
echo "[$(date)] Recovery Time: ${RECOVERY_TIME} ms" | tee -a "$LOG_FILE"
RECORD_COUNT=$(grep -c ".*" "$OUTPUT_LOG")
echo "[$(date)] Records recovered: $RECORD_COUNT" | tee -a "$LOG_FILE"

kill $APP_PID
echo "========== Done =========="
