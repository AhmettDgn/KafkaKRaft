# Values değişiklik notları

## Önemli sınır

Bu chart'ın mevcut template'leri ile güvenli bir “non-Bitnami values override” yoktur. `non-bitnami-values.yaml`, hedefteki **port edilmiş chart** için örnek değer sözleşmesidir; doğrudan bu chart'a deploy girdisi değildir.

| Alan | Mevcut chart | Port edilmiş hedef |
| --- | --- | --- |
| Kafka runtime | Bitnami layout/scriptleri ve `KAFKA_CFG_*` | `apache/kafka` uyumlu runtime; `KAFKA_*` veya `server.properties` |
| Config mount | `/opt/bitnami/kafka/config` | ASF imajının `/mnt/shared/config` giriş modeline uygun mount |
| Data path | `/bitnami/kafka` | Yeni imaj/config tarafından seçilen kalıcı data path |
| Volume permissions | Hard-coded `/bin/bash` | POSIX `sh` veya kontrol edilen kurum shell imajı |
| Auto-discovery | Bitnami kubectl + bash | `registry.k8s.io/kubectl` tabanlı, shell'i doğrulanmış kurum imajı |
| JMX | Bitnami JAR adı/komutu | Doğrulanmış kurum JMX exporter/JAR veya Java agent |
| Provisioning | Bitnami library ve `/opt/bitnami/kafka/bin` | ASF tool path'leri ve bağımsız client config scripti |

## Digest politikası

Placeholder digest'ler bilinçli olarak boş gerçek değer yerine kullanılmıştır. Tag tek başına immutable kabul edilmemeli; onay akışı manifest listesinde iki mimariyi doğruladıktan sonra registry digest'ini bu dosyaya yazmalıdır. Kubernetes digest belirtilmişse tag'i değil digest'i çeker ([Kubernetes image names](https://kubernetes.io/docs/concepts/containers/images/)).
