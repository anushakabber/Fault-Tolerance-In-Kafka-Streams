import os
import re
import numpy as np
import pandas as pd

def parse_log(log_path):
    with open(log_path, 'r') as f:
        lines = f.readlines()

    data = {
        'log_file': os.path.basename(log_path),
        'mode': 'in-memory' if 'in-memory' in log_path else 'rocksdb',
        'recovery_time_ms': None,
        'records_recovered': 0,
        'latencies_ns': [],
        'throughput': []
    }

    for line in lines:
        if "Recovery Time:" in line:
            match = re.search(r"Recovery Time: (\d+) ms", line)
            if match:
                data['recovery_time_ms'] = int(match.group(1))

        elif "Records recovered:" in line:
            match = re.search(r"Records recovered: (\d+)", line)
            if match:
                data['records_recovered'] = int(match.group(1))

        elif "LATENCY_MS:" in line:
            try:
                latency = int(line.strip().split("LATENCY_MS:")[-1].strip())
                data['latencies_ns'].append(latency)
            except:
                continue

        elif "THROUGHPUT:" in line:
            try:
                rate = int(line.strip().split("THROUGHPUT:")[-1].strip())
                data['throughput'].append(rate)
            except:
                continue

    return data

# Collect all logs
logs = [f for f in os.listdir('.') if f.startswith('test-') and f.endswith('.log')]
parsed = [parse_log(f) for f in logs]

# Build final metrics table
metrics = []
for item in parsed:
    latencies = np.array(item['latencies_ns']) / 1e6  # convert to ms
    throughput = np.array(item['throughput'])

    metrics.append({
        'log_file': item['log_file'],
        'mode': item['mode'],
        'recovery_time_ms': item['recovery_time_ms'],
        'records_recovered': item['records_recovered'],
        'latency_p50_ms': np.percentile(latencies, 50) if len(latencies) else None,
        'latency_p95_ms': np.percentile(latencies, 95) if len(latencies) else None,
        'latency_p99_ms': np.percentile(latencies, 99) if len(latencies) else None,
        'latency_mean_ms': np.mean(latencies) if len(latencies) else None,
        'throughput_mean_rps': np.mean(throughput) if len(throughput) else None,
        'throughput_peak_rps': np.max(throughput) if len(throughput) else None,
    })

df = pd.DataFrame(metrics)

# Display table
df.to_csv("kafka_metrics_summary.csv", index=False)

