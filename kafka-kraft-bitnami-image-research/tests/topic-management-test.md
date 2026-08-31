# Topic yönetimi — gerçek sonuçlar

Kaynak: kullanıcının 2026-08-31 Contabo terminal çıktısı; chart 0.1.0 / kaynak 0747716. Ajan bağımsız bir canlı çalıştırma yapmadı.

## Geçen kontroller

```text
Topic: lab-smoke-20260831105749-15898
PartitionCount: 1
ReplicationFactor: 3
Configs: min.insync.replicas=2,segment.bytes=268435456,retention.ms=3600000
Partition: 0  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
```

Producer/consumer doğrulaması sonrasında aynı topic 1 partition'dan 3'e artırıldı:

```text
PartitionCount: 3  ReplicationFactor: 3
Partition: 0  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
Partition: 1  Leader: 0  Replicas: 0,1,2  Isr: 0,1,2
Partition: 2  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
Result: PASS
```

Uzun TopicId değeri çıkarılmış, gerçek çıktının ilgili alanları korunmuştur. Create, describe, replication/ISR ve partition artırma **geçti**.

## Çalıştırılmayanlar / sınırlamalar

- Topic silme veya veri reset: **yapılmadı**; kullanıcıdan yetki alınmadı.
- Tekrar create idempotency'si, partition azaltma negatif testi ve provisioning Job: ayrıca test edilmedi.
- Roadmap'teki queue/topic yönetimi Kafka topic create/describe/partition yönetimiyle karşılanır; ayrı bir queue ürünü kurulduğu iddia edilmez.
- 0.2.0 canlı topic testi: bekliyor. Eski kurulumda storage sorunu olduğundan yeni mutation testleri öncesinde recovery kararı gerekir.
