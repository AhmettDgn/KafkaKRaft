# Ubuntu / Contabo — elle kurulum

> **Önemli — 0.1.0 / commit 0747716 ile kurulmuş mevcut cluster:** Normal deploy veya restart çalıştırmayın. Containerd child-volume çakışması doğrulanmıştır. Önce [STORAGE-RECOVERY.md](STORAGE-RECOVERY.md) dosyasını okuyup salt-okunur envanteri alın. Yeni 0.2.0 chart eski kuruluma otomatik upgrade'i bilinçli olarak engeller. Aşağıdaki ilk kurulum adımları yalnız boş/yeni ortama yöneliktir.

GitHub otomasyonu yoktur. `git push` sunucuda hiçbir komut çalıştırmaz. Her güncellemede sunucuda `git pull --ff-only`, doğrulama ve deploy komutlarını siz çalıştırırsınız.

## 1. Hazırlık

- Ayrı test sunucusu: Ubuntu 22.04/24.04/26.04, systemd, amd64 veya arm64; en az 4 vCPU, nominal 8 GB RAM, /var/lib altında 30 GiB boş alan. Kaynak kontrolü kapasite garantisi değildir.
- İlk kurulum için sudo; sonraki deploy/test için normal kullanıcı. Mevcut K3s/Kubernetes varsa script otomatik devralmaz; farklı Helm sürümünü ezmez.
- Contabo ağ firewall'ında SSH erişiminizi koruyun. **6443/TCP, 10250/TCP, 8472/UDP ve 9092–9093/TCP portlarına internetten erişimi kapatın.** Kafka ve API'yi public açmayın. Egress DNS/HTTPS image/package indirmeleri için gerekli. Script firewall değiştirmez.
- Aktif UFW/başka host firewall varsa K3s pod/service trafiği ve DNS için yerel kuralları [K3s gereksinimlerine](https://docs.k3s.io/installation/requirements) göre inceleyin; firewall'ı körlemesine kapatmayın.
- Sabit sürümler: `deploy/contabo/versions.env`. Varsayılan storage `local-path`; 3 adet 5Gi PVC. Local-path kapasitesi gerçek disk kotası değildir; disk izleme/yedek gerekir.
- Varsayılan `lab` profili TLS/SASL içermeyen cluster içi testtir. Ayrı `secure` profil aşağıda açıklanır. Üç pod aynı fiziksel sunucudadır; sunucu kaybına karşı HA sağlamaz.

## 2. Repoyu alın ve ön kontrolü çalıştırın

Sudo yetkili **normal Linux kullanıcınızla**, kendi home dizininizde:

```bash
git clone https://github.com/AhmettDgn/KafkaKRaft.git
cd KafkaKRaft
bash scripts/contabo/bootstrap.sh --check
```

Private repo ise GitHub'a erişim için kendi salt-okunur repo anahtarınızı/kimliğinizi kullanın. Token'ı clone URL'sine veya rapora yazmayın. GitHub Actions Secret kurulumu yoktur.

ZIP/dosya kopyası da kullanılabilir. Scriptler LF'dir; executable biti kopyada kaybolursa `bash script.sh` yeterlidir. Git içermeyen kopyada rapor SHA yerine `unversioned` der.

## 3. Bir defalık kurulum

Önce yukarıdaki firewall kısıtlarını gerçekten uygulayın. Aşağıdaki onay değişkeni firewall'ı sizin yerinize yapılandırmaz.

```bash
mkdir -p artifacts
set -o pipefail
sudo env DEPLOY_USER="$(id -un)" LAB_FIREWALL_CONFIRMED=true \
  bash scripts/contabo/bootstrap.sh --install 2>&1 | tee artifacts/bootstrap.log
```

`bootstrap.log` yerel kurulum çıktısıdır; Git'e eklenmez. Kurulumun sonucunu uygulama raporunuza aktarabilirsiniz. Script token/kubeconfig içeriğini yazdırmaz; `bash -x` ile çalıştırmayın.

Script, K3s ve Helm'i sabit sürümlerle kurar; namespace erişimini ve kalıcı cluster-ID Secret'ını hazırlar. Mevcut yapılandırma ve cluster ID korunur. Beklenmeyen mevcut servis/namespace/sürüm durumunda durur: silerek veya marker dosyasını elle oluşturarak kontrolü aşmayın.

Yalnız root erişiminiz varsa ilk kurulumda `DEPLOY_USER=kafka-deploy` belirtin. Sonra `sudo -iu kafka-deploy` ile o kullanıcının home dizinine geçip repo'yu yeniden klonlayın; root'a ait erişilemez bir klasörden deploy etmeyin. Script bu kullanıcıya sudo yetkisi vermez.

Sunucuda oluşturulan dosyalar:

| Dosya | Kullanım |
| --- | --- |
| /etc/kafka-kraft/deploy.env | Manuel deploy ayarları |
| /etc/kafka-kraft/lab-values.yaml | Yeni chart'ın override değerleri |
| /etc/kafka-kraft/deployer.kubeconfig | Yalnız lab namespace yetkili kimlik |
| /var/log/kafka-lab/*.md | Deploy ve Kafka test sonuçları |

Yapılandırma/kubeconfig yalnız root ve deploy kullanıcısının özel primary grubuna okunabilir. Script paylaşılan primary grubu reddeder; sonradan bu gruba başka kullanıcı eklemeyin. Kubeconfig'i Git'e, rapora veya mesajlara kopyalamayın. `/etc/rancher/k3s/k3s.yaml` admin kimliğidir; deploy kullanıcısına verilmez.

## 4. Doğrulayın, kurun, mesaj testi yapın

Normal deploy kullanıcısıyla, repo dizininde:

```bash
bash scripts/validate.sh
bash scripts/contabo/deploy.sh --check
bash scripts/contabo/deploy.sh
bash scripts/lab/smoke-test.sh
# Yalnız bu laboratuvardaki kafka-lab-0 pod'unu yenileyen kesintili test:
bash scripts/lab/smoke-test.sh --restart
```

- `validate.sh`: yerel lint/render/Bash ve mock testler; Kubernetes'e bağlanmaz.
- `deploy.sh --check`: ayrıca API server dry-run; gerçek dağıtım değildir.
- `storage-audit.sh`: üç pod'un gerçek mount kaynakları, PVC eşlemesi ve metadata kimliğini salt-okunur denetler. Eski storage düzeninde FAIL dönmesi beklenen güvenlik engelidir.
- `deploy.sh`: Helm install/upgrade ve readiness bekler. Başarısız kurulumda kaynakları teşhis için bırakır; PVC silmez.
- Smoke testi gerçek topic oluşturur, mesaj yazar/okur ve ISR kontrol eder. Restart testi bir pod'u silip yeniden oluşmasını bekler, metadata ve mesaj kalıcılığını kontrol eder; geri gelen cluster'a yeni mesaj da yazar.
- Test topic'leri bilerek bırakılır, mesaj retention'ı bir saattir. Topic isimleri rapordadır; topic nesneleri otomatik silinmez.

Mevcut Bitnami `values/` dosyalarını bu chart'a vermeyin. Replica sayısı/cluster adı/namespace/domain sonradan değiştirilemez; yeni izole release ve boş storage gerekir. Manuel scriptler yalnız eşleşen `kafka-lab` veya `kafka-secure` release/namespace çiftlerini destekler.

## 5. Ayrı secure profil

Secure profil mevcut `kafka-lab` kümesini yükseltmez; yeni namespace, cluster-ID ve PVC'ler kullanır. Önce custom image'i Docker/Buildx ve GHCR oturumuyla manuel yayımlayın:

```bash
bash images/kafka-jmx/build-and-push.sh
docker buildx imagetools inspect ghcr.io/ahmettdgn/kafka-jmx:4.0.2-jmx-1.6.0
```

Çıktıdaki multi-arch manifest digest'ini not edin. Ardından root olarak secure namespace/RBAC/config dosyalarını ve harici test Secret'larını oluşturun:

GHCR package public değilse önce namespace'te bir registry pull Secret oluşturup `image.pullSecrets` alanına yalnız Secret adını yazın; registry token'ını values veya rapora koymayın. Public package kullanılması laboratuvar için daha basit varsayımdır.

```bash
sudo env DEPLOY_USER="$(id -un)" LAB_FIREWALL_CONFIRMED=true \
  bash scripts/contabo/bootstrap.sh --profile secure --install
sudo env DEPLOY_USER="$(id -un)" \
  bash scripts/contabo/prepare-secure-secrets.sh kafka.example.com
sudoedit /etc/kafka-kraft/secure-values.yaml
```

`kafka.example.com`, gerçek sunucu DNS adıyla; örnek digest gerçek GHCR manifest digest'iyle; `203.0.113.10/32` yalnız güvenilen gerçek istemci CIDR'siyle değiştirilmelidir. DNS sunucu IP'sine çözülmeden ve Contabo/UFW üzerinde 31092–31094 yalnız bu CIDR'ye izinli olmadan deploy etmeyin. Script firewall değiştirmez. Üretilen CA test amaçlı ve bir yıl geçerlidir; production PKI değildir.

Normal deploy kullanıcısıyla:

```bash
bash scripts/contabo/deploy.sh --config /etc/kafka-kraft/secure-deploy.env --check
bash scripts/contabo/deploy.sh --config /etc/kafka-kraft/secure-deploy.env
bash scripts/lab/smoke-test.sh --config /etc/kafka-kraft/secure-deploy.env
bash scripts/lab/smoke-test.sh --config /etc/kafka-kraft/secure-deploy.env --restart
```

Smoke testi doğru admin ve application kimliklerini, yanlış parola reddini, ACL'siz principal reddini, JMX endpoint'ini, topic/mesaj akışını ve restart kalıcılığını denetler. Secret içeriğini veya `/etc/kafka-kraft/secure-deployer.kubeconfig` dosyasını rapora koymayın.

## 6. Sonraki güncellemeler

```bash
git status --short
git pull --ff-only origin main
git rev-parse HEAD
bash scripts/validate.sh
bash scripts/contabo/deploy.sh --check
bash scripts/contabo/deploy.sh
bash scripts/lab/smoke-test.sh
```

Git pull dosyaları getirir; **deploy komutuna kadar cluster değişmez**. Deploy kirli checkout'ı reddeder. Sunucu ayarlarını repo dışında `/etc/kafka-kraft/lab-values.yaml` içinde `sudoedit` ile düzenleyin; override değişikliklerini hassas veri olmadan raporlayın.

## 7. Teşhis ve geri alma

```bash
export KUBECONFIG=/etc/kafka-kraft/deployer.kubeconfig
kubectl get pods,pvc,svc -n kafka-lab
kubectl get events -n kafka-lab --sort-by=.lastTimestamp
kubectl logs kafka-lab-0 -n kafka-lab -c kafka --tail=100
helm history kafka-lab -n kafka-lab
```

Doğrulanmış önceki Helm revision'ına dönmek için `REVISION` yerine history'deki numarayı yazın:

```bash
helm rollback kafka-lab REVISION -n kafka-lab --wait --timeout 15m
bash scripts/lab/smoke-test.sh
```

Rollback Kafka storage formatını/verisini geri almaz; Kafka sürüm düşürme işlemini körlemesine yapmayın. İlk kurulum başarısızsa eski revision yoktur; logları inceleyip aynı kimlik/PVC ile düzeltme deploy'u yapın. Git kaynağında geri alma için incelenmiş revert commit'i kullanın; checkout ile çalışan revision farkını rapora yazın.

**PVC, namespace veya cluster-ID Secret'ını silmeyin; `k3s-uninstall.sh` çalıştırmayın.** Helm uninstall PVC'leri Retain nedeniyle bırakır; namespace silmek ise PVC'leri de siler. Local-path PV reclaim politikası nedeniyle PVC silinmesi veriyi kalıcı kaybettirebilir. Eksik cluster-ID + mevcut PVC durumunda script durur: güvenli yedekten kimliği geri yükleyin; yeni ID üretmeyin.

K3s ve PV verisi için ayrı, doğrulanmış yedekleme gereklidir. Bu paket production yedekleme/migration otomasyonu içermez. ServiceAccount credential rotasyonu gerektiğinde admin olarak token Secret'ını yenileyip bootstrap'ı tekrar çalıştırın; Kafka cluster-ID Secret'ına dokunmayın.

## Henüz doğrulanmamış olanlar

0.1.0 için kullanıcı çıktıları kalıcılık hatasını doğruladı; temiz 0.2.0 deploy ve restart kalıcılık kabulü daha sonra geçti. 0.3.0 secure profil yalnız offline doğrulanmıştır. Custom multi-arch image/CVE taraması ve gerçek `kafka-secure` deploy sonuçlarını `IMPLEMENTATION-REPORT.md` ile `/var/log/kafka-secure` raporlarına ayrıca kaydedin.
