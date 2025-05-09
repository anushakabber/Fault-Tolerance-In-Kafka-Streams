# Kafka Streams Fault Tolerance Benchmarking

This project evaluates the **fault tolerance characteristics of Apache Kafka Streams** under various configurations: state store types (RocksDB vs in-memory), changelog tuning, standby replicas, and workload variations. It systematically measures **recovery time**, **processing latency**, and **throughput** under simulated crash-restart scenarios.

---

## 📁 Project Structure

├── results/ # CSV results from multiple experiment batches
│ ├── kafka_metrics_summary_*.csv
│
├── src/main/java/com/example/
│ └── App.java # Main Kafka Streams app with instrumentation
│
├── producer.py # Timestamped record producer to Kafka topic
├── metrics_collector.py # Parses logs and extracts recovery/latency/throughput metrics
├── run_test.sh # Simulates crash-restart for RocksDB or in-memory runs
├── run_standby_test.sh # Tests recovery with vs without standby replicas
├── run_changelog_comparison.sh # Tests recovery with default vs tuned changelog settings
├── reset_kafka_topics.sh # Deletes and recreates Kafka topics before test runs
├── pom.xml # Maven build configuration
└── README.md # You're here

## ⚙️ Dependencies

- Java 17
- Apache Kafka 3.6.x
- ZooKeeper (default coordination setup)
- Python 3.10+
- Bash

🧪 Running an Experiment
✅ 1. Basic Crash-Recovery Run

`bash run_test.sh rocksdb`
`bash run_test.sh in-memory`

This launches the app, sends records via producer.py, kills and restarts the stream processor, and collects metrics.

✅ 2. Standby Replica Comparison

`bash run_standby_test.sh`

This rebuilds and reruns the app with num.standby.replicas = 0 and 1, then logs recovery/latency differences.

✅ 3. Changelog Tuning Comparison

`bash run_changelog_comparison.sh`

Tests the effect of:segment.ms=10000, min.cleanable.dirty.ratio=0.01

🔁 Always Reset Topics Before New Runs

`bash reset_kafka_topics.sh`

This deletes and recreates input-topic, output-topic, and any changelog topics.

📊 Metrics Captured
The application prints detailed logs that are parsed by metrics_collector.py. Metrics include:

recovery_time_ms: Time from restart to first restored record

latency_mean_ms: End-to-end event latency, computed per record

throughput_mean_rps: Mean records processed per second during live ingestion

Results are stored in /results/*.csv.