# Gerçek deploy denemesi ve başarısızlık analizi

## Kanıtın kaynağı

2026-08-31 tarihinde kullanıcı Contabo terminal çıktılarını bu görüşmede paylaştı. Ajan sunucuya SSH ile bağlanmadı. Aşağıdaki kayıtlar bu çıktılardan alınmış kısaltılmış metin kanıtıdır; uydurulmuş çalıştırma veya ekran görüntüsü değildir.

## Bootstrap ve deploy

- Ubuntu 24.04, x86_64, 4 vCPU ön kontrolleri PASS.
- İlk bootstrap tamamlanmamıştı; deploy.env ve deployer.kubeconfig yoktu. Sonraki root çalıştırmasında DEPLOY_USER=kafka-deploy ile exit 0; namespace, namespace Role/RoleBinding, deployer token ve cluster-ID Secret oluşturuldu.
- `deploy.sh --check`: API server dry-run dahil PASS.
- Gerçek kaynak SHA: `0747716e0c52b51b8fd2dda307bf99d1ba5b8d97`.
- Helm release/namespace: kafka-lab; revision 1; chart 0.1.0; image Apache Kafka 4.0.2 sabit digest.
- 10:56–10:57 UTC deploy/ilk smoke çıktısı:

```text
STATUS: deployed
REVISION: 1
statefulset rolling update complete 3 pods
kafka-lab-0  1/1 Running  0
kafka-lab-1  1/1 Running  0
kafka-lab-2  1/1 Running  0
data-kafka-lab-0  Bound  5Gi  RWO  local-path
data-kafka-lab-1  Bound  5Gi  RWO  local-path
data-kafka-lab-2  Bound  5Gi  RWO  local-path
LeaderId: 2
MaxFollowerLag: 0
```

Service'ler client ClusterIP:9092 ve headless:9092/9093. Üç birleşik broker/controller quorum üyesi 0/1/2. Cluster-ID/uzun pod/PVC kimlikleri özet çıktıda çıkarıldı; Secret/kubeconfig içeriği kaydedilmedi.

## Restart gözlemi — FAIL

11:05 UTC `smoke-test.sh --restart`: kafka-lab-0 pod'u yeniden oluştu ve Ready oldu; storage kimlik karşılaştırması FAIL. Yeni pod logu:

```text
Formatting metadata directory /var/lib/kafka/data with metadata.version 4.0-IV3.
Result: FAIL (exit 1)
```

Salt-okunur mountinfo, **üç pod'da da** aynı tür hatayı doğruladı:

```text
/k3s/storage/pvc-<id>_kafka-lab_data-kafka-lab-N -> /var/lib/kafka
/k3s/agent/containerd/.../containers/<id>/volumes/<id> -> /var/lib/kafka/data
```

Bunlar redakte edilmiş yol özetleridir. Apache imajının child VOLUME'u PVC parent mount'unu örtmüş; mesaj okunması diğer replikalardan recovery ile mümkün olsa da pod-local persistence sağlamamıştır. STALE_BROKER_EPOCH retry logu da görüldü; tek başına kök neden olarak gösterilmedi.

## Düzeltme ve güncel durum

0.2.0 chart: exact PVC mount + kraft alt dizini, image volume'larının açık tanımı, başlangıç storage guard, üç-pod audit ve legacy upgrade engeli. [Ayrıntılı bulgular](../../CHART-AUDIT.md), [kurtarma kapıları](../../deploy/contabo/STORAGE-RECOVERY.md).

Yeni kaynak pull edilmiş olsa da kullanıcı son denetiminde pod'lar hâlâ eski layout'ta: **düzeltilmiş chart'ın canlı deploy/restart kabulü yapılmadı.** Veri silme veya taşıma onayı alınmadan bu aşama tamamlandı sayılmaz. Eski chart'a image-only negatif deney canlıya uygulanmadı.
