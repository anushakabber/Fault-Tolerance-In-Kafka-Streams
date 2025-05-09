#!/bin/bash

# This script compares changelog recovery performance:
# 1. With default Kafka changelog configs
# 2. With tuned changelog settings (segment.ms, min.cleanable.dirty.ratio)

set -e

TOPIC="fault-tolerance-demo-rocksdb-reduce-store-changelog"
KAFKA_BIN="/Users/anushakabber/Desktop/kafka/bin"
BROKER="localhost:9092"

reset_changelog_config() {
  echo "🧹 Resetting changelog configs to Kafka defaults (best effort)..."

  $KAFKA_BIN/kafka-configs.sh --bootstrap-server $BROKER \
    --entity-type topics --entity-name "$TOPIC" \
    --alter --delete-config segment.ms || echo "(segment.ms not set, skipping)"

  $KAFKA_BIN/kafka-configs.sh --bootstrap-server $BROKER \
    --entity-type topics --entity-name "$TOPIC" \
    --alter --delete-config min.cleanable.dirty.ratio || echo "(min.cleanable.dirty.ratio not set, skipping)"
}

tune_changelog_config() {
  echo "🔧 Tuning changelog topic with aggressive compaction..."
  $KAFKA_BIN/kafka-configs.sh --bootstrap-server $BROKER \
    --entity-type topics --entity-name "$TOPIC" \
    --alter \
    --add-config segment.ms=10000,min.cleanable.dirty.ratio=0.01
}

run_test_variant() {
  local mode=$1
  echo "🚀 Running recovery test: $mode"
  bash reset_kafka_topics.sh
  python3 src/main/java/com/example/producer.py
  bash src/main/java/com/example/run_test.sh "$mode"
}

# Run baseline test
reset_changelog_config
run_test_variant changelog-default

# Run tuned test
bash reset_kafka_topics.sh
python3 src/main/java/com/example/producer.py

tune_changelog_config
run_test_variant changelog-tuned

# Summarize
python3 metrics_collector.py

echo "✅ Done. Compare 'changelog-default' vs 'changelog-tuned' in the metrics CSV."
