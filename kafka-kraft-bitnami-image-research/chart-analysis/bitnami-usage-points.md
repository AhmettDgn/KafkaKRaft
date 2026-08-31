# Bitnami'ye bağlı kullanım noktaları

## Kritik bağlar

| Konum | Bağımlılık | Apache Kafka ile etkisi |
| --- | --- | --- |
| `templates/_init_containers.tpl:155` | `. /opt/bitnami/scripts/libkafka.sh` | ASF image'ında bu dosya yoktur; statik incelemeye göre init başarısızlığı beklenir. Bu image-only deney canlı çalıştırılmadı. |
| Aynı template | `kafka_server_conf_set`, `configure_kafka_sasl`, `configure_kafka_tls`, `retry_while`, `error` gibi Bitnami shell fonksiyonları | Bu fonksiyonlar bağımsız scriptte yeniden uygulanmalıdır. |
| `templates/_init_containers.tpl` | `/bitnami/kafka/data/meta.properties`, `/bitnami/kafka` data mount | Persisted metadata ve data mount düzeni taşınmalıdır. |
| Broker/controller StatefulSet'leri | `/opt/bitnami/kafka/config/server.properties`, log4j, cert ve secret mount'ları | Apache imajının config/secrets düzeneğine göre değiştirilmelidir. |
| Broker/controller environment | `KAFKA_CFG_PROCESS_ROLES` ve common env içindeki `KAFKA_CFG_*` | ASF imajının `KAFKA_*` sözleşmesine veya yazılmış properties dosyasına dönüştürülmelidir. |
| `templates/provisioning/job.yaml:62,185,188,251` | `libkafka.sh`, `libos.sh`, `/opt/bitnami/kafka/bin/*` | Provisioning Job port edilmeden etkinleştirilemez. |
| `templates/_helpers.tpl:564-565,648-707` | Bitnami config/cert/secret path'leri | TLS ve SASL file path'leri yeni imaj layout'una taşınmalıdır. |
| `templates/secrets.yaml` | `provider: bitnami` metadata değeri | Secret tüketicileri etkilenmiyorsa metadata temizlenmelidir. |
| `templates/NOTES.txt` | Bitnami Secure Images mesajı ve komutları | Kullanıcı dokümantasyonu güncellenmelidir. |

## “Sadece values” neden yeterli değildir?

Bu chart'ın `image`, `broker.command`, `broker.args`, `controller.command` ve `controller.args` değerleri olsa da `prepare-config` init container'ının command/args alanları values ile override edilemez; her iki StatefulSet de bu init container'ı koşulsuz ekler. Bu init container ilk çalıştığı için ana container command override'ı problemi çözmez.

Ek olarak, `volume-permissions` ve auto-discovery scriptleri `/bin/bash` ile başlar. Bu nedenle Alpine gibi `bash` içermeyen bir imajı sadece repository/tag değiştirerek kullanmak da güvenli değildir.

## Port sınırı

Salt image bağımlılığını kaldırmak için en az şu template grupları değişmelidir:

1. `_init_containers.tpl`
2. `broker/statefulset.yaml` ve `controller-eligible/statefulset.yaml`
3. `_helpers.tpl`
4. `provisioning/job.yaml`
5. JMX komutu/mount'ları ve `NOTES.txt`
6. `Chart.yaml` ile Common-library çağrıları (tam Bitnami ayrışması hedefleniyorsa)

Bu nedenle doğru değişim tipi “values override” değil, kontrollü bir chart fork/port işlemidir.

Bu haftaki uygulama, bu özelliklerin tamamını taşımak yerine `lab/kafka-apache` altında sınırlı bağımsız demo chart'ıdır. Orijinal template'ler korunmuştur; demo içinde TLS/SASL/JMX/provisioning Job port edildiği iddia edilmez. [Seçim ve kapsam](../alternatives/selected-image-decision.md).
