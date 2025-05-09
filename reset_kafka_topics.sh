#!/bin/bash

# Path to Kafka CLI
KAFKA_BIN="/Users/anushakabber/Desktop/kafka/bin"

echo "🧹 Deleting existing topics..."
$KAFKA_BIN/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic input-topic
$KAFKA_BIN/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic output-topic
sleep 120

echo "Recreating topics..."
$KAFKA_BIN/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic input-topic --partitions 1 --replication-factor 1
$KAFKA_BIN/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic output-topic --partitions 1  --replication-factor 1
sleep 30

echo " Producing fresh timestamped data..."
python3 src/main/java/com/example/producer.py

echo "🔍 Verifying message format:"
$KAFKA_BIN/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic input-topic --from-beginning --max-messages 5 \
  --property print.key=true --property print.value=true

echo "Topics reset, data loaded, and ready to run the test."
