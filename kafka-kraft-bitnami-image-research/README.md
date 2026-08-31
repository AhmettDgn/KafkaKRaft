# Kafka KRaft / Bitnami image araştırması — final çalışma dosyaları

Tarih: 2026-08-31. İkinci staj, hafta 1 (genel program hafta 5).
Repository: [AhmettDgn/KafkaKRaft](https://github.com/AhmettDgn/KafkaKRaft).
Madde bazında teslim durumu: [ROADMAP-COMPLIANCE.md](../ROADMAP-COMPLIANCE.md).

## Araştırma sorusunun cevabı

Apache Kafka image'ı ile Bitnami'den bağımsız KRaft demo kurulabilir; yalnız image repository/tag değiştirmek mevcut chart'ın Bitnami script/entrypoint/path bağımlılıklarını kaldırmaz. Bu nedenle kökteki orijinal chart korundu, [lab/kafka-apache](../lab/kafka-apache) bağımsız chart'ı geliştirildi. Seçim Apache Kafka 4.0.2'nin digest ile sabitlenmiş ASF image'ıdır; kurum image'ı henüz build edilmedi.

Sunucudaki 0.1.0 denemesinde deploy ve mesajlaşma geçti; restart ise image VOLUME alt mount'u PVC'yi örttüğü için başarısız oldu. Kullanıcının eski test verilerini silme onayından sonra temiz 0.2.0 deploy edildi: üç yeni PVC doğrudan `/var/lib/kafka/data` yolunda. Pod 0 replacement sonrasında üç PVC/PV kaynağı ve Kafka kimlikleri değişmedi; eski üç mesaj okundu ve yeni dördüncü mesaj yazılıp okundu. 0.2.0 kalıcılık kabulü geçti.

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
- Eski 0.1.0'daki üç broker'ın tehlikeli mount düzeni teyit edildi; bu test verileri açık onayla sıfırlandı. Yeni 0.2.0 exact PVC mount audit'i geçti.
- Roadmap, eski başarısız denemenin teknik açıklamasını korur; 0.2.0 restart kalıcılığı gerçek sunucuda PASS olmuştur.
- amd64/arm64 manifest kontrolü çalışma testi değildir. İki mimaride canlı test, CVE scanner, SBOM/imza doğrulaması yapılmadı.
- Gerçek ekran görüntüleri henüz sağlanmadı; terminal metni ekran görüntüsü gibi etiketlenmedi.
- GitHub otomasyonu yoktur. Üç pod tek fiziksel sunucudadır; production HA, TLS/SASL, JMX ve dış erişim kapsam dışıdır.
- Eski veriler taşınmadı; kullanıcı disposable test verilerinin silinmesini onayladı. Fiziksel secure erase veya geri yükleme garantisi verilmedi. [Geçiş kaydı](../IMPLEMENTATION-REPORT.md).

Teknik demo hedefi tamamlandı. Kalan teslim kalemi gerçek ekran görüntüleridir. Production için TLS/SASL, dış erişim, JMX, zafiyet/SBOM/imza, yük/uzun süre ve fiziksel host arızası testleri ayrı kapsamdır.
