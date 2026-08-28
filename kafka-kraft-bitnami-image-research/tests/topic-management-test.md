# Topic yönetimi testi

## Durum

Çalıştırılmadı. Kubernetes context'i bu çalışma ortamında erişilebilir değildir ve mevcut image-only override'ın init aşamasında çalışmayacağı belirlenmiştir.

## Port edilmiş cluster için test prosedürü

```bash
POD=kafka-kraft-controller-0
BOOTSTRAP=kafka-kraft:9092

kubectl exec -n kafka "$POD" -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$BOOTSTRAP" \
  --create --if-not-exists --topic orders-stream-v1 \
  --partitions 3 --replication-factor 3

kubectl exec -n kafka "$POD" -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$BOOTSTRAP" --describe --topic orders-stream-v1

kubectl exec -n kafka "$POD" -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server "$BOOTSTRAP" --alter --topic orders-stream-v1 --partitions 6
```

## Beklenen kanıtlar

- `create` idempotent olarak başarılı olur.
- `describe`, üç partition için beklenen leader/replica/ISR bilgisini gösterir.
- Partition sayısı 3'ten 6'ya çıkar; Kafka partition sayısını azaltmaya izin vermez.
- Port edilmiş provisioning Job etkinse aynı topic ayrı bir test adıyla, idempotency ve hata görünürlüğü kontrol edilerek test edilir.

Komut yolu (`/opt/kafka/bin`) ASF imajına özgü kabul edilmiştir; kurum imajı farklı bir layout sunuyorsa test komutları imaj sözleşmesiyle birlikte güncellenmelidir.
