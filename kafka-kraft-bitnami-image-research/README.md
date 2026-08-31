# Kafka KRaft / Bitnami image araştırması — final çalışma dosyaları

Tarih: 2026-08-31. İkinci staj, hafta 1 (genel program hafta 5).
Repository: [AhmettDgn/KafkaKRaft](https://github.com/AhmettDgn/KafkaKRaft).
Madde bazında teslim durumu: [ROADMAP-COMPLIANCE.md](../ROADMAP-COMPLIANCE.md).

## Araştırma sorusunun cevabı

Apache Kafka image'ı ile Bitnami'den bağımsız KRaft demo kurulabilir; yalnız image repository/tag değiştirmek mevcut chart'ın Bitnami script/entrypoint/path bağımlılıklarını kaldırmaz. Bu nedenle kökteki orijinal chart korundu, [lab/kafka-apache](../lab/kafka-apache) bağımsız chart'ı geliştirildi. Seçim Apache Kafka 4.0.2'nin digest ile sabitlenmiş ASF image'ıdır; kurum image'ı henüz build edilmedi.

Sunucudaki 0.1.0 denemesinde deploy, quorum, topic, producer/consumer ve partition artırma geçti. Restart testi başarısız oldu: image VOLUME alt mount'u PVC'yi örttüğü için pod verisi gerçek PVC'de değildi. Bu, yalnız render/Running kontrolünün yeterli olmadığını gösteren somut bulgudur. Düzeltme 0.2.0 kodunda var, offline testleri geçti; yeni sürümün canlı kalıcılık testi henüz yapılmadı.

## Teslim dosyaları

| Gün | Dosyalar / kanıt |
| --- | --- |
| 1 — Mimari ve envanter | [KRaft ve repo yapısı](chart-analysis/kraft-architecture.md), [image bağımlılıkları](chart-analysis/image-dependencies.md), [Bitnami kullanım noktaları](chart-analysis/bitnami-usage-points.md) |
| 2 — Alternatifler | [Karşılaştırma](alternatives/image-comparison.md), [manifest/multiarch kanıtı](alternatives/manifest-evidence.md), [CVE ve güncelleme değerlendirmesi](alternatives/security-evaluation.md), [seçim kararı](alternatives/selected-image-decision.md) |
| 3 — Values / render | [Orijinal değer özeti](helm-values/original-values.yaml), [yalnız image override deneyi](helm-values/image-only-override.yaml), [yeni chart değerleri](helm-values/non-bitnami-values.yaml), [değişiklik gerekçeleri](helm-values/diff-notes.md), [render sonuçları](tests/helm-template-output.md) |
| 4 — Gerçek deneme | [Deploy/restart](tests/deploy-notes.md), [producer/consumer](tests/producer-consumer-test.md), [topic yönetimi](tests/topic-management-test.md), [ekran görüntüsü teslim listesi](screenshots/README.md) |
| 5 — Sonuç ve sunum | Bu README, [karar](alternatives/selected-image-decision.md), [demo notları](DEMO-NOTES.md), [işlem raporu](../IMPLEMENTATION-REPORT.md), [chart denetimi](../CHART-AUDIT.md) |

## Tekrarlanabilir offline doğrulama

Repository kökünden, Helm ve Python/PyYAML bulunan ortamda:

```bash
bash scripts/validate.sh
helm lint lab/kafka-apache --strict -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
helm template kafka-lab lab/kafka-apache -n kafka-lab -f kafka-kraft-bitnami-image-research/helm-values/non-bitnami-values.yaml
```

Values dosyaları birbirinin yerine kullanılmaz: image-only-override kökteki Bitnami chart için negatif uyumluluk deneyidir; non-bitnami-values yalnız yeni bağımsız chart içindir. Ayrıntılar [diff-notes](helm-values/diff-notes.md).

## Sonuçların sınırları

- Gerçek sunucu kanıtı kullanıcı tarafından paylaşılan terminal çıktılarıdır; bu çalışma ortamından SSH ile doğrulama yapılmadı.
- Mevcut sunucuda üç broker'ın da eski tehlikeli mount düzeninde olduğu --inspect ile teyit edildi. Kaynak pull işlemi çalışan release'i güncellemez.
- Roadmap, başarısız denemenin teknik açıklamasını ve uygulanabilir sonraki adımı kabul eder. Kalıcılık testi PASS olarak sunulamaz.
- amd64/arm64 manifest kontrolü çalışma testi değildir. İki mimaride canlı test, CVE scanner, SBOM/imza doğrulaması yapılmadı.
- Gerçek ekran görüntüleri henüz sağlanmadı; terminal metni ekran görüntüsü gibi etiketlenmedi.
- GitHub otomasyonu yoktur. Üç pod tek fiziksel sunucudadır; production HA, TLS/SASL, JMX ve dış erişim kapsam dışıdır.
- Eski verilerin korunması/silinmesi kararı verilmeden upgrade, restart, PVC silme veya veri taşıma yapılmamalı. [Güvenli geçiş koşulları](../deploy/contabo/STORAGE-RECOVERY.md).

Sonraki teknik adım: veri koruma kararı ve uygun yedek/ayrı test ortamı onayı ardından 0.2.0'ı canlı doğrulamak; exact PVC mount, sabit cluster/node/directory kimlikleri, restart sonrası eski mesaj okuma ve yeni mesaj yazma kanıtını eklemek.
