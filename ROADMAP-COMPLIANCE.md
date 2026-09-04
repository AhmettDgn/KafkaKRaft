# Staj hafta 1 — gereksinim ve teslim matrisi

Tarih: 2026-08-31. Kaynak: kullanıcının “A Stajyeri 2. Staj - Hafta 1 Roadmap” dokümanı.
Repository: [AhmettDgn/KafkaKRaft](https://github.com/AhmettDgn/KafkaKRaft).
Araştırma girişi: [README](kafka-kraft-bitnami-image-research/README.md).

## Kapsam kararı

İstenen ana çıktı araştırma + values override denemesi + deploy/test denemesi + teknik öneridir. Roadmap'in son maddesi, deploy başarısızsa teknik sebep ve uygulanabilir sonraki adımı yeterli kabul eder. Bu nedenle hatalı restart sonucu saklanmadı; çalışan eski demo ile henüz canlı doğrulanmamış düzeltme ayrıldı. Yeni chart, eski Bitnami chart'ın bütün production özelliklerini taşımakla eşdeğer değildir.

## Günlük teslim eşleştirmesi

| Gün / gereksinim | Durum | Dosya / kanıt |
| --- | --- | --- |
| 1 — KRaft, ZooKeeper farkı, broker/controller | Hazır | [Mimari açıklama ve repo ağacı](kafka-kraft-bitnami-image-research/chart-analysis/kraft-architecture.md) |
| 1 — Broker/controller/init/helper/metrics image envanteri | Hazır | [Image bağımlılıkları](kafka-kraft-bitnami-image-research/chart-analysis/image-dependencies.md) |
| 1 — Bitnami kullanım noktaları | Hazır | [Template/path/env bağımlılıkları](kafka-kraft-bitnami-image-research/chart-analysis/bitnami-usage-points.md) |
| 1 — Klasör yapısı görüntüsü veya komut çıktısı | Komut ve kaynak ağaç özeti var | [Mimari belgesi](kafka-kraft-bitnami-image-research/chart-analysis/kraft-architecture.md) |
| 2 — En az dört alternatif, lisans/yayıncı/KRaft/StatefulSet/uyumluluk | Hazır; beş yayıncı alternatifi + custom/DOI incelendi | [Karşılaştırma](kafka-kraft-bitnami-image-research/alternatives/image-comparison.md) |
| 2 — amd64/arm64 kontrolü | Apache, Confluent, Strimzi manifestleri doğrulandı; diğerlerinin belirsizlikleri açık | [Digest/erişim kanıtı](kafka-kraft-bitnami-image-research/alternatives/manifest-evidence.md) |
| 2 — Güncelleme ve CVE/security değerlendirmesi | Değerlendirme hazır; gerçek scanner/SBOM/imza testi yapılmadı | [Güvenlik değerlendirmesi](kafka-kraft-bitnami-image-research/alternatives/security-evaluation.md) |
| 3 — Orijinal ve alternatif values | Hazır; dosyaların hedef chart'ları ayrıldı | [Değişiklik notları](kafka-kraft-bitnami-image-research/helm-values/diff-notes.md) |
| 3 — command/args/env/securityContext/volume değişiklikleri | Hazır; salt override'ın yetersizliği açık | [Diff](kafka-kraft-bitnami-image-research/helm-values/diff-notes.md), [chart denetimi](CHART-AUDIT.md) |
| 3 — Helm template denemesi | İki chart için offline kontrol; runtime kanıtı değil | [Render notu](kafka-kraft-bitnami-image-research/tests/helm-template-output.md), [otomatik regresyon](tests/test_roadmap.py) |
| 4 — Deploy, Pod/StatefulSet/Service, quorum | 0.2.0 temiz deploy, üç-pod PVC/metadata, quorum ve mesaj testi GEÇTİ | [Deploy notları](kafka-kraft-bitnami-image-research/tests/deploy-notes.md) |
| 4 — Topic, producer, consumer, yönetim | 0.2.0 üzerinde GEÇTİ; RF=3/minISR=2, sıralı mesaj eşleşmesi ve 1→3 partition | [Mesajlaşma](kafka-kraft-bitnami-image-research/tests/producer-consumer-test.md), [topic](kafka-kraft-bitnami-image-research/tests/topic-management-test.md) |
| 4 — Restart/rolling davranışının gözlemi | 0.1.0 BAŞARISIZ; 0.2.0 pod replacement + aynı PVC/metadata + eski/yeni mesaj kabulü GEÇTİ | [Deploy notları](kafka-kraft-bitnami-image-research/tests/deploy-notes.md) |
| 4/5 — Gerçek ekran görüntüleri | Tamamlandı; beş gerçek terminal PNG'si | [Görsel kanıtlar](kafka-kraft-bitnami-image-research/screenshots/README.md) |
| 5 — README, karar, sonuç, kısa demo notu | Hazır | [Final README](kafka-kraft-bitnami-image-research/README.md), [seçim](kafka-kraft-bitnami-image-research/alternatives/selected-image-decision.md), [demo](kafka-kraft-bitnami-image-research/DEMO-NOTES.md) |

## Mentor kontrol listesi

- [x] Tüm dört image ailesi ve runtime/provisioning kullanımı belgelendi.
- [x] Bitnami script, env ve mount bağımlılıkları listelendi.
- [x] En az dört alternatif araştırıldı; lisans ve ticari erişim ayrıldı.
- [x] amd64/arm64 kontrolü yapıldı; erişilemeyen adaylar doğrulanmış sayılmadı.
- [x] Güncelleme ve CVE yaklaşımı değerlendirildi; güvenlik onayı verilmedi.
- [x] KRaft/StatefulSet ve entrypoint uyumu incelendi.
- [x] Values override deneyi ve Helm render testi mevcut.
- [x] Gerçek deploy denemesi, topic ve producer/consumer çıktıları kaydedildi.
- [x] Çalışmayan restart'ın teknik nedeni ve sonraki adım açıklandı.
- [x] Sonuç ve öneri yazıldı.
- [x] Gün 4/5'in gerçek ekran görüntüleri teslim edildi.
- [x] İdeal çalışan demo için 0.2.0 canlı kalıcılık kabul testi geçti.

İşaretli maddeler yalnız açıklanan laboratuvar/roadmap kapsamını ifade eder. “Restart gözlemi yapıldı” ile “restart başarılı” ayrımı gerçek 0.2.0 kabul kanıtıyla kapatıldı. Mentor kontrol listesindeki bütün haftalık maddeler tamamlandı; bu production onayı değildir.

## Roadmap sonrası güvenli genişletme

Chart 0.3.0, roadmap'in zorunlu minimumunun üzerine çıkarak Bitnami'deki koşullu image kullanım alanlarının karşılıklarını ekler: resmi Apache tabanlı custom JMX agent image, TLS/SASL/ACL listener'ları, broker başına dış Service, provisioning Job ve Prometheus kaynakları. Varsayılan 0.2 davranışı korunur. Bu genişletme offline lint/render/mock testlerinden geçmiştir; multi-arch image push, CVE taraması ve `kafka-secure` canlı deploy henüz roadmap'in daha önce tamamlanmış 0.2.0 kanıtı yerine gösterilmez.

## Sonraki güvenli adım ve yetki sınırı

Sunucuda çalışan release, deploy kaynağı `0c0c5ce0acfc570c793035846c6f0254b52dfd5d` / chart 0.2.0 / Helm revision 1'dir. Ardından kaynak `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c` içindeki aynı smoke/storage koduyla pod 0 replacement ve kalıcılık kabulü geçmiştir. İki SHA arasında chart/deploy/storage/smoke kod farkı yoktur.

Eski 0.1.0 test verilerinin silinmesi kullanıcı tarafından açıkça onaylandı; kontrollü sıfırlama tamamlandı. GitHub otomasyonu yoktur; kaynak push'u sunucuda işlem tetiklemez.

Tam işlem, hata, test ve commit kayıtları [IMPLEMENTATION-REPORT.md](IMPLEMENTATION-REPORT.md) içindedir.
