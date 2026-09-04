# Apache Kafka KRaft test chart 0.3.0

> 0.3.0 varsayılan davranışı 0.2.0 ile uyumludur ve secure özellikleri opt-in ekler. 0.1.0 kurulumları doğrudan upgrade edilemez; [kontrollü kurtarma rehberi](../../deploy/contabo/STORAGE-RECOVERY.md) gerekir. 0.2.0 PLAINTEXT profilinin canlı kalıcılık testi geçti; 0.3.0 secure profilinin canlı testi henüz yapılmadı.

Bağımsız chart; Bitnami helper, script, image veya dependency içermez. Eski Bitnami chart `legacy/bitnami-kafka` altında ayrı ve korunmuştur.

## Sözleşme

- Apache Kafka `4.0.2`, OCI index digest `sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f`; linux/amd64 ve linux/arm64. Registry manifest ve amd64 canlı runtime testleri geçti; arm64 canlı runtime ve zafiyet taraması yapılmadı.
- Varsayılan 3 birleşik broker/controller; static quorum. İlk kurulumda `replicaCount=1` ayrı küçük lab için desteklenir, sonradan 1↔3 dönüşümü desteklenmez. Helm upgrade mevcut replica sayısını kontrol eder; disk kimlik kaydı topoloji değişimini engeller.
- Yeni cluster için dışarıdan, aynı namespace'te `existingClusterIdSecret` adında Secret ve `cluster-id` anahtarı gerekir. 22 karakter base64url Kafka kimliği bütün node'larda aynıdır. Chart Secret üretmez ve her render'da kimlik değiştirmez.
- PVC doğrudan `/var/lib/kafka/data` üzerine mount edilir; Kafka log ve metadata dizini `/var/lib/kafka/data/kraft` olur. Apache imajındaki diğer iki VOLUME yolu (`/etc/kafka/secrets`, `/mnt/shared/config`) açık readonly emptyDir mount'larıyla kaplanır; kullanılmayan bu yollar için gizli containerd volume oluşmaz.
- Başlangıçta exact mount, container-local kaynak ve nested mount kontrolleri yapılır. Metadata varsa cluster/node/directory kontrolünden sonra format atlanır. Metadata'sız dolu dizin reddedilir; PVC kökündeki `.lab-volume-identity` mevcutsa metadata kaybında yeniden format yapılmaz. `--ignore-formatted` veya otomatik veri silme yoktur. Tüm PVC'nin silinmesi/değiştirilmesi bu yerel marker ile saptanamaz; bu yüzden PVC silmek yasaktır ve test PVC UID'sini de karşılaştırır.
- Helm canlı lookup eski layout'u ve değişen kimlik/storage sözleşmesini reddeder. Deploy scripti ayrıca mevcut pod/PVC/mount denetimini yapar. Bu kontroller yönetici müdahalesine karşı bir güvenlik sınırı değil, yanlışlıkla upgrade'e karşı korumadır; annotation elle değiştirilmemelidir.
- Varsayılan profil dış servis üretmez; cluster içi PLAINTEXT client:9092/controller:9093 kullanır.
- Secure profil `INTERNAL:9092=SASL_SSL`, `CONTROLLER:9093=SSL+clientAuth` ve isteğe bağlı `EXTERNAL:9094=SASL_SSL` üretir. Broker başına NodePort yalnız verilen CIDR'lere açılır; controller dışarı açılmaz. Host/Contabo firewall yine zorunludur.
- TLS ve SASL materyali dış Secret'lardan gelir; chart Secret üretmez. Minimum anahtar sözleşmesi `kafka.keystore.p12`, `kafka.truststore.p12`, üç password anahtarı, `server-jaas.conf` ve `admin.properties` dosyalarıdır.
- ACL etkinse `StandardAuthorizer` varsayılan reddetme uygular. Provisioning hook Job yalnız tanımlı topic/ACL'leri idempotent ekler; silme yapmaz.
- Metrics etkinse custom image içindeki doğrulanmış Prometheus JMX Exporter agent'ı 9404 portunda çalışır. ServiceMonitor/PrometheusRule hem seçenek hem ilgili CRD API mevcutsa render edilir.
- `extraConfig` quorum/listener/data/identity/authorizer anahtarlarını değiştiremez; `extraDeploy` yalnız namespace-safe allowlist kind'larını kabul eder.
- Non-root UID/GID/fsGroup 1000, read-only rootfs, kapalı token mount, writable data/config/tmp; startup TCP, readiness Kafka API, liveness TCP. TCP liveness tüm quorum sağlığını kanıtlamaz.
- RF=3/minISR=2 (tek pod için 1/1); auto topic creation kapalı. Varsayılan kaynaklar pod başına 250m CPU/768Mi request, 1 CPU/1536Mi limit, 512Mi heap. Yük/retention için tuning gerekir.
- Varsayılan K3s `local-path`, PVC başına 5Gi. PVC boyutu/storageClass StatefulSet üzerinde otomatik değiştirilemez. Veri yedeği ve kapasite izleme operatör sorumluluğudur.
- PDB maxUnavailable=1; tek sunucu arızasına karşı fiziksel yedeklilik sağlamaz.
- `minReadySeconds=30` rollout sırasında kısa bir readiness kararlılığı süresi sağlar; ISR senkronizasyonunu garanti etmez. PDB doğrudan pod silmeyi ve StatefulSet rolling update'i durdurmaz.

## Kurulum ve kontroller

Tam manuel Ubuntu akışı: [Contabo rehberi](../../deploy/contabo/README.md). GitHub otomasyonu yoktur.

Sadece offline render:

```bash
helm lint lab/kafka-apache --strict
helm template kafka-lab lab/kafka-apache -n kafka-lab
bash scripts/validate.sh
```

Secure profil render testi için örnek digest placeholder'ını yalnız test sırasında geçerli 64 hex ile override edin:

```bash
helm template kafka-secure lab/kafka-apache -n kafka-secure \
  -f deploy/contabo/secure-values.yaml.example \
  --set image.digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

`validate.sh` için Bash, Helm, Python 3 ve PyYAML gerekir. Ubuntu bootstrap bunları kurar; diğer test makinelerinde `python3 -m pip install -r tests/requirements.txt` kullanın (gerekirse venv). Testler fake Kafka araçlarıyla format korumalarını doğrular; image veya Kubernetes çalıştırmaz.

HPA/VPA, ayrı broker/controller StatefulSet'leri, dış IP auto-discovery, cert-manager, Prometheus/Grafana kurulumu ve production migration kapsam dışıdır. Eski Bitnami values yeni chart ile uyumlu değildir. [İşlem/test raporu](../../IMPLEMENTATION-REPORT.md).

Kaynak: [Apache Kafka KRaft operasyonları](https://kafka.apache.org/40/operations/kraft/).
