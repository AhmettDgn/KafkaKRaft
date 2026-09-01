# Helm lint/render doğrulaması — 2026-08-31

Ortam: yerel Windows, Helm v3.21.4, Python/PyYAML. Komutlar repository kökünden çalıştırıldı. Bu testler cluster bağlantısı/kurulum gerektirmez; sunucuya gönderilmedi.

## 1. Orijinal chart + yalnız image override

```bash
helm lint legacy/bitnami-kafka --strict -f legacy/bitnami-kafka/values-template.yaml -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml
helm template kafka-lab legacy/bitnami-kafka -n kafka-lab -f legacy/bitnami-kafka/values-template.yaml -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml
```

Lint GEÇTİ: 1 chart, 0 failed. Legacy chart'ta varsayılan values.yaml bulunmaması INFO; açık values-template.yaml kullanıldı.
Render GEÇTİ. Root common helper digest verildiğinde tag'i atlar; image alanı:

```text
docker.io/apache/kafka@sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f
```

Python regresyonu gerçek render metninde şu literal occurrence sayılarını ölçtü:

| Pattern | Sayı | Anlam |
| --- | --- | --- |
| /opt/bitnami | 4 | Script, config ve log path sözleşmeleri devam ediyor |
| libkafka.sh | 1 | prepare-config Bitnami kütüphanesini kaynak alıyor |
| KAFKA_CFG_ | 1 | Bitnami env sözleşmesi devam ediyor |

Sayılar birbirinden bağımsız literal substring sayılarıdır; dosya/satır sayısı veya tüm özelliklerin tam envanteri değildir. Bu deneyde metrics/provisioning/external discovery kapalıdır. Tam özellik envanteri [ayrı belgede](../chart-analysis/image-dependencies.md).

Negatif bulgu BEKLENEN SONUÇ: yalnız image override runtime portu değildir. Orijinal chart'ın Apache ile canlı kurulumu denenmedi; statik uyumsuzluk, gerçekten gözlenmiş bir init crash'i gibi sunulmadı.

## 2. Bağımsız chart + teslim edilen values

```bash
helm lint lab/kafka-apache --strict -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
helm template kafka-lab lab/kafka-apache -n kafka-lab -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
```

Lint GEÇTİ: 1 chart, 0 failed; icon önerisi INFO.
Render GEÇTİ: Apache image/digest, 3 replika, local-path 5Gi PVC, exact /var/lib/kafka/data mount, ayrı helper/init image olmaması doğrulandı. Bitnami image/path/KAFKA_CFG_ ve registry placeholder taramasında eşleşme yok.

```text
test_delivered_lab_values_render_with_exact_pvc_mount ... ok
test_delivery_files_and_local_links ... ok
test_original_chart_image_only_is_not_runtime_port ... ok
Ran 3 tests
OK
LEGACY image-only experiment: /opt/bitnami=4, libkafka.sh=1, KAFKA_CFG_=1
```

Otomatik tekrar: [tests/test_roadmap.py](../../tests/test_roadmap.py); [scripts/validate.sh](../../scripts/validate.sh) bu üç testi de çalıştırır. Dosya/link testi belge varlığını kontrol eder; ekran görüntülerinin mevcut olduğunu veya belgelerdeki her iddianın bağımsız doğrulandığını kanıtlamaz.

## Sonuç ayrımı

- Helm lint/render: GEÇTİ, offline.
- Yeni chart 0.2.0 için API server dry-run/deploy/restart: ÇALIŞTIRILMADI.
- Eski 0.1.0 canlı deploy/mesajlaşma: kullanıcı terminal kanıtında GEÇTİ.
- Eski 0.1.0 restart/kalıcılık: BAŞARISIZ; [teknik neden](deploy-notes.md).
- Render edilen Secret rastgele değerleri rapora kopyalanmadı; gerçek credential kullanılmadı.
