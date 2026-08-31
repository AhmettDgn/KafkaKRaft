# Chart ve çalışma zamanı çakışma denetimi — 2026-08-31

## Sonuç

0.1.0 chart'ta **kritik veri kalıcılığı hatası** doğrulandı. PVC parent mount'u, Apache image-defined child volume tarafından örtülüyordu. 0.2.0 düzeltmesi ve fail-closed kontrolleri yazıldı. Eski canlı cluster'a otomatik upgrade **engellendi**. Düzeltmenin canlı ortamda çalıştığı henüz doğrulanmadı; offline PASS, veri taşındı veya production hazır anlamına gelmez.

Bu denetim yeni `lab/kafka-apache` chart'ının bütün template/helper/values/startup dosyalarını, deploy/bootstrap/smoke scriptlerini, namespace RBAC'ını ve kökteki eski chart ile birlikte bulunma durumunu kapsar. Eski Bitnami chart yeniden geliştirilmedi; onun tüm production özelliklerine güvenlik sertifikasyonu yapılmadı.

## Bulgular ve yapılanlar

| ID / önem | Bulgu ve etki | Düzeltme / durum |
| --- | --- | --- |
| S01 Kritik | PVC `/var/lib/kafka`, image VOLUME `/var/lib/kafka/data`; Kafka container-local diske yazıyor. Pod yenilenince format ve directory ID değişimi. | PVC exact `/var/lib/kafka/data`, log alt dizini `kraft`; chart 0.2.0. Sunucu geçişi bekliyor. |
| S02 Yüksek | İmajın `/etc/kafka/secrets` ve `/mnt/shared/config` volume'ları da örtük containerd diskleri oluşturuyor; readOnlyRootFilesystem tek başına bunları engellemiyor. | İkisi açık readonly emptyDir. Bu chart'ta kullanılmıyorlar; entrypoint bypass ediliyor. |
| S03 Kritik | Sadece mountPath değiştiren upgrade canlı pod'ları yeni boş dizine döndürebilir; PVC Bound yanıltıcı. | Helm lookup legacy layout'u reddeder; deploy scripti mutation öncesi runtime/PVC audit çalıştırır. Veri taşıma otomatik değil. |
| S04 Yüksek | İlk startup testi gerçek image-volume davranışını modellemiyordu. | Image digest/volume sözleşmesi fixture'ı, ancestor mount regresyonu ve gerçek production Helm guard helper testleri eklendi. |
| S05 Yüksek | Startup yalnız log dizinine bakıyordu; kaybolan alt dizinde yeni format mümkün. | Exact mount/anon kaynak/nested mount kontrolleri; PVC kökünde identity marker; marker varsa metadata kaybında duruş. Tüm PVC kaybını marker tek başına engelleyemez. |
| S06 Orta | Restart scripti sadece tüm meta.properties metnini kıyaslıyor; fail aşaması belirsiz. İlk testte gerçek format hatasını yakaladı, bu yanlış pozitif diye atılamaz. | Semantik cluster/node/directory/version karşılaştırması + bütün pod'larda PVC/PV/mount/stamp kontrolü; checkpoint hata mesajları. Kimlik değişimi hâlâ FAIL. |
| S07 Yüksek | Eski script bootstrap eksikken default Kubernetes context'inde çalışabiliyordu. | Smoke/audit açık KUBECONFIG veya bootstrap yapılandırması ister; implicit default context reddedilir. |
| S08 Orta | Statik quorum koruması yalnız replica sayısına odaklıydı; Secret adı/DNS/storage değişimi pod'ları bozabilirdi. | Helm immutable identity/storage signature; count/Secret/domain/PVC size/class değişirse upgrade durur. Release/namespace de imzaya dahil. |
| S09 Orta | Kısa readiness anı rollout için yeterli; PDB tüm restart türlerini durdurmaz. | minReadySeconds 30 eklendi. ISR garantisi değildir; kontrollü geçişte ayrı quorum/ISR kapısı gerekli. |

## Diğer denetlenen alanlar

| Alan | İnceleme sonucu ve sınır |
| --- | --- |
| Image/entrypoint | Apache 4.0.2 OCI index digest korunuyor. Bash/Java ve image volumes resmi metadata/source ile karşılaştırıldı. `/etc/kafka/docker/run` kullanılmıyor; custom config, doğrudan Kafka binary. İmaj değişirse sözleşme yeniden incelenmeli. |
| StatefulSet/PVC | Üç combined node, Parallel ilk scheduling, ordinal node ID, bir PVC/pod, Retain. `kraft/` mount altında; init container/hostPath/privileged container yok. Eski PVC'nin yeni layout'a otomatik adoption'ı yok. |
| Kafka config | Static voters ordinal/FQDN'lerle tutarlı; CLIENT 9092, CONTROLLER 9093; RF 3/minISR 2, tek node 1/1. Auto-topic creation kapalı. Metadata/log aynı kalıcı dizinde. Static quorum in-place scale edilmez. |
| Service/DNS | Headless service adı StatefulSet serviceName ve advertised listeners ile eşleşiyor; publishNotReady ilk quorum bootstrap için açık. Client ClusterIP; NodePort/LoadBalancer yok. Selector'lar sadece aynı release/name pod'larını seçiyor. |
| NetworkPolicy | Client aynı namespace; controller ve Kafka egress aynı release selector'ı. DNS TCP/UDP 53 açık. DNS egress bütün namespace'lere 53 izni verir: lab için kabul edilmiş sınırlama, production için DNS pod/namespace kısıtı ayrıca tasarlanmalı. Enforcement CNI'ye bağlı. |
| SecurityContext | UID/GID/fsGroup 1000, RuntimeDefault seccomp, drop ALL, no escalation, read-only rootfs; pod token mount kapalı. Writable config/tmp emptyDir; image auxiliary mounts readonly. CSI/fsGroup davranışı canlıda tekrar doğrulanmalı. |
| Probe/resource | Startup/liveness TCP, readiness Kafka API; hiçbirisi disk/ISR kanıtı yerine geçmez. JVM 512Mi heap, pod memory 1536Mi limit ve CLI overhead laboratuvar bütçesi. Yük testi/disk kotası/zafiyet taraması yapılmadı. |
| RBAC | Namespace Role/RoleBinding; cluster-admin yok. Deploy kullanıcısı Helm için namespace Secret'larını yönetebilir; bu namespace içindeki verilere güvenilir operatördür. Uzun ömürlü SA token ayrı 0640 dosyada; production credential lifecycle değil. |
| Bootstrap | Idempotent Secret/config koruması, mevcut servisi otomatik devralmama, shared primary-group reddi. Root sadece bootstrap. K3s/Helm sürümleri sabit. Sunucudaki apt kaynakları kubectl 1.30 olasılığını gösteriyor, gerçek client sürümü ayrıca okunmalı; başarılı API çağrısı resmi version-skew desteğini kanıtlamaz. |
| Helm v3 davranışı | Lint/template lookup sunucuya bağlanmadığında legacy detection yapamaz; online Helm upgrade helper ve deploy runtime audit ayrı katmandır. Raw kubectl/yönetici müdahalesi korumaları aşabilir; annotation değişikliği güvenli migration değildir. |
| Kaynak/raporlama | GitHub workflow yok. Kaynak pull cluster'ı değiştirmez. Deploy temiz checkout + SHA raporlar. Runtime snapshot'larda kimlik değerleri yerine hash tutulur; mount kaynağı/PVC ID gizli credential değildir ama altyapı bilgisi içerir. |
| Eski Bitnami chart | Kökte version 32.4.4, common 2.31.4 bağımlılığı korunuyor. Yeni chart dependencies içermez; `lab.*` helpers eski `kafka.*`/`common.*` ile karışmaz. Yeni deploy yalnız `lab/kafka-apache` kullanır; eski values uyumlu değildir. İki chart aynı namespace/release adıyla kurulmaz. |
| Kök paketleme | `.helmignore` lab/scripts/tests/deploy/artifacts'ı eski chart paketinden çıkarır. Yeni rapor ve audit belgesi de paket dışına alınır. Eski template/value dosyaları değiştirilmez. |

## Kontrol edilen dosyalar

- `lab/kafka-apache/Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/{_helpers.tpl,statefulset.yaml,service.yaml,configmap.yaml,networkpolicy.yaml,pdb.yaml}`, `files/start.sh`.
- `scripts/contabo/{preflight,bootstrap,deploy}.sh`, `scripts/install-tools.sh`, `scripts/lab/{create-cluster-id,smoke-test,storage-audit}.sh`, `scripts/lab/storage_audit.py`, `scripts/validate.sh`.
- `deploy/contabo/{lab-access.yaml,lab-values.yaml.example,deploy.env.example,versions.env}`; root Chart/lock/dependency ve Helmignore.
- Testler: mevcut render/startup/identity testlerine ek `tests/test_storage.py`, `tests/fixtures/apache-kafka-4.0.2-image.json`.

## Test/kanıt ayrımı

| Katman | Durum |
| --- | --- |
| 0.1.0 gerçek Contabo bootstrap/deploy/topic/mesaj | Kullanıcı loglarında başarılı |
| 0.1.0 gerçek restart/pod-local persistence | Başarısız; mountinfo kök nedeni doğruluyor |
| 0.2.0 lint/render/guard/mount parser/mock startup | Son komut sonuçları IMPLEMENTATION-REPORT.md'de |
| 0.2.0 gerçek containerd/K3s çalıştırma ve restart | Henüz çalıştırılmadı |
| Mevcut verinin yedeği/taşınması/izole restore | Henüz yapılmadı |
| Production HA/TLS/SASL/yedekleme/performans | Kapsam dışı; onaylanmadı |

İlk sonraki işlem [STORAGE-RECOVERY.md](deploy/contabo/STORAGE-RECOVERY.md) A bölümündeki salt-okunur envanterdir. Yeni chart kaynaklarının hazır olması eski canlı verinin taşındığı anlamına gelmez.

## Kaynaklar

- [Apache Kafka 4.0.2 Dockerfile](https://github.com/apache/kafka/blob/4.0.2/docker/jvm/Dockerfile): üç image-defined VOLUME.
- [containerd helpers](https://github.com/containerd/containerd/blob/main/internal/cri/server/helpers.go) ve [container creation](https://github.com/containerd/containerd/blob/main/internal/cri/server/container_create.go): CRI mount eşlemesi, image volume oluşturma.
- [containerd configuration](https://github.com/containerd/containerd/blob/main/docs/cri/config.md): ignore_image_defined_volumes ve implicit writable mount davranışı.
- [Kubernetes StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/): update/storage semantiği.
- [Kubernetes disruption](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/): PDB'nin kapsamadığı silme/update yolları.
