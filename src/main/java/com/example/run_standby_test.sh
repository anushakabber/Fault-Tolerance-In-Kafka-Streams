#!/bin/bash

# Runs Kafka Streams app twice:
# 1. Without standby replicas
# 2. With 1 standby replica
# Collects logs for both and runs metrics_collector.py

set -e

APP_PATH="src/main/java/com/example/App.java"
BACKUP_PATH="${APP_PATH}.bak"

# Make a backup of the App.java file
cp "$APP_PATH" "$BACKUP_PATH"

inject_standby_config() {
  local standby_count=$1
  echo "Injecting NUM_STANDBY_REPLICAS = $standby_count"
  sed -i '' "/StreamsConfig.BOOTSTRAP_SERVERS_CONFIG/a\\
props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, $standby_count);" "$APP_PATH"
}


reset_topics() {
  echo "🧹 Resetting topics..."
  /Users/anushakabber/Desktop/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic input-topic || true
  /Users/anushakabber/Desktop/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic output-topic || true
  sleep 120
  /Users/anushakabber/Desktop/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic input-topic --partitions 1 --replication-factor 1
  /Users/anushakabber/Desktop/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic output-topic --partitions 1 --replication-factor 1
  sleep 5
  echo " Producing fresh timestamped data..."
  python3 src/main/java/com/example/producer.py
  sleep 1
}

run_test() {
  local mode=$1
  echo " Running test: $mode"
  bash src/main/java/com/example/run_test.sh "$mode"
}

# ---------- RUN WITHOUT STANDBY ----------
reset_topics
inject_standby_config 0
run_test no-standby

# ---------- RUN WITH 1 STANDBY ----------
reset_topics
cp "$BACKUP_PATH" "$APP_PATH"  # Restore clean state before reinjection
inject_standby_config 1
run_test standby

# Restore original App.java
cp "$BACKUP_PATH" "$APP_PATH"
echo "Done. App.java restored. Logs and metrics collected."
