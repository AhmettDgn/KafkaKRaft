# Kafka KRaft — bağımsız Apache laboratuvarı

Bitnami image veya Helm-library bağımlılığı olmayan Apache Kafka KRaft laboratuvarı. Chart 0.2.0, gerçek Contabo/K3s ortamında üç node deploy, exact PVC audit, quorum, topic, producer/consumer ve pod replacement sonrası kalıcılık testlerini geçti.

## Hızlı yönlendirme

- Kullanılan chart: [lab/kafka-apache](lab/kafka-apache)
- Ubuntu / Contabo kurulumu: [deploy/contabo/README.md](deploy/contabo/README.md)
- Test ve işlem raporu: [IMPLEMENTATION-REPORT.md](IMPLEMENTATION-REPORT.md)
- Roadmap kabul matrisi: [ROADMAP-COMPLIANCE.md](ROADMAP-COMPLIANCE.md)
- Araştırma ve ekran görüntüleri: [kafka-kraft-bitnami-image-research/README.md](kafka-kraft-bitnami-image-research/README.md)
- Chart/storage denetimi: [CHART-AUDIT.md](CHART-AUDIT.md)

## Repository düzeni

```text
lab/kafka-apache/                       Kullanılan bağımsız Apache Kafka chart'ı
scripts/                                Offline doğrulama ve manuel sunucu araçları
deploy/contabo/                         Ubuntu/K3s yapılandırma ve işletim rehberi
tests/                                  Chart, storage ve startup regresyon testleri
kafka-kraft-bitnami-image-research/     Araştırma, test kanıtları ve ekran görüntüleri
legacy/bitnami-kafka/                   Karşılaştırma için korunan eski Bitnami chart
```

Yeni kurulumlarda yalnız `lab/kafka-apache` kullanılır. Eski Bitnami chart çalıştırılacak hedef değildir; image-only uyumsuzluk deneyini ve araştırmanın kaynak durumunu yeniden üretmek için `legacy/` altında tutulur.

## Yerel doğrulama

Helm, Bash ve Python 3/PyYAML bulunan ortamda:

```bash
bash scripts/validate.sh
```

Ubuntu sunucu kurulumu ve manuel deploy için Contabo rehberini izleyin. GitHub Actions, otomatik SSH veya push sonrası deploy yoktur.

## Sınırlar

Bu cluster içi PLAINTEXT test ortamıdır. Üç pod aynı fiziksel sunucuda olduğundan host arızasına karşı HA sağlamaz. TLS/SASL, dış erişim, JMX, production veri taşıması, backup/restore ve güvenlik taraması ayrı kapsamdır.

Eski 0.1.0 cluster'ları normal upgrade etmeyin; önce [storage recovery rehberini](deploy/contabo/STORAGE-RECOVERY.md) inceleyin.
