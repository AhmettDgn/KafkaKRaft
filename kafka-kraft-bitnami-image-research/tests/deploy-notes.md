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

## Tekrar ön kontrol — 2026-08-31 12:30:30 UTC

Kullanıcı `artifacts/server-check-20260831T123030Z-CAHfug.md` terminal kanıtını paylaştı. Mesajdaki kesilmiş satırlar yerine tam ek metin esas alındı:

- Checkout `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c`, çalışma ağacı temiz, kullanıcı kafka-deploy, context kafka-lab.
- Helm release hâlâ revision 1 / **kafka-apache-lab-0.1.0** / app 4.0.2 / deployed. Güncel checkout yeni chart'ın çalıştığını göstermez.
- Üç pod 1/1 Running, StatefulSet 3/3, üç PVC Bound / 5Gi / local-path: durum okuması PASS.
- Storage audit **FAIL (exit 1)**: her üç pod'da `/var/lib/kafka` PVC mount'u altında `/var/lib/kafka/data` containerd image volume'u var. Eski shadow mount sorunu devam ediyor.
- Quorum status PASS: leader 2, voters 0/1/2, max follower lag 0, lag time 20 ms. Bu metadata quorum gözlemidir; topic ISR ve kalıcı disk kabulü değildir.
- Producer/consumer ve restart bu tur yeniden çalıştırılmadı. Veri koruma/silme kararı bekleniyor; güvenlik engeli aşılmadı.

Ayrıntılı komut/çıkış kodları [işlem raporunda](../../IMPLEMENTATION-REPORT.md). Sunucuya ajan bağlantısı veya yeni deploy yapılmadı.

## Onaylı temiz kurulum hazırlığı — 2026-08-31 13:03–13:05 UTC

Kullanıcı eski test topic/mesaj/offset/disk verilerinin silinerek 0.2.0 ile sıfırdan kurulmasına açık onay verdi. Bu nedenle yukarıdaki veri koruma/silme kararı bekleme durumu sona erdi; veri taşıması yapılmadı.

- 13:03:07: eski Helm release uninstall başarılı; pod'lar önce Terminating, PVC'ler Bound kaldı.
- 13:05:10: pod/StatefulSet ve release yokluğu kontrolleri sonrası üç eski PVC/PV eşleşmesi doğrulanarak yalnız `data-kafka-lab-0/1/2` silindi; cluster-ID Secret yenilendi. Blok exit 0.
- Boş kurulum denetimi PASS: `no existing release, pods or PVCs (pre-deploy only)`. Son durum listesinde pod/StatefulSet/PVC/Service yok. Namespace, erişim tokenı ve RBAC silinmedi.
- Eski veriler taşınmadı ve doğrulanmış geri yükleme garantisi yok; fiziksel secure erase iddia edilmez.
- **0.2.0 deploy henüz bekleniyor.** Sıfırlama başarısı yeni çalışan Kafka veya kalıcılık testi başarısı değildir.

Kanıt: kullanıcının `artifacts/reset-stage1-20260831T130307Z-kzmfMi.md` ve `artifacts/reset-stage2-20260831T130510Z-L0WFiP.md` terminal çıktıları. Tam komut/sonuç kaydı [işlem raporundadır](../../IMPLEMENTATION-REPORT.md).

## Temiz 0.2.0 deploy — 2026-08-31 21:40 UTC

Kullanıcının `artifacts/deploy-v020-20260831T214010Z-sePMvW.md` çıktısı:

- Çalıştıran shell root ve checkout `/root/KafkaKRaft`; kaynak `0c0c5ce0acfc570c793035846c6f0254b52dfd5d`. Bu, daha önce önerilen kafka-deploy kullanıcısından farklıdır; ancak scriptin scope/RBAC/storage kontrolleri geçti ve namespace dışı mutation çıktısı yoktur.
- Chart 0.2.0 doğrulandı. 6 chart + 10 storage Python testi, 12 mock startup ve 4 cluster-ID senaryosu geçti. Bu checkout, sonraki üç roadmap testini içermediğinden bu koşuda toplam 16 Python testi vardır; chart/deploy/storage/smoke dosyaları `430f8cb` ile aynıdır.
- Deploy `--check` PASS; boş release/pod/PVC, Helm lint ve API server dry-run geçti. Gerçek install PASS: `kafka-apache-lab-0.2.0`, app 4.0.2, revision 1.
- Üç pod 1/1 Running ve StatefulSet 3/3; üç yeni 5Gi local-path PVC Bound. Her pod'da `/var/lib/kafka/data` tam ve tek mount olarak kendi K3s PVC kaynağına bağlı.
- Üç pod için `explicit PVC mount and metadata verified`; storage audit **PASS**. Eski `/var/lib/kafka` parent + containerd child shadow düzeni yok.
- Kurulum bloğu exit 0. Bu sonuç image pull, rollout ve ilk metadata/PVC düzenini doğrular; quorum/topic/mesaj ve pod replacement sonrası kalıcılık henüz bu turda test edilmedi.

## 0.2.0 smoke ve pod replacement — 2026-08-31 21:45 UTC

Kullanıcı normal `kafka-deploy` hesabında, kaynak `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c` ile `smoke-test.sh --restart` çalıştırdı. Sonuç:

- Başlangıç storage audit: üç pod için exact PVC mount/metadata PASS.
- Quorum: leader 1, voters 0/1/2, observer yok, max follower lag 0.
- RF=3/minISR=2 topic, üç sıralı mesaj ve full ISR: PASS.
- Yalnız pod 0 silinip yeni pod Ready oldu. Aynı PV/PVC mount kaynağı ve üç broker'ın semantik storage kimliği karşılaştırması PASS.
- Restart öncesi üç mesaj tekrar okundu; restart sonrası dördüncü mesaj yazılıp dört mesaj okundu: PASS.
- Quorum tekrar max follower lag 0; topic 1'den 3 partition'a genişletildi ve tüm partition'lar üç üyeli ISR gösterdi.
- Son: `PASS: replacement pod, unchanged metadata and persistent messages`; `Result: PASS`. Böylece 0.2.0 kalıcılık kabulü tamamlandı.

Bu tek-pod replacement testidir; host arızası veya eşzamanlı üç-pod kaybı testi değildir. Ayrıntılar [producer/consumer](producer-consumer-test.md), [topic](topic-management-test.md) ve [işlem raporunda](../../IMPLEMENTATION-REPORT.md).
