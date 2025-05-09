# producer.py
from kafka import KafkaProducer
import time
import random

producer = KafkaProducer(bootstrap_servers='localhost:9092')

start = time.time()
for i in range(10000):
    key = f"user{random.randint(1, 10000)}"
    value = str(time.time_ns())  # Embed send timestamp in nanoseconds
    producer.send("input-topic", key=key.encode(), value=value.encode())
    if i % 100 == 0:
        time.sleep(0.01)

producer.flush()
producer.close()

end = time.time()
print(f"Produced 10,000 records in {end - start:.2f} seconds.")
