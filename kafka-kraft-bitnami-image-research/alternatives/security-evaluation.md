# Güvenlik, CVE ve güncellik değerlendirmesi

## Değerlendirme sonucu

**Hiçbir image için “CVE yok / güvenlik onaylı” denmiyor.** OCI manifest mimari/erişim kanıtıdır; Helm lint veya Kafka mesajlaşması zafiyet taraması değildir. Bu teslimde gerçek image vulnerability scan, SBOM üretimi veya container imzası doğrulaması çalıştırılmadı. Roadmap'in güvenlik yaklaşımı değerlendirmesi aşağıdadır; production release gate henüz tamamlanmadı.

| Aday | Yayıncı yaklaşımı / güncelleme | Bu çalışmanın doğruladığı | Kalan kontrol |
| --- | --- | --- | --- |
| Apache Kafka | ASF security advisories ve Kafka release düzeltmeleri | Resmi CVE listesi incelendi; örneğin CVE-2026-35554 için 4.0.2 düzeltme sürümleri arasında listeleniyor | Aynı digest'in amd64/arm64 OS/JRE/JAR taraması; image provenance/imza zinciri ayrıca doğrulanmalı |
| Confluent cp-kafka | Platform release ve security-support süreçleri; paket bileşenlerinin yaşam döngüsü | Yayıncı Docker/platform belgeleri, kaynak lisansı ve seçili tag mimarileri | Container paket listesi/lisansları, CVE raporu ve support/EOL kontrolü; cp-server ile karıştırılmamalı |
| Strimzi | Açık kaynak security reporting/advisory süreci; Kafka/operator sürümleri birlikte yönetilir | Proje security dokümanı ve seçili Kafka image manifesti | Seçili eski tag'in güncel advisories/EOL uygunluğu, image SBOM/CVE ve operator upgrade uyumu |
| Red Hat Streams / UBI | Ürün errata, destek matrisi ve Red Hat yaşam döngüsü | Ürün support matrisi; açık kaynak çekirdek ile ticari destek ayrımı | Somut image/tag/digest, abonelik/erişim, container health/advisories; UBI güncellemesi Kafka JAR açıklarını tek başına çözmez |
| Chainguard | Yayıncı günlük build, SBOM, Sigstore imzaları/provenance ve vulnerability/advisory görünürlüğü sunuyor | Yayıncı belgeleri; bu ortamda registry denemesi 403 | Erişim sonrası somut digest/SBOM/signature ve iki mimariyi doğrulama; pazarlama iddiası bağımsız test değildir |
| Kurum içi image | Build, base refresh, dependency ve CVE sorumluluğu kuruma geçer | Tasarım alternatifi olarak değerlendirildi; build yapılmadı | Tekrarlanabilir Dockerfile, iki mimari build, SBOM/imza ve düzeltme SLA'sı |

Kaynaklar: [Apache CVE listesi](https://kafka.apache.org/community/cve-list/), [Confluent Docker](https://docs.confluent.io/platform/current/installation/docker/installation.html), [Strimzi security](https://strimzi.io/security/), [Red Hat Streams ürün desteği](https://access.redhat.com/products/streams-apache-kafka/), [Chainguard provenance](https://images.chainguard.dev/directory/image/kafka/provenance).

## Somut güvenlik kabul planı (henüz çalıştırılmadı)

1. Scanner ve vulnerability DB sürüm/tarihini kaydedin; inceleme hedefi değişken tag değil sabit OCI index + platform digest'leri olsun.
2. Her iki mimaride OS, Java runtime ve Java dependency/JAR bulgularını tarayın; yalnız Kafka çekirdeğinin CVE sayfası yeterli değildir.
3. SBOM ve tam scanner çıktısını koruyun. HIGH/CRITICAL bulguları, fix availability ve exploitability ile triage edin; istisnalar gerekçe/sahip/son tarih içersin. Tarama olmadan “0 CVE” yazmayın.
4. Artifact imzası/provenance için yayıncı kimliği ve güven kökünü doğrulayın; Apache dağıtım arşivi imzası, container image imzası yerine geçmez.
5. Yeni digest'e geçmeden önce render, runtime mount, topic/mesaj ve restart testlerini tekrarlayın. Bu aşama manuel olabilir; kullanıcı isteği gereği GitHub Actions yoktur.

Kafka 4.0.2 burada test edilen ve digest'i sabitlenen demo sürümüdür; “en son sürüm” veya kurum için uzun dönem destek kararı değildir. CVE düzeltme örneği bütün image'ın güvenli olduğunu kanıtlamaz. Mevcut PLAINTEXT/tek-host demo TLS/SASL veya production güvenlik şartlarını karşılamaz.
