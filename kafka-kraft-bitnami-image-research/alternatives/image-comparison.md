# Alternatif image değerlendirmesi

## Değerlendirme ilkesi

Bir imajın `amd64` ve `arm64` desteği, tag/digest düzeyinde OCI manifestiyle doğrulanmalıdır; provider veya eski bir tag için verilen genel ifade kabul kanıtı değildir. Örnek komut:

```powershell
docker manifest inspect <image@sha256:...> | Select-String 'architecture|os'
```

Bu çalışmada `apache/kafka:4.0.0`, `alpine:3.20.2` ve `registry.k8s.io/kubectl:v1.33.4` için hem `linux/amd64` hem `linux/arm64` görüldü. Seçilen sürümler release öncesinde digest ile tekrar kontrol edilmelidir.

| Aday | Açık kaynak / tedarikçi | amd64/arm64 | KRaft | Mevcut Bitnami chart uyumu | Güvenlik ve karar |
| --- | --- | --- | --- | --- | --- |
| Bitnami Kafka | Bitnami/Broadcom; mevcut Apache Kafka paketlemesi | Mevcut chart ile çalışır; bu çalışma kapsamında tekrar manifest doğrulaması yapılmadı | Evet | Tam | Çıkış noktası; hedef değil. |
| `apache/kafka` | Apache-2.0, Apache Software Foundation | `4.0.0` için doğrulandı | Evet; resmi imajın varsayılanı KRaft'tır | Düşük: template portu gerekir | **Runtime için seçildi.** ASF sürümü, imza/SBOM/CVE taraması kurum pipeline'ında gate olmalı. |
| Chainguard Kafka | Chainguard; `cgr.dev/<organization>/kafka` erişimi gerekir | Tag/digest başına doğrulanmalı | Evet; Apache image entrypoint/`KAFKA_*` uyumluluğu belgeli | Düşük: aynı chart portu gerekir | Güçlü supply-chain seçeneği: Sigstore, SBOM ve provenance sunar; lisans/erişim satın alma sürecinde incelenmeli. |
| Confluent `cp-kafka` | Confluent Platform | Resmi dokümantasyon Linux AMD64 ve ARM64 der | Evet | Düşük: farklı entrypoint/env ve ürün lisansı | Teknik aday; lisans ve ticari destek gereksinimi nedeniyle varsayılan seçim değil. |
| Strimzi | Apache-2.0; Kubernetes operator yaklaşımı | Seçilen Strimzi tag'i manifest ile doğrulanmalı | Evet | Drop-in değil; CRD/operator'a geçiş gerekir | Kubernetes işletimi için güçlü stratejik aday; mevcut Helm release'in yerine geçer. |
| Red Hat AMQ Streams | Red Hat destekli Strimzi dağıtımı | Destek matrisi/tag ile doğrulanmalı | Sürüme bağlı | Drop-in değil; operator'a geçiş gerekir | Red Hat aboneliği ve yaşam döngüsü uygun kurumlarda değerlendirilebilir. |
| Kurum içi ASF tabanlı imaj | Apache Kafka + Temurin/UBI/Chainguard base, kurum CI/CD'si | CI ile iki platformda yayınlanmalı | Evet | Yüksek, yalnızca port edilmiş chart ile | **Operasyonel tercih.** Tam kontrol, digest/SBOM/imza/CVE gate; bakımı kuruma aittir. |

## Yardımcı image kararları

| İş | Geçerli alternatif | Not |
| --- | --- | --- |
| Dosya sahipliği | `alpine:3.20.2` veya kurum minimal shell | Mevcut template `/bin/bash` çağırdığı için önce `sh` portu gerekir; mevcut haliyle Alpine drop-in değildir. |
| Kubernetes discovery | `registry.k8s.io/kubectl:v1.33.4` veya kurum `kubectl+shell` imajı | Manifestte `amd64`/`arm64` doğrulandı. Mevcut script bash kullandığından shell uyumluluğu test edilmelidir. Kubernetes sürüm skew politikası da kontrol edilmelidir. |
| JMX exporter | Kurum yapımı JMX Exporter imajı veya Java agent | Prometheus JMX Exporter projesi JAR release eder; bu chart'ın varsaydığı `quay.io/prometheus/jmx-exporter:1.0.1` tag'i yoktur. İmaj/JAR/komut sözleşmesi birlikte test edilmelidir. |

## Kaynaklar

- [ASF resmi Kafka Docker image](https://kafka.apache.org/40/getting-started/docker/)
- [Chainguard Kafka kullanım bilgisi](https://images.chainguard.dev/directory/image/kafka/overview) ve [provenance/SBOM](https://images.chainguard.dev/directory/image/kafka/provenance)
- [Confluent Linux AMD64/ARM64 desteği](https://docs.confluent.io/platform/current/installation/docker/installation.html)
- [Strimzi KRaft işletim modeli](https://strimzi.io/docs/operators/latest/deploying)
- [JMX Exporter proje/release bilgisi](https://github.com/prometheus/jmx_exporter)
