# ADR-001: Apache Kafka image + bağımsız laboratuvar chart'ı

## Güncel karar — 2026-08-31

Demo için `docker.io/apache/kafka:4.0.2@sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f` seçildi. Gerçek chart `lab/kafka-apache`; sürüm 0.2.0. Kurum registry'sinde custom image build edildiği, tüm Bitnami özelliklerinin port edildiği veya production onayı verildiği iddia edilmiyor.

## Gerekçe

- ASF kaynak/yayıncı kimliği ve Kafka çekirdeğinin Apache-2.0 lisansı açık; seçilen digest'in amd64/arm64 manifestleri doğrulandı.
- Gerçek 0.1.0 Contabo denemesi KRaft quorum, topic, producer/consumer ve partition artırma işlemlerinin çalışabildiğini gösterdi.
- Eski chart'ın prepare-config init container'ı Bitnami shell API'sine bağlı: yalnız image override yeterli değil. Yerel helper ve config/start scriptleri olan ayrı chart gerekir.
- Confluent teknik alternatif; ek dağıtım sözleşmesini/dosya yollarını incelemek gerekir. cp-kafka'yı bütün Confluent ürünleriyle aynı lisans kategorisinde varsaymıyoruz.
- Strimzi/Red Hat operator yaklaşımı ayrı platform kararıdır; mevcut Helm chart'a drop-in replacement değildir.
- Chainguard supply-chain açısından incelendi fakat bu ortamda registry erişimi doğrulanamadı. Custom build bakım/supply-chain sorumluluğunu kuruma taşır; bu haftanın uygulanmış çıktısı değildir.

## Çalıştı / çalışmadı

| Aşama | Sonuç |
| --- | --- |
| Eski chart'a image-only override | Lint/render deneyi; Bitnami init/path bağları kaldığı için runtime uygun değil. Canlıya uygulanmadı |
| Bağımsız chart 0.1.0, kaynak 0747716 | Gerçek deploy, quorum ve mesaj testi başarılı (kullanıcı logları) |
| 0.1.0 restart kalıcılığı | **Başarısız**; containerd image child volume PVC'yi örttü, yeni pod format attı |
| Bağımsız chart 0.2.0 düzeltmesi | Gerçek temiz deploy, exact PVC/metadata audit, mesajlaşma ve pod replacement kalıcılık testi başarılı |
| CVE/SBOM/imza güvenlik onayı | Verilmedi; değerlendirme ve kabul planı var |
| Production migration | Yapılmadı; ayrı kapsam |

## Haftanın sorusuna cevap

**Bitnami'den bağımsız KRaft demo uygulanabilir; yalnız values değişikliği yeterli değildir.** Apache image + bağımsız chart yaklaşımı gerçek deploy, mesaj ve pod replacement sonrası kalıcılık seviyesinde gösterildi. Eski çakışma ve doğrulanmış düzeltme [denetim raporunda](../../CHART-AUDIT.md) belgeli.

Roadmap, başarısız deploy/test alanlarının teknik sebebi ve sonraki adımı açıklandığında bunu geçerli araştırma çıktısı sayıyor. Bu koşul, başarısız restart'ı PASS yazmayı veya production hazır ilan etmeyi gerektirmez.

## Sonraki adım ve sınırlar

Eski veriler, kullanıcı tarafından disposable olduğu açıkça onaylandıktan sonra kontrollü temiz kurulumla sıfırlandı; veri taşıması yapılmadı. 0.2.0 mount/kimlik/restart testi tamamlandı. Gelecekte gerçek veri taşıması gerekiyorsa [kontrollü storage recovery](../../deploy/contabo/STORAGE-RECOVERY.md) şartları yeniden geçerlidir.

TLS/SASL/JMX/dış erişim ve production taşıması haftalık demo kapsamı dışında. GitHub otomasyonu kullanıcı isteğiyle yok. Sürüm/digest güncellemeleri CVE değerlendirmesi ve tekrar test gerektirir; 4.0.2'nin en güncel/ömür boyu güvenli sürüm olduğu iddia edilmez.
