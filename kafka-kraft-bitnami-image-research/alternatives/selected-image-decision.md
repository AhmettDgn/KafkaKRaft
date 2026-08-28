# ADR-001: Bitnami'den bağımsız Kafka KRaft dağıtımı

## Durum

Kabul edildi: hedef mimari için. Uygulama ve cluster doğrulaması henüz yapılmadı.

## Bağlam

Chart 32.4.4, Bitnami container image'larının yanında Bitnami shell API'sine ve Common Helm library chart'ına bağlıdır. Mevcut `non-bitnami-values.yaml` türü bir repository/tag override render edilir, fakat runtime contract'ı değiştirmez.

## Karar

Kurum, `apache/kafka:4.0.0` kaynaklı, digest-pinned ve kurum registry'sinde yayınlanan Kafka runtime imajını kullanacaktır. Mevcut chart, kurum tarafından fork edilerek ASF image contract'ına port edilecektir. Port tamamlandığında Bitnami Common library bağımlılığı da yerel helper'lar ile kaldırılacaktır.

Geçişte iki yol vardır:

1. **Hedef yol — chart portu:** Bitnami init/config/provisioning kodu bağımsız script/template'lerle değiştirilir. Yeni Kafka imajı Bitnami scripti içermez.
2. **Geçici yol — uyumluluk imajı:** Kurum imajı mevcut Bitnami layout ve scriptlerini sunar. Registry/image kaynağını değiştirir ama Bitnami davranış sözleşmesini korur. Bu nedenle zaman sınırı ve kaldırma planı olmayan bir nihai çözüm değildir.

Strimzi/AMQ Streams alternatifi ayrı bir platform kararıdır: mevcut Helm release'i bir operator/CRD tabanlı işletim modeline dönüştürür. Bu çalışma kapsamında drop-in replacement sayılmamıştır.

## Uygulama kabul kriterleri

| Kriter | Kanıt |
| --- | --- |
| Manifestte Bitnami image yok | `helm template` + image allow-list taraması |
| Manifestte Bitnami path/script yok | `/opt/bitnami`, `libkafka.sh`, `libos.sh`, `KAFKA_CFG_` taraması; sadece tarihsel yorum istisna olabilir |
| Helm library bağımsızlığı | `Chart.yaml`/`Chart.lock` içinde Bitnami OCI dependency yok |
| Multiarch | Her yayınlanmış digest için `linux/amd64` ve `linux/arm64` manifest kanıtı |
| Supply chain | SBOM, imza/provenance, SCA/CVE raporu, tanımlı CVE eşiği |
| KRaft | 3 controller quorum, broker join, PVC restart ve rolling update |
| Veri yolu | Topic create/describe, producer/consumer, consumer group offset, TLS/SASL seçiliyse bunların testi |

## Aşamalı iş planı

1. Fork oluşturma ve mevcut manifest/test baseline'ı.
2. Init-config ve StatefulSet config/data/secret path portu; plaintext tek node smoke test.
3. Üç controller + broker KRaft, persistence ve rolling restart.
4. TLS/SASL, external access, provisioning ve JMX portu.
5. Bitnami Common helper'larının kaldırılması, image policy ve CI release gate.

## Riskler

- Mevcut PVC'ler Bitnami path'inde `meta.properties` içerir. In-place migration öncesi uyumluluk, yedekleme ve rollback planı gerekir.
- KRaft controller voter/directory ID değişimi cluster'ı bölüştürebilir. Production'ta yeni cluster + replikasyon/migration daha güvenli olabilir.
- KRaft ve Kafka binary sürümü sabit tutulmalıdır; aynı değişiklikte hem image dağıtım modeli hem Kafka major upgrade yapılmamalıdır.
