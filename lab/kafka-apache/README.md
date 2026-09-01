# Apache Kafka KRaft test chart

> Sürüm 0.2.0 kalıcılık düzeltmesi içerir. 0.1.0 kurulumları doğrudan upgrade edilemez; [kontrollü kurtarma rehberi](../../deploy/contabo/STORAGE-RECOVERY.md) gerekir. Temiz 0.2.0 deploy, exact PVC audit ve pod replacement sonrası kalıcılık testi gerçek sunucuda geçti.

Bağımsız chart; Bitnami helper, script, image veya dependency içermez. Eski Bitnami chart `legacy/bitnami-kafka` altında ayrı ve korunmuştur.

## Sözleşme

- Apache Kafka `4.0.2`, OCI index digest `sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f`; linux/amd64 ve linux/arm64. Registry manifest ve amd64 canlı runtime testleri geçti; arm64 canlı runtime ve zafiyet taraması yapılmadı.
- Varsayılan 3 birleşik broker/controller; static quorum. İlk kurulumda `replicaCount=1` ayrı küçük lab için desteklenir, sonradan 1↔3 dönüşümü desteklenmez. Helm upgrade mevcut replica sayısını kontrol eder; disk kimlik kaydı topoloji değişimini engeller.
- Yeni cluster için dışarıdan, aynı namespace'te `existingClusterIdSecret` adında Secret ve `cluster-id` anahtarı gerekir. 22 karakter base64url Kafka kimliği bütün node'larda aynıdır. Chart Secret üretmez ve her render'da kimlik değiştirmez.
- PVC doğrudan `/var/lib/kafka/data` üzerine mount edilir; Kafka log ve metadata dizini `/var/lib/kafka/data/kraft` olur. Apache imajındaki diğer iki VOLUME yolu (`/etc/kafka/secrets`, `/mnt/shared/config`) açık readonly emptyDir mount'larıyla kaplanır; kullanılmayan bu yollar için gizli containerd volume oluşmaz.
- Başlangıçta exact mount, container-local kaynak ve nested mount kontrolleri yapılır. Metadata varsa cluster/node/directory kontrolünden sonra format atlanır. Metadata'sız dolu dizin reddedilir; PVC kökündeki `.lab-volume-identity` mevcutsa metadata kaybında yeniden format yapılmaz. `--ignore-formatted` veya otomatik veri silme yoktur. Tüm PVC'nin silinmesi/değiştirilmesi bu yerel marker ile saptanamaz; bu yüzden PVC silmek yasaktır ve test PVC UID'sini de karşılaştırır.
- Helm canlı lookup eski layout'u ve değişen kimlik/storage sözleşmesini reddeder. Deploy scripti ayrıca mevcut pod/PVC/mount denetimini yapar. Bu kontroller yönetici müdahalesine karşı bir güvenlik sınırı değil, yanlışlıkla upgrade'e karşı korumadır; annotation elle değiştirilmemelidir.
- Dış servis yok; yalnız cluster içi PLAINTEXT client:9092/controller:9093. NetworkPolicy client erişimini aynı namespace ile, controller erişimini aynı release'in pod'larıyla sınırlar. NetworkPolicy CNI uygulamasına bağlıdır; TLS/SASL değildir.
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

`validate.sh` için Bash, Helm, Python 3 ve PyYAML gerekir. Ubuntu bootstrap bunları kurar; diğer test makinelerinde `python3 -m pip install -r tests/requirements.txt` kullanın (gerekirse venv). Testler fake Kafka araçlarıyla format korumalarını doğrular; image veya Kubernetes çalıştırmaz.

TLS/SASL, JMX, dış erişim, production migration ve otomatik ölçekleme kapsam dışıdır. Eski Bitnami values yeni chart ile uyumlu değildir. [İşlem/test raporu](../../IMPLEMENTATION-REPORT.md).

Kaynak: [Apache Kafka KRaft operasyonları](https://kafka.apache.org/40/operations/kraft/).
