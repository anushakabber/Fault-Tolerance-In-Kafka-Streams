package com.example;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.utils.Bytes;
import org.apache.kafka.streams.*;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.*;

import java.time.Instant;
import java.util.Properties;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicBoolean;

public class App {
    public static void main(String[] args) {
        boolean useInMemoryStore = args.length > 0 && args[0].equalsIgnoreCase("in-memory");

        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "fault-tolerance-demo");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 0);props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 0);        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> input = builder.stream("input-topic");

        Materialized<String, String, KeyValueStore<Bytes, byte[]>> storeMaterialized = useInMemoryStore
                ? Materialized.<String, String>as(Stores.inMemoryKeyValueStore("in-memory-reduce-store"))
                    .withKeySerde(Serdes.String())
                    .withValueSerde(Serdes.String())
                : Materialized.<String, String, KeyValueStore<Bytes, byte[]>>as("rocksdb-reduce-store")
                    .withKeySerde(Serdes.String())
                    .withValueSerde(Serdes.String());

        // Throughput counter
        AtomicInteger counter = new AtomicInteger();
        ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor();
        executor.scheduleAtFixedRate(() -> {
            System.out.println("THROUGHPUT: " + counter.getAndSet(0));
        }, 1, 1, TimeUnit.SECONDS);

        // Track first record after restore
        AtomicBoolean firstRecordSeen = new AtomicBoolean(false);

        KTable<String, String> reduced = input
                .peek((key, value) -> {
                    if (!firstRecordSeen.getAndSet(true)) {
                        System.out.println("FIRST_RECORD_AFTER_RESTORE at " + System.currentTimeMillis());
                    }

                    try {
                        long now = System.currentTimeMillis();
                        long sentMillis = Long.parseLong(value) / 1_000_000;
                        long latency = now - sentMillis;
                        System.out.println("LATENCY_MS: " + latency);
                    } catch (NumberFormatException e) {
                        // Not a timestamped value — skip
                    }

                    counter.incrementAndGet();
                })
                .groupByKey()
                .reduce((oldValue, newValue) -> newValue, storeMaterialized);

        reduced.toStream().to("output-topic", Produced.with(Serdes.String(), Serdes.String()));

        KafkaStreams streams = new KafkaStreams(builder.build(), props);
        streams.start();

        System.out.println("STREAMS APP STARTED at " + Instant.now().toEpochMilli());

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("STREAMS APP STOPPED at " + Instant.now().toEpochMilli());
            streams.close();
            executor.shutdown();
        }));
    }
}
