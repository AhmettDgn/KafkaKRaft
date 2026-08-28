# Producer ve consumer veri yolu testi

## Durum

Çalıştırılmadı. Bu dokümanda örnek mesaj çıktısı PASS kanıtı değildir; gerçek deploy sonrasında aşağıdaki prosedür ve kaydedilmiş çıktı kullanılmalıdır.

## Test prosedürü

Önce `orders-stream-v1` topic'inin üç partition ve uygun replication factor ile var olduğunu doğrulayın. Ardından geçici producer/consumer pod'larında **aynı onaylanmış kurum Kafka imajını** kullanın:

```bash
kubectl run kafka-producer -n kafka --rm -i --restart=Never \
  --image=registry.example.invalid/platform/kafka@sha256:APPROVED_DIGEST -- \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server kafka-kraft:9092 --topic orders-stream-v1

kubectl run kafka-consumer -n kafka --rm -i --restart=Never \
  --image=registry.example.invalid/platform/kafka@sha256:APPROVED_DIGEST -- \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-kraft:9092 --topic orders-stream-v1 \
  --from-beginning --group bitnami-exit-e2e
```

## Kabul kriterleri

1. Producer'a gönderilen benzersiz en az üç mesaj consumer tarafından aynı sırayla alınır (partition anahtarına göre beklenen sıralama tanımlanmalıdır).
2. Consumer group offset'i commit edilir ve lag, consumer tamamlandıktan sonra sıfıra iner.
3. Bir broker/controller restart'ından sonra yeni producer/consumer çalışması başarılı olur.
4. TLS/SASL etkin ortamda client property dosyası doğru secret mount'undan okunur; düz metin credential loglanmaz.

## Kaydedilecek kanıt

Image digest, cluster/chart sürümü, topic yapılandırması, producer girişleri, consumer çıktısı ve `kafka-consumer-groups.sh --describe` çıktısı saklanmalıdır. Credential, broker URL'nin hassas kısmı ve müşteri verisi redakte edilmelidir.
