# Kafka KRaft chart'ından Bitnami bağımlılığını kaldırma analizi

> 2026-08-31 güncellemesi: Bu klasör tarihsel analizdir. Artık ayrı [Apache Kafka 4.0.2 laboratuvar chart'ı](../lab/kafka-apache) bulunmaktadır. Güncel kapsam/test durumu [uygulama raporundadır](../IMPLEMENTATION-REPORT.md). Aşağıdaki eski image/fork önerileri yeni kurulum talimatı değildir; analizdeki values dosyaları yeni chart'a verilmemelidir. GitHub otomasyonu kaldırılmıştır.

## Karar özeti

Mevcut chart, yalnızca image repository/tag override edilerek `apache/kafka` ile güvenle çalıştırılamaz. `helm template` başarılı olsa da template'ler Bitnami'nin dosya sistemi, bash kütüphaneleri ve `KAFKA_CFG_*` sözleşmesine doğrudan bağlıdır. Bu nedenle **salt values override yaklaşımı reddedilmiştir**.

Önerilen hedef mimari, ASF'nin resmi `apache/kafka:4.0.0` imajını kullanan ve bu chart'ın Bitnami'ye bağlı template'lerini port eden kurum içi Helm fork'udur. Bu, hem Bitnami registry/image bağımlılığını hem de Bitnami Common Helm bağımlılığını ortadan kaldıran tek sürdürülebilir yaklaşımdır. Geçişi hızlandırmak için Bitnami scriptlerini taşıyan uyumluluk imajı kurulabilir; ancak bu yalnızca geçici köprüdür, hedef durum değildir.

Bu çalışma 29 Ağustos 2026 tarihinde incelenmiştir. `apache/kafka:4.0.0` OCI manifesti bu ortamdan doğrudan doğrulanmış ve `linux/amd64` ile `linux/arm64` varyantlarını içermektedir. Apache'nin resmi Docker imajı 3.7.0'dan beri yayınlanmaktadır ve 4.0.0 sürümü Kafka'nın resmi indirme sayfasında yer alır ([Apache Kafka Docker](https://kafka.apache.org/40/getting-started/docker/), [4.0.0 sürümü](https://kafka.apache.org/community/downloads/)).

## Mevcut repository yapısı

```text
.
├── Chart.yaml                         # Kafka 32.4.4; Bitnami Common chart bağımlılığı
├── Chart.lock
├── values-template.yaml               # Kurum registry placeholder'lı ana değer şablonu
├── values/values-aws-satcom-preprod-3pp.yaml
├── templates/
│   ├── _init_containers.tpl           # Kritik Bitnami init/script bağımlılığı
│   ├── _helpers.tpl                   # Konfigürasyon, TLS ve secret path'leri
│   ├── broker/ ve controller-eligible/# StatefulSet'ler
│   ├── provisioning/                  # Topic provisioning Job'ı
│   └── metrics/                       # JMX exporter kaynakları
└── kafka-kraft-bitnami-image-research/# Bu analiz ve doğrulama kanıtları
```

Chart, controller-eligible StatefulSet'i ile broker StatefulSet'ini, KRaft metadata quorum için controller listener'ını ve isteğe bağlı provisioning/JMX bileşenlerini üretir. `Chart.yaml` içindeki `common` bağımlılığı `oci://registry-1.docker.io/bitnamicharts` kaynağındandır; bu bir container image değil, ayrıca ele alınması gereken Helm-library bağımlılığıdır.

## Doğrulanmış bulgular

| Alan | Sonuç |
| --- | --- |
| Image-only override render edilir mi? | Evet. `helm lint` geçti; `helm template` geçti. |
| Image-only override deploy edilebilir mi? | Hayır, kanıtlanmış değildir; mevcut template üzerinde teknik olarak beklenen sonuç init-container hatasıdır. |
| Ana kırılma | `prepare-config`, `/opt/bitnami/scripts/libkafka.sh` dosyasını kaynak alır. Bu dosya ASF imajında yoktur. |
| İkincil kırılmalar | `/opt/bitnami/kafka/*` mount/path'leri, `KAFKA_CFG_*`, Bitnami provisioning scriptleri ve JMX sidecar komutu. |
| Mevcut önerideki JMX imajı | `quay.io/prometheus/jmx-exporter:1.0.1` manifesti bulunamadı; kullanılmamalıdır. |
| Deploy testi | Bu çalışma alanında okunabilir bir kubeconfig yok; Kubernetes deploy/producer/consumer testi yapılmadı. |

Detaylı kanıtlar için [image bağımlılık envanteri](chart-analysis/image-dependencies.md), [bağlı kullanım noktaları](chart-analysis/bitnami-usage-points.md) ve [render testi](tests/helm-template-output.md) dosyalarına bakın.

## Hedef yaklaşım

1. Chart'ı kurum repository'sine fork edin ve Bitnami Common helper çağrılarını yerel helper'larla değiştirin.
2. `prepare-config` mantığını, `apache/kafka` sözleşmesine göre `/mnt/shared/config/server.properties` üreten bağımsız bir script/ConfigMap olarak yazın.
3. StatefulSet'lerde `KAFKA_CFG_*` yerine Apache imajının desteklediği `KAFKA_*` değişkenlerini veya doğrudan `server.properties` dosyasını kullanın; data/config/secret mount path'lerini Apache düzenine taşıyın.
4. `volume-permissions` ve `auto-discovery` scriptlerini POSIX `sh` uyumlu hâle getirin. Sonra sırasıyla doğrulanmış minimal shell ve `registry.k8s.io/kubectl` tabanlı kurum imajlarına geçin.
5. JMX için yayıncıya ait imajı varsaymak yerine, doğrulanmış JMX Exporter release JAR'ını içeren imzalı kurum imajı üretin veya Java agent modelini seçin.
6. Digest pinleme, SBOM, imza doğrulama, CVE eşiği ve hem `amd64` hem `arm64` manifest kontrolünü release gate yapın.

Detaylı kabul kriterleri ve aşamalı yol haritası [seçim kararı](alternatives/selected-image-decision.md) içindedir.

## Doğrulama durumu

| Test | Durum | Kanıt |
| --- | --- | --- |
| Helm lint | Geçti | `tests/helm-template-output.md` |
| Helm render | Geçti; runtime uyumluluğu kanıtı değildir | `tests/helm-template-output.md` |
| Kubernetes deploy | Çalıştırılmadı | `tests/deploy-notes.md` |
| Topic yönetimi | Çalıştırılmadı | `tests/topic-management-test.md` |
| Producer/consumer | Çalıştırılmadı | `tests/producer-consumer-test.md` |

## Kaynaklar

- [Apache Kafka Docker dokümantasyonu](https://kafka.apache.org/40/getting-started/docker/)
- [Apache Kafka Docker kullanım rehberi](https://github.com/apache/kafka/tree/trunk/docker)
- [Strimzi KRaft dokümantasyonu](https://strimzi.io/docs/operators/latest/deploying)
- [Confluent Docker platform desteği](https://docs.confluent.io/platform/current/installation/docker/installation.html)
- [Chainguard Kafka image dokümantasyonu](https://images.chainguard.dev/directory/image/kafka/overview)
- [Kubernetes registry ve imza/SBOM bilgisi](https://kubernetes.io/releases/download/)
