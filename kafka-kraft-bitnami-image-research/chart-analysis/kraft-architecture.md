# Kafka KRaft ve bu haftanın mimari sınırı

KRaft, Kafka cluster metadata'sının Kafka controller quorum'u tarafından Raft ile yönetilmesidir. ZooKeeper'lı modelde metadata koordinasyonu ayrı ZooKeeper kümesine dayanır; KRaft'ta bu bağımlılık kalkar. Kafka 4.x bu çalışmada KRaft olarak kullanılır. [Apache KRaft](https://kafka.apache.org/40/operations/kraft/).

- **Broker:** topic partition kayıtlarını saklar; producer/consumer isteklerini ve partition replikasyonunu işler.
- **Controller:** broker/partition metadata'sını yönetir; quorum içinden leader seçilir. Üç controller çoğunluk için en az ikisine ihtiyaç duyar.
- **Bu demo:** aynı üç pod hem broker hem controller. Tek Contabo host üzerinde oldukları için fiziksel host arızasına karşı HA yoktur. Static voters ordinal 0/1/2 ve headless DNS adlarıyla sabittir; in-place scale-to-zero veya 1↔3 değişimi desteklenmez.
- **Cluster kimliği:** broker'lar aynı cluster ID'yi, farklı node/directory ID'leri kullanır. Aynı ID ile iki canlı broker kopyasını aynı ağa bağlamak kurtarma yöntemi değildir.
- **Veri kalıcılığı:** PVC'nin Bound olması yeterli değildir; gerçek log.dirs altında çalışan filesystem'in PVC'ye bağlı olması gerekir. 0.1.0 denemesinde bu kontrolün eksikliği gerçek bir hata üretti.

## Klasör yapısı — komutla doğrulanabilir

Repo kökünden:

```bash
git ls-files legacy/bitnami-kafka lab/kafka-apache
```

```text
legacy/bitnami-kafka/                       eski Bitnami chart ve upstream belgeleri (korundu)
lab/kafka-apache/                              bağımsız Apache demo chart
  Chart.yaml, values.yaml, values.schema.json
  templates/                                  StatefulSet, Service, ConfigMap, PDB, NetworkPolicy
  files/start.sh                              KRaft properties ve storage kontrolleri
scripts/contabo/                               manuel Ubuntu/K3s kurulum ve deploy
scripts/lab/                                   mesaj/restart testi ve salt-okunur disk denetimi
kafka-kraft-bitnami-image-research/             haftalık araştırma/teslim belgeleri
```

Bu güncel dizin özeti gerçek repo dosyalarından türetilmiştir. Eski chart, final temizlikte `legacy/` altına taşındı; içeriği silinmedi. Roadmap Gün 1'de izin verilen komut çıktısı ve teslim edilen ekran görüntüsü, bağımsız `lab/kafka-apache` ağacını ayrıca doğrular.

2026-08-31 tarihinde çalıştırılan `git ls-files lab/kafka-apache` komutunun gerçek çıktısı:

```text
lab/kafka-apache/Chart.yaml
lab/kafka-apache/README.md
lab/kafka-apache/files/start.sh
lab/kafka-apache/templates/_helpers.tpl
lab/kafka-apache/templates/configmap.yaml
lab/kafka-apache/templates/networkpolicy.yaml
lab/kafka-apache/templates/pdb.yaml
lab/kafka-apache/templates/service.yaml
lab/kafka-apache/templates/statefulset.yaml
lab/kafka-apache/values.schema.json
lab/kafka-apache/values.yaml
```
