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

## 0.2.0 sonucu — 2026-08-31 21:45 UTC

Yeni topic `lab-smoke-20260831214527-8378`, RF=3 ve `min.insync.replicas=2` ile oluşturuldu. İlk partition'ın replikaları 2,0,1 ve ilk ISR 2,0,1 idi. Pod 0 replacement sonrasında ISR 2,1,0 ile yeniden üç üyeye ulaştı; quorum max follower lag 0 idi. Mesaj/kalıcılık doğrulamasından sonra topic 1'den 3 partition'a genişletildi:

```text
PartitionCount: 3  ReplicationFactor: 3
Partition: 0  Leader: 2  Replicas: 2,0,1  Isr: 2,1,0
Partition: 1  Leader: 0  Replicas: 0,1,2  Isr: 0,1,2
Partition: 2  Leader: 1  Replicas: 1,2,0  Isr: 1,2,0
Result: PASS
```

Sonuç: 0.2.0 create/describe, RF/minISR/full ISR ve partition artırma **GEÇTİ**.

## Çalıştırılmayanlar / sınırlamalar

- Yeni test topic'ini silme: **yapılmadı**; kayıtları bir saat retention kullanır, topic nesnesi kalır.
- Tekrar create idempotency'si, partition azaltma negatif testi ve provisioning Job: ayrıca test edilmedi.
- Roadmap'teki queue/topic yönetimi Kafka topic create/describe/partition yönetimiyle karşılanır; ayrı bir queue ürünü kurulduğu iddia edilmez.
- Eski 0.1.0 test verileri açık kullanıcı onayıyla sıfırlandı; bu, yeni 0.2.0 test topic'ini otomatik silme yetkisi olarak genişletilmedi.
