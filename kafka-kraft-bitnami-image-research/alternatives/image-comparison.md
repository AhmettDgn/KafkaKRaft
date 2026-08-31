# Alternatif image karşılaştırması

İnceleme: 2026-08-31. Kapsam: en az dört aday; burada beş yayıncı alternatifi, custom build ve Docker Official Images olasılığı değerlendirilmiştir. Bir image'ın KRaft desteklemesi mevcut Bitnami chart'a doğrudan uyduğu anlamına gelmez.

## Roadmap karşılaştırma tablosu

| Image adayı | Kaynak / lisans | Açık kaynak | amd64 | arm64 | Güncelleme desteği | Güvenlik yaklaşımı | KRaft | Mevcut Helm chart uyumu | Sonuç |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bitnami Kafka (baz) | Bitnami/Broadcom; Kafka Apache-2.0 | Kafka evet; image dağıtım/erişim koşulları ayrıca incelenmeli | Bu tur manifest kontrol edilmedi | Bu tur manifest kontrol edilmedi | Tag/erişim/ürün yaşam döngüsü bağımlılığı | Seçili eski image taranmadı | Mevcut template destekliyor | Kendi script sözleşmesine uygun | Mevcut bağımlılık; hedef değil |
| Apache Kafka 4.0.2 | ASF; Apache-2.0 | Evet | Manifest doğrulandı | Manifest doğrulandı | ASF sürümleri ve CVE duyuruları | Yayıncı advisories; ayrıca OS/JRE/JAR taraması gerekli | Evet; sunucuda denendi | Yalnız image override yetersiz | Bağımsız demo chart için seçildi |
| Confluent cp-kafka 8.2.0 | Confluent; kafka-images kaynak deposu Apache-2.0 | Kaynak repo evet; image bileşenleri ayrıca incelenmeli | Manifest doğrulandı | Manifest doğrulandı (v8) | Confluent Platform sürüm/yaşam döngüsü | Yayıncı güvenlik güncellemeleri; bu digest taranmadı | Evet; bu çalışmada runtime testi yok | Farklı entrypoint/env/path; template portu gerekir | Teknik alternatif; ASF ile aynı dağıtım değil |
| Strimzi 0.47.0-kafka-4.0.0 | Strimzi; Apache-2.0; UBI tabanı | Evet | Manifest doğrulandı | Manifest doğrulandı | Operator/Kafka uyumluluk matrisiyle sürümlenir | Security policy ve duyurular; seçilen eski tag güvenli kabul edilmedi | Evet; bu çalışmada runtime testi yok | Drop-in değil; operator veya özel template uyarlaması | Kubernetes işletimi için alternatif mimari |
| Red Hat Streams / UBI | Red Hat, Kafka/Strimzi açık kaynak bileşenleri; abonelik koşulları ayrı | Bileşenler evet; UBI tek başına Kafka değildir | Ürün matrisi; belirli tag doğrulanmadı | Ürün matrisi aarch64; belirli tag doğrulanmadı | Ürün destek yaşam döngüsü | Red Hat errata/CVE süreci; yerel scan yok | Seçilen ürün sürümü/modu kontrol edilmeli | Desteklenen operator/OpenShift yaklaşımı; K3s drop-in değil | Kurumsal destek isteyen ortamlar için aday |
| Chainguard Kafka | Chainguard; açık kaynak bileşenler, dağıtım erişimi ayrı | Bileşenler evet; erişim/lisans koşulları ayrı | Bu denemede doğrulanamadı | Bu denemede doğrulanamadı | Yayıncı sürekli rebuild yaklaşımı | Yayıncı SBOM/Sigstore/provenance; bu digest doğrulanmadı | Yayıncı belgesinde destekli | Apache benzeri entrypoint olsa da Bitnami scriptleri yok | Yetkili registry erişimi sonrası değerlendirilebilir |
| Custom ASF + UBI/Java image | Kurum build'i; bileşen lisansları korunur | Seçilen bileşenlere bağlı | Build/test edilmedi | Build/test edilmedi | Tüm rebuild/JRE/Kafka takibi kuruma ait | SBOM, imza, CVE ve güncelleme sorumluluğu kurumda | ASF konfigürasyonuyla mümkün | Port edilmiş chart ile; otomatik uyum yok | Kontrol yüksek, bakım maliyeti yüksek; bu çalışmada üretilmedi |
| Docker Official Image | Docker Official Images kataloğu | Kafka girdisi bulunmadı | Uygulanamaz | Uygulanamaz | Uygulanamaz | Uygulanamaz | Uygulanamaz | Uygulanamaz | Ayrı library/kafka adayı yok; ASF resmî imajıyla karıştırılmamalı |

Digest, tarih ve erişim sonuçları: [manifest kanıtı](manifest-evidence.md).
CVE, güncellik ve lisans sınırları: [güvenlik değerlendirmesi](security-evaluation.md).
Bu tablo adayların tümünde gerçek deploy veya güvenlik taraması yapıldığı anlamına gelmez.

## StatefulSet, entrypoint ve parametre uyumu

| Aday | StatefulSet uygunluğu | command / args / env / depolama ihtiyacı |
| --- | --- | --- |
| Apache | Sabit broker kimliği, DNS ve PVC ile uygun; eski demo çalıştı ancak kalıcılık testi başarısız | Yeni chart doğrudan /opt/kafka/bin araçlarını ve server.properties kullanır. Bitnami KAFKA_CFG_* kaldırılır; image VOLUME yolları açık mount edilir |
| Confluent | Uygun tasarlanabilir; burada doğrulanmadı | Confluent entrypoint ve KAFKA_* yapılandırması, UID/path sözleşmesi uyarlanmalı; Bitnami bash kütüphaneleri varsayılamaz |
| Strimzi | Kubernetes için tasarlanmış; operator sürümüne göre workload yönetimi değişir | En uygun kullanım desteklenen operator/CR yaklaşımı; imajı elle kullanmak script/config/sertifika/UID portu gerektirir |
| Red Hat / UBI | Desteklenen ürün platformunda; K3s uygunluğu ayrıca doğrulanmalı | Ürün operator sözleşmesi veya custom build gerektirir; yalın UBI base Kafka binary içermez |
| Chainguard | Yayıncı StatefulSet örneği sunuyor; burada çalıştırılmadı | Apache benzeri KAFKA_* entrypoint; Bitnami yolları yine değişmeli; izinler/mountlar seçilen tag'de kontrol edilmeli |
| Custom | Tasarlanabilir; çalışan artifact yok | Entry point, config, kullanıcı, PVC, probes ve image VOLUME sözleşmesi kurum tarafından tanımlanır |

## Helper/init/metrics karşılıkları

Envanter yalnız broker ile sınırlı değildir: [tüm kullanım noktaları](../chart-analysis/image-dependencies.md).

| Mevcut iş / image | Alternatif yaklaşım | Bu teslimde durum |
| --- | --- | --- |
| prepare-config / bitnami/kafka | Bağımsız start script + ConfigMap | Yeni lab chart'ta uygulandı; Bitnami libkafka yok |
| volume-permissions / bitnami/os-shell | fsGroup destekli volume veya doğrulanmış shell imajı | Lab UID/GID 1000 ve fsGroup kullanır; ayrı izin init image'ı yok. Alpine'e salt image override /bin/bash uyumsuzluğu yaratabilir |
| auto-discovery / bitnami/kubectl | Kubernetes kubectl dağıtımı + uyumlu shell; RBAC/sürüm skew kontrolü | Lab dış erişim kullanmaz; image ve discovery yok. Asıl chart özelliğinin port edildiği iddia edilmez |
| provisioning / bitnami/kafka | Apache CLI ile manuel topic testleri | Lab smoke scripti aynı Kafka image'ında exec kullanır; eski hook Job port edilmedi |
| JMX / bitnami/jmx-exporter | Doğrulanmış JMX Exporter JAR'ı + Java agent veya kurum image'ı | Lab kapsamı dışında; hayalî registry/tag veya doğrulanmamış image önerilmedi |

Bu dar demo, asıl chart'ın TLS/SASL/JMX/external-access özelliklerinin eksiksiz portu değildir. Haftalık araştırma ve deploy denemesi için seçilen uygulanabilir kapsam budur.

## Birincil kaynaklar

- [ASF Docker kullanımı](https://kafka.apache.org/40/getting-started/docker/) ve [CVE listesi](https://kafka.apache.org/community/cve-list/).
- [Confluent Docker](https://docs.confluent.io/platform/current/installation/docker/installation.html) ve [kafka-images lisansı](https://github.com/confluentinc/kafka-images/blob/master/LICENSE). Bu lisans tüm Confluent ürünlerinin lisansı olarak genellenmez.
- [Strimzi işletim belgeleri](https://strimzi.io/docs/operators/latest/deploying), [security policy](https://strimzi.io/security/) ve [UBI tabanı](https://github.com/strimzi/strimzi-kafka-operator/blob/main/docker-images/base/Dockerfile). Güncel operator belgesi eski örnek tag'in destek taahhüdü değildir.
- [Red Hat 2.7 ürün mimari matrisi](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/2.7/html/release_notes_for_streams_for_apache_kafka_2.7_on_openshift/ref-supported-configurations-str) ve [ürün sayfası](https://access.redhat.com/products/streams-apache-kafka/). Matris bilgisi tag manifesti değildir.
- [Chainguard kullanım](https://images.chainguard.dev/directory/image/kafka/overview) ve [provenance](https://images.chainguard.dev/directory/image/kafka/provenance).
- [Docker Official Images kataloğu](https://github.com/docker-library/official-images/tree/master/library), [JMX Exporter projesi](https://github.com/prometheus/jmx_exporter).
