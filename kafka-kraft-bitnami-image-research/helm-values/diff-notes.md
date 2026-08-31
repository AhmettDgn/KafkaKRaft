# Values değişiklikleri — iki ayrı deney

## Dosyaları karıştırmayın

| Dosya | Hedef chart | Amaç |
| --- | --- | --- |
| original-values.yaml | Kökteki Bitnami chart | Orijinal image alanlarının referans alt kümesi; tam deploy values değildir |
| image-only-override.yaml | Kökteki Bitnami chart + values-template.yaml | **Yalnız offline negatif deney:** ASF image'a geçince hard-coded Bitnami scriptlerinin kaldığını gösterir |
| non-bitnami-values.yaml | lab/kafka-apache 0.2.0 | Seçilen Apache image/digest, 3 pod ve storage için gerçek schema-uyumlu override |

Önceki placeholder kurum-image taslağı gerçek uygulanabilir lab values ile değiştirildi. Kurum registry'sinde image build/yayını yapılmış gibi gösterilmiyor. Eski 0.1.0 canlı cluster için bu dosyayı doğrudan deploy etmeyin; [storage recovery](../../deploy/contabo/STORAGE-RECOVERY.md) engeli geçerlidir.

## Image-only deney

```bash
helm lint . --strict -f values-template.yaml \
  -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml
helm template image-only . -n kafka-lab -f values-template.yaml \
  -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml
```

Buradaki `global.security.allowInsecureImages=true`, negatif render deneyi için Bitnami'nin image tanıma kontrolünü aşar; image'ın güvenli/uyumlu olduğu anlamına gelmez. Bu deney chart'ı **çalıştırmaz** ve mevcut init scriptini düzeltmez.

## Gerçek lab values render'ı

```bash
helm lint lab/kafka-apache --strict \
  -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
helm template kafka-lab lab/kafka-apache -n kafka-lab \
  -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
```

## Gerekli template değişiklikleri

| Alan | Eski chart | Bağımsız lab |
| --- | --- | --- |
| Runtime image | registry + repository, Bitnami 4.0.0 paketlemesi | docker.io/apache/kafka:4.0.2 + digest |
| Command / args | Bitnami init/config/start sözleşmesi | /bin/bash /scripts/start.sh; Apache server binary |
| Env / config | KAFKA_CFG_* ve Bitnami shell helper | POD_NAME/NAMESPACE, CLUSTER_ID; /work/server.properties |
| PVC/data | /bitnami/kafka; eski template sözleşmesi | PVC exact /var/lib/kafka/data; Kafka log dizini kraft/ |
| Image VOLUME | Bitnami image'a göre tasarlanmış | Apache'nin 3 volume'u açık mount; child shadow engeli |
| Güvenlik | Bitnami runtime'a bağlı izin/init yaklaşımı | UID/GID/fsGroup 1000, rootfs readonly; ayrı root init yok |
| Yardımcı image'lar | os-shell, kubectl, jmx-exporter ve provisioning | Lab'da gerekli özellikler azaltıldı; JMX/external-discovery/provisioning Job yok |
| Helm library | Bitnami common | Yerel lab.* helper'ları; dependency yok |

Bu bir **sınırlı bağımsız demo chart'ıdır**, eski chart'ın TLS/SASL/JMX/external access dahil tüm özelliklerinin portu değildir. Roadmap bu özelliklerin geliştirilmesini zorunlu tutmuyor; ancak image kullanım noktalarını açıklamayı istiyor.
