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
| 4 — Deploy, Pod/StatefulSet/Service, quorum | 0.1.0 denemesi GEÇTİ; kullanıcı terminal kanıtı | [Deploy notları](kafka-kraft-bitnami-image-research/tests/deploy-notes.md) |
| 4 — Topic, producer, consumer, yönetim | 0.1.0 denemesinde GEÇTİ; create/describe ve 1→3 partition | [Mesajlaşma](kafka-kraft-bitnami-image-research/tests/producer-consumer-test.md), [topic](kafka-kraft-bitnami-image-research/tests/topic-management-test.md) |
| 4 — Restart/rolling davranışının gözlemi | Denendi ve BAŞARISIZ; tüm üç pod'da PVC shadow mount bulundu | [Başarısızlığın kanıtı](kafka-kraft-bitnami-image-research/tests/deploy-notes.md), [recovery koşulları](deploy/contabo/STORAGE-RECOVERY.md) |
| 4/5 — Gerçek ekran görüntüleri | EKSİK; terminal metni var, gerçek görüntü yok | [İstenen görüntüler](kafka-kraft-bitnami-image-research/screenshots/README.md) |
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
- [ ] Gün 4/5'in gerçek ekran görüntüleri teslim edildi.
- [ ] İdeal çalışan demo için 0.2.0 canlı kalıcılık kabul testi geçti.

İşaretli maddeler yalnız açıklanan kapsamı ifade eder. “Restart gözlemi yapıldı” ile “restart başarılı” farklıdır. Dokümandaki başarısızlık analizi yolu karşılandı; eksik ekran görüntüleri nedeniyle tüm teslim kalemleri %100 tamamlandı denemez.

## Sonraki güvenli adım ve yetki sınırı

Sunucuda son bildirilen çalışan kaynak 0747716 / chart 0.1.0 / Helm revision 1'dir. Kullanıcının git pull ile 0c0c5ce'ye güncellediği checkout, çalışan Helm release revision'ı değildir. Yeni 0.2.0'ın deploy/restart testi henüz yoktur.

Önce mevcut verilerin korunma gereksinimi ve yedek/ayrı test ortamı kararı netleşmeli. Bu onay olmadan PVC/namespace/cluster-ID silinmez, legacy upgrade guard kaldırılmaz ve pod'lar yeniden başlatılmaz. GitHub otomasyonu istenmediğinden yoktur; kaynak push'u sunucuda işlem tetiklemez.

Tam işlem, hata, test ve commit kayıtları [IMPLEMENTATION-REPORT.md](IMPLEMENTATION-REPORT.md) içindedir.
