# 0.1.0 storage olayı — kontrollü veri koruma ve geçiş

## Durum ve yetki sınırı

Bu rehber **mevcut veriyi korumayı** hedefler. Çalışan sunucuda otomatik taşıma/silme yapmaz. 0.2.0 chart düzeltmesi hazırdır; mevcut cluster'ın taşındığı veya yeni sürümün sunucuda doğrulandığı iddia edilmez. Gerçek geçiş, aşağıdaki yedek/kurtarma kapıları tamamlandıktan sonra sunucuya özel işlem planıyla yapılmalıdır.

Kullanıcının 2026-08-31 çıktısı: eski release `kafka-lab`, namespace `kafka-lab`, Helm revision 1, kaynak `0747716`; broker 0 yeniden oluşunca format atmış, mesajlar diğer replikalar sayesinde erişilebilir kalmıştır. Mountinfo PVC-parent ve containerd-child çakışmasını doğrulamıştır. Broker 1/2'nin mount kaynakları ayrıca envanterlenmelidir.

## Şu anda yapılmaması gerekenler

- `helm upgrade`, `helm rollback`, restart testi, pod/StatefulSet/namespace/PVC silme, scale-to-zero, reboot veya K3s/containerd temizliği yapmayın.
- Eski chart'a rollback kalıcılık hatasını geri getirir; çözüm değildir.
- Containerd `containers/<id>/volumes/<id>` dizinlerini yedek kabul etmeyin. Container temizliğiyle kaybolabilirler.
- Çalışan Kafka loglarını `cp -r`, `kubectl cp` veya `tar` ile almak **tutarlı/yeterli yedek** garantisi vermez. Yalnız dış producer'ları durdurmak da Kafka'nın Raft/log yazmalarını durdurmaz.
- `storage-layout` annotation'ını elle ekleyerek korumayı aşmayın; PVC UID/Bound durumu tek başına kalıcılığı kanıtlamaz.
- `ignore_image_defined_volumes` değerini tüm containerd için değiştirip servisi yeniden başlatmayın. Bu değişiklik başka workload'ları etkiler; bu düzeltme chart seviyesindedir.

## A. Hemen yapılabilecek salt-okunur envanter

Normal `kafka-deploy` kullanıcısıyla repo'yu güncellemek yalnız dosyaları değiştirir; otomasyon yoktur:

```bash
cd ~/KafkaKRaft
git status --short
git pull --ff-only origin main
export KUBECONFIG=/etc/kafka-kraft/deployer.kubeconfig
mkdir -p /var/log/kafka-lab
set -o pipefail
bash scripts/lab/storage-audit.sh --inspect 2>&1 |
  tee "/var/log/kafka-lab/storage-inspection-$(date -u +%Y%m%dT%H%M%SZ).md"
```

**Eski kurulumda bu komutun FAIL / çıkış 1 vermesi beklenir.** Veri değiştirmez; üç pod'un mount kaynaklarını gösterir. Yeni `deploy.sh --check` ve `smoke-test.sh --restart` aynı eski layout'u gördüğünde güvenlik nedeniyle durur. Tekrar çalıştırıp engeli aşmaya uğraşmayın.

Ek metadata/health envanteri (Secret içerikleri yok):

```bash
git rev-parse HEAD
helm history kafka-lab -n kafka-lab
kubectl get pods -n kafka-lab -o wide
kubectl get pvc -n kafka-lab -o wide
for pod in kafka-lab-0 kafka-lab-1 kafka-lab-2; do
  printf '\n%s\n' "$pod"
  kubectl exec -n kafka-lab "$pod" -c kafka -- \
    env KAFKA_HEAP_OPTS='-Xms32m -Xmx128m' \
    /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status
done
kubectl exec -n kafka-lab kafka-lab-0 -c kafka -- \
  env KAFKA_HEAP_OPTS='-Xms32m -Xmx128m' \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe
```

Mount raporları host yollarını içerir; paylaşırken kullanıcı/host adlarını maskeleyebilirsiniz. Token/private key/admin kubeconfig veya `kubectl get secret -o yaml` çıktısını paylaşmayın. Test topic'lerinde bir saat retention bulunduğunu unutmayın; süre dolması ile depolama kaybını karıştırmayın.

## B. Geçişten önce zorunlu karar/kanıt kapısı

Operatör şu bilgileri onaylamalıdır:

1. Üç broker için pod UID, container ID, PVC/PV adı ve **gerçek Kafka mount kaynakları**; bunlar yeniden başlatma sonrası değişebileceğinden eski çıktılardaki container ID'leri komutlara sabit yazılmamalıdır.
2. Korunacak topic'ler, consumer-group offset'leri, retention, log boyutu ve boş disk alanı. Veri sadece disposable test mesajları olsa bile otomatik sıfırlama yapılmaz.
3. Yazıcıların durdurulabileceği bakım aralığı ve cluster'ın yedekleme anındaki tutarlılık yöntemi. Destekleniyorsa sağlayıcı seviyesinde tüm ilgili diskleri kapsayan, doğrulanmış snapshot/izole kurtarma kopyası değerlendirilebilir; bu özelliğin mevcut olduğu varsayılmaz.
4. Yedek, PVC dizinleriyle **sınırlı olamaz**: asıl veriyi barındıran üç containerd volume'u ve KRaft metadata dahil olmalıdır. Cluster-ID Secret ve gerekli erişim kimlikleri ayrıca güvenli, repo dışı yerde saklanmalıdır; rapora içerikleri yazılmaz.
5. Yedekten **izole bir ortamda geri yükleme denemesi**. Aynı node/cluster kimliğiyle ikinci broker seti canlı cluster'a bağlanmamalıdır. Çalışan loglardan alınmış doğrulanmamış dosya kopyası bu kapıyı geçmez.

Bu bilgiler ve geri yüklenebilir yedek kanıtı yoksa **burada durun**. Bu repo, canlı Kafka verisinin taşınmasını doğrulanmamış bir komut dizisiyle otomatikleştirmez.

## C. Hedef dosya düzeni ve kimlik sözleşmesi

| Öğe | Eski 0.1.0 | Düzeltilmiş 0.2.0 |
| --- | --- | --- |
| PVC mount | `/var/lib/kafka` | `/var/lib/kafka/data` (tam eşleşme) |
| Gerçek log dizini | `/var/lib/kafka/data` (container-local) | `/var/lib/kafka/data/kraft` (PVC altı) |
| Metadata | Eski container-local `meta.properties` | Aynı broker'ın korunan dosyası, `kraft/meta.properties` |
| Yerel topoloji kaydı | `.lab-identity` log dizininde | Aynı kayıt korunur; PVC kökünde ayrıca `.lab-volume-identity` |
| Image yardımcı volume'ları | Gizli containerd volume'ları | Açık readonly emptyDir mount'ları |

Her broker'ın **tüm log dizini**, kendi KRaft metadata logu, `meta.properties`, `directory.id`, node ID ve cluster ID korunmalıdır. Sadece topic partition dosyalarını veya sadece `meta.properties` dosyasını taşımak yeterli değildir. Broker 0'ın dizini broker 1/2'ye kopyalanmamalıdır.

Restore hedefinde PVC kökünde `kraft/` bulunur; kaynak Kafka dizininin **içeriği** bu alt dizine gider. Yanlışlıkla `kraft/data/` oluşturulmaz. UID/GID 1000 erişimi ve root dizinin fsGroup izinleri doğrulanır. Eski PVC'de kalan boş `data/` mount noktası dahil beklenmeyen kök içerikler otomatik silinmez; yedek sonrası ayrıca incelenir. Chart bu durumda başlamayı reddeder.

Mevcut `meta.properties` sağlıklıysa yeni başlangıç scripti formatı atlar; metadata eksikse yeni ID üretmek veya format zorlamak çözüm değildir. Root volume marker mevcut olup Kafka metadata kayıpsa başlangıç durur.

## D. Kontrollü geçişin uygulama şartları

Bu bölüm bir yürütme scripti değil, yedek sonrası sunucuya özel planın kabul kriterleridir:

1. Önce B kapısı geçilir. Eski Helm manifesti/values (hassas kısımlar güvenli saklanarak), pod/PVC eşlemeleri ve rollback/kurtarma noktası kaydedilir.
2. Kafka'nın yazmadığı tutarlı bir durumdan, kaynak containerd dizinleri garbage collection'a uğramadan veri alınması sağlanır. Nasıl sağlanacağı mevcut host/snapshot olanaklarına göre doğrulanmadan pod silinmez.
3. Veriler broker bazında doğru PVC'nin `kraft/` altına, mevcut dosyalar ezilmeden yerleştirilir; dizin/metadata bütünlüğü, sahiplik ve kayıt kimlikleri karşılaştırılır.
4. Yeni StatefulSet spec'i ancak veri hazırken kontrollü replacement planıyla uygulanır. Mevcut chart'ın legacy-upgrade engeli normal yol için bilinçlidir. Raw `kubectl apply` ile otomatik rolling restart başlatmak veya annotation sahteciliği yapmak kabul edilmez. Gerekli kontrollü replacement/Helm release uzlaştırma komutları, yedek ve staging kanıtı incelendikten sonra ayrı onaylanır.
5. Üç birleşik broker/controller'ın birden kaybedilmesine izin verilmez. Readiness tek başına replica catch-up değildir; bir sonraki pod işleminden önce quorum ve ISR doğrulanır. Offline tüm-cluster restore seçilmişse izole restore ve bakım kesintisi ayrıca onaylanır.
6. Eski geçici dizin/yedekler kabul testleri tamamlanmadan temizlenmez. Düzeltmeden sonra eski chart'a `helm rollback` yapılmaz; sorun halinde çalışan pod'lar korunur ve doğrulanmış yedek/kurtarma planına dönülür.

## E. Geçiş sonrası kabul testleri

Yalnız geçiş gerçekten tamamlanıp yeni pod'ların layout'u `pvc-v2` olduğunda:

```bash
bash scripts/lab/storage-audit.sh
bash scripts/lab/smoke-test.sh
bash scripts/lab/smoke-test.sh --restart
```

Beklenenler: üç pod'un gerçek `/var/lib/kafka/data` kaynağı doğru PV; hiçbir `/containers/.../volumes/...` kaynaklı Kafka data mount'u yok; Kafka `log.dirs` doğru; eski cluster/node/directory kimlikleri korunmuş; PVC UID/PV ve identity hash'leri restart öncesi/sonrası aynı; logda format yerine mevcut storage kullanımı; eski kayıtlar okunuyor, yeni kayıtlar yazılıyor, quorum/ISR sağlıklı.

Yeni testler önce storage audit çalıştırır; unsafe eski layout'ta topic oluşturmadan veya pod silmeden durur. Metadata yorum/tarih/sıralama farkları göz ardı edilir, **cluster/node/directory ID değişiklikleri hâlâ FAIL** verir. Mesaj okumak tek başına kalıcılık PASS sayılmaz.

## Mevcut ilerleme

- Kod ve offline regresyonlar: rapordaki son durum esas alınır.
- Sunucudaki 0.2.0 deploy: yapılmadı.
- Veri yedeği / fiziksel taşıma / izole restore: yapılmadı, operatör kanıtı bekleniyor.
- İlk güvenli sonraki adım: A bölümündeki salt-okunur üç-pod envanterini paylaşmak.
