# Uygulama raporu

## GÜNCEL DURUM — 2026-08-31 21:45 UTC

Önceki bölümler kronolojik tarihsel kayıttır. 0.1.0 restart kalıcılık testi başarısız olduktan sonra kullanıcı eski test verilerinin silinmesini açıkça onayladı. Kontrollü sıfırlama ve temiz chart 0.2.0 kurulumu tamamlandı. Üç pod'un exact PVC mount/metadata audit'i, KRaft quorum, topic, producer/consumer, pod 0 replacement, aynı PVC/kimlikler, restart sonrası eski mesaj okuma ve yeni mesaj yazma testleri **GEÇTİ**. Çalışan Helm release `kafka-apache-lab-0.2.0`, revision 1'dir. Ayrıntılı son kanıt raporun en altındaki 21:40 ve 21:45 UTC bölümlerindedir.

- 10:56–10:57 UTC: üç pod Running, üç PVC Bound, quorum/mesajlaşma başarılı (kullanıcının paylaştığı kanıt; ajan sunucuya bağlanmadı).
- 11:05 UTC restart testi FAIL; yeni pod logunda `Formatting metadata directory /var/lib/kafka/data` görüldü. Üç mesajın okunması diğer replikaların varlığı nedeniyle pod-local kalıcılık kanıtı değildir.
- Mountinfo kök nedeni doğruladı: PVC `/var/lib/kafka` üzerinde, gerçek Kafka dizini `/var/lib/kafka/data` ise containerd `containers/<id>/volumes/<id>` kaynağı üzerinde. Kimlik/hash ve hosta özel uzun ID'ler rapora kopyalanmadı.
- Hata sorumluluğu: ilk chart, Apache image-defined child volume ile PVC ancestor mount çakışmasını ele almıyordu. Eski offline testler bu runtime davranışını modellemiyordu. PVC Bound/render PASS verinin gerçekten PVC'ye yazıldığını kanıtlamaz.
- Kullanıcı düzeltme, detaylı chart/çakışma denetimi, Markdown raporu ve daha sonra disposable eski lab verilerinin silinmesini onayladı. Veri taşıması yapılmadı; yalnız onaylanan üç eski Kafka PVC'si kontrollü olarak kaldırıldı.
- İncelenen resmi kaynaklar: [Apache image VOLUME](https://github.com/apache/kafka/blob/4.0.2/docker/jvm/Dockerfile), [containerd tam yol eşleme](https://github.com/containerd/containerd/blob/main/internal/cri/server/helpers.go), [containerd image volumes](https://github.com/containerd/containerd/blob/main/docs/cri/config.md), [StatefulSet update davranışı](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).

## 2026-08-31 — Başlangıç ve kapsam

- Amaç: mevcut Bitnami chart'ını koruyarak bağımsız Apache Kafka KRaft laboratuvar chart'ı, Ubuntu/K3s kurulumu ve GitHub otomasyonu hazırlamak.
- Yerel `main` başlangıcı: `8e51b1a`; çalışma ağacı temiz. `origin`: `https://github.com/AhmettDgn/KafkaKRaft.git`.
- İnceleme: `git status --short`, `rg --files`, mevcut bootstrap/deploy/workflow dosyalarının okunması. Özel chart henüz yok; kökte Bitnami chart bulunuyor.
- Bulunan sorunlar: deploy yapılandırması için root-only izinler; K3s kurulumunun bulunmaması; eksik secret'larda koşulsuz SSH denemesi; Helm'e yalnız eksik ortam values verilmesi; dağıtımın eski chart'ı hedeflemesi.
- Bu rapor her anlamlı aşamada güncellenecek. Secret, private key, token ve kubeconfig içeriği kaydedilmeyecek.

## Doğrulama durumu

İlk chart lint/render ve Bash sözdizimi kontrolleri geçti. Render, container çalıştırma ve gerçek Kubernetes/Contabo sonuçları ayrı raporlanacak.

## 2026-08-31 — Image ve chart

### Kapsam değişikliği: GitHub otomasyonu kaldırıldı

Kullanıcının yeni talebiyle GitHub Actions, push ile otomatik SSH/dağıtım ve GitHub Secrets kurulumu kapsam dışıdır. Önceden var olan `.github/workflows/validate-and-deploy.yml` kaldırıldı. GitHub yalnız kaynak deposu olacak; Ubuntu kurulumu, git pull, deploy ve testler kullanıcı tarafından elle çalıştırılacak. Önceki otomasyon talimatları yeni rehberle geçersiz kılınacaktır.

- `docker buildx imagetools inspect apache/kafka:4.0.2`: OCI index digest `sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f`; linux/amd64 ve linux/arm64 doğrulandı. unknown/unknown girdileri attestation manifestleridir.
- Resmi release API kontrolleri: Helm `v3.21.4`, K3s `v1.36.4+k3s1`. Sürümler `deploy/contabo/versions.env` içinde sabitlendi.
- İlk ağ/registry çağrıları sandbox erişim engeline takıldı; izinli tekrarda doğrulama başarılı. Yerel Docker daemon çalışmıyor; container testi henüz yapılmadı.
- `python tests/test_chart.py`: 4 test grubu geçti (render sözleşmesi, tek node/storage override, geçersiz values reddi, Secret override).
- `bash tests/startup.sh`: 8 davranış kontrolü geçti; Kafka araçları mock edildi. Gerçek Kafka runtime testi değildir. Windows Git Bash ilk denemede Unix araçlarını PATH'te bulamadı; `/usr/bin:/bin` eklenerek test tekrarlandı ve geçti.
- `lab/kafka-apache`: bağımsız Chart/values/schema, StatefulSet, iki Service, ConfigMap, PDB ve NetworkPolicy eklendi. Image digest sabit; Bitnami helper/image yok.
- `start.sh`: static quorum, boş data dizininde ilk format, mevcut cluster/node/directory metadata kontrolü, topoloji kaydı, doğrudan Apache server başlangıcı. Cluster ID dışarıdan kalıcı Secret ile sağlanır.
- `.gitattributes`: Linux scriptleri ve YAML için LF; binary arşivler korunuyor.
- Komutlar: `helm lint lab/kafka-apache --strict`, `helm template kafka-lab lab/kafka-apache -n kafka-lab`, `bash -n lab/kafka-apache/files/start.sh` — geçti. İlk yerel Helm `v3.17.0`; Ubuntu kurulum sürümü ayrıca sabitlenmiştir. CI yoktur.
- Kaynaklar: [Apache KRaft](https://kafka.apache.org/40/operations/kraft/), [K3s kurulum](https://docs.k3s.io/installation/configuration), [K3s erişim](https://docs.k3s.io/cluster-access). Static quorum seçimi yalnız yeni laboratuvar cluster'ı içindir; in-place ölçekleme/migration desteklenmez.

## 2026-08-31 — Manuel Ubuntu kurulumu ve erişim

- `scripts/contabo/preflight.sh`: Ubuntu/systemd, mimari, CPU/RAM/disk, port ve mevcut Kubernetes kontrolleri. Başka kurulumu tespit ederse durur; firewall kapatılmaz.
- `scripts/contabo/bootstrap.sh`: sabit sürümlü K3s/Helm; K3s installer SHA-256 ve araç checksum doğrulaması. Root yalnız kurulumda kullanılır. Değişik sürümde mevcut araç/servis otomatik ezilmez.
- `deploy/contabo/lab-access.yaml`: yalnız `kafka-lab` namespace Role/RoleBinding, restricted Pod Security; pod'lara API token mount edilmez. Deploy kubeconfig root:deploy-group `0640`, dizin `0750`; admin kubeconfig paylaşılmaz. Uzun ömürlü namespace ServiceAccount token'ı yalnız sunucuda saklanır; production için uygun credential yaşam döngüsü yerine geçmez.
- `scripts/lab/create-cluster-id.sh`: mevcut Secret korunur. Secret eksik fakat PVC varsa yeni kimlik üretmeyerek geri yükleme ister.
- `scripts/contabo/deploy.sh`: geçerli checkout SHA'sını kaydeder, kirli checkout'ı reddeder; kilit, lint/render/vendor taraması ve API server dry-run sonrası elle Helm deploy. Başarısız ilk kurulumda teşhis için kaynaklar/PVC tutulur; `--atomic` kullanılmaz. Açık geri alma adımları rehberdedir.
- Deploy ve smoke çıktıları sunucuda `/var/log/kafka-lab/*.md` dosyalarına kaydedilir. Secret/kubeconfig gövdeleri çıktılanmaz. Dosya kopyasında Git yoksa revision `unversioned` olarak belirtilir; SHA doğrulandığı iddia edilmez.
- `scripts/lab/smoke-test.sh`: topic, RF/ISR, sıralı producer/consumer, quorum çıktısı, isteğe bağlı pod yenileme, değişmeyen metadata, eski mesaj okuma ve yeni mesaj yazma kontrolleri hazırlandı. Bu script henüz gerçek Kubernetes üzerinde çalıştırılmadı.
- `.github/workflows/validate-and-deploy.yml` kullanıcı talebiyle kaldırıldı; eski GitHub Secrets/SSH rehberi manuel rehberle değiştirildi. Sunucuya deploy için artık push yeterli değildir.
- Yeniden çalıştırılan yerel kontroller: bütün yeni `.sh` dosyalarında `bash -n`, `bash tests/startup.sh`, `python tests/test_chart.py`, `helm lint lab/kafka-apache --strict` başarılı. Helm yalnız öneri seviyesinde icon mesajı verdi.

## 2026-08-31 — Son yerel denetimler

- `scripts/validate.sh` bütün offline kontrolleri tek manuel komutta toplar. GitHub workflow oluşturulmadı. Kullanılmayan Kind kurulum seçeneği/sürümü kaldırıldı.
- Resmi Helm `v3.21.4` Windows arşivi `artifacts/tools` altına indirildi. SHA-256 `268a7b98b313403055e4f31807aeaac529c90e1188acd7857ae3e960b0f67cce`, resmi checksum ile eşleşti. `helm version --short`: `v3.21.4+g813176c`. Test arşivleri/binary'leri Git'e eklenmez.
- ShellCheck `v0.11.0` resmi GitHub release'inden alındı. İlk denetimde smoke scriptinin inline ERR trap'inde SC2154 uyarısı çıktı. Ayrı EXIT fonksiyonuna çevrildi; açık `exit 1` durumları da artık raporlanıyor. Son denetim uyarısız geçti.
- Komut: `shellcheck --external-sources --source-path=SCRIPTDIR <yeni sh dosyaları>` — geçti.
- Komut: `HELM_BIN=<v3.21.4 helm> PYTHON_BIN=python bash scripts/validate.sh` (Git Bash PATH `/usr/bin:/bin` ile) — geçti. Python 6 test grubu; startup 8 davranış kontrolü; cluster-ID 4 davranış kontrolü. Bunlar mock/offline testlerdir.
- `tests/cluster-id.sh`: Secret varken koruma, boş kurulumda üretim, eski PVC varken ret, API hatasında ret. Gerçek kubeconfig kullanılmaz.
- `tests/test_chart.py`: RBAC'ın yalnız namespace kapsamı, restricted Pod Security, sunucu values render'ı, LF satır sonları ve workflow bulunmaması da kontrol edildi.
- Registry image config denetimi: amd64/arm64, Java 21, `appuser`, `/opt/kafka` dağıtımı ve Bash varlığı image metadata/build history'de görüldü. Chart Apache'nin container otomatik-config girişini atlayıp kendi korumalı start scriptini çalıştırır. Bu inceleme container çalıştırıldığı anlamına gelmez.
- Son güvenlik incelemesi: primary grubunda başka kullanıcı varsa bootstrap kubeconfig paylaşmadan durur; rapor dosya isimlerine PID eklendi; smoke testine tam ISR dönüşü ve restart sonrası yeni yazı/okuma eklendi.
- `git diff --check` geçti. Push öncesi `git ls-remote origin refs/heads/main`: başlangıç SHA'sı ile aynı (`8e51b1a1098199f33c6d60e47db36fae4ee01c55`). Kökteki mevcut chart template/values dosyaları değiştirilmedi; yalnız paket dışlama listesi ve belge girişleri güncellendi.

### Test durumları

| Kontrol | Durum | Kapsam |
| --- | --- | --- |
| OCI digest/mimari/config | Geçti | Registry erişimi; runtime değil |
| Helm 3.17.0 ve 3.21.4 lint/render | Geçti | Yerel Windows |
| Render/schema/RBAC/LF/otomasyonsuz repo testleri | Geçti | 6 Python test grubu |
| Storage başlangıç korumaları | Geçti | 8 mock davranış kontrolü |
| Cluster-ID korumaları | Geçti | 4 mock davranış kontrolü |
| Bash syntax / ShellCheck | Geçti | Son sürümde uyarı yok |
| Ubuntu bootstrap / Linux binary çalıştırma | Çalıştırılmadı | Hedef sunucu erişimi yok |
| API server dry-run / gerçek Helm deploy | Çalıştırılmadı | Kubernetes erişimi yok |
| PVC sahipliği, image pull, pod health | Çalıştırılmadı | Gerçek cluster gerekli |
| Quorum / topic / producer-consumer / restart | Çalıştırılmadı | Gerçek Kafka gerekli |
| Image zafiyet taraması | Çalıştırılmadı | Güvenlik onayı iddia edilmez |
| Push sonrası otomatik dağıtım | Kapsam dışı | Kullanıcı GitHub otomasyonunu istemiyor |

### Kalan işler ve geri alma

- Kullanıcı Contabo firewall'ını kısıtlayıp [manuel rehberi](deploy/contabo/README.md) uygulamalı. Benden sunucu testi istenirse host/SSH portu/kullanıcı ve güvenli SSH erişim yetkisi gerekir; private key veya parola rapora/mesaja konmamalı.
- Sunucuda çalışan revision: **yok / henüz dağıtım yapılmadı**. Yerel render başarısı deploy başarısı olarak gösterilmedi.
- Sunucu komutlarının gerçek sonuçları `/var/log/kafka-lab/*.md`; ilk bootstrap çıktısı isteğe bağlı `artifacts/bootstrap.log`. Bunlar henüz oluşmuş sunucu kanıtları değildir.
- Geri alma: doğrulanmış önceki `helm history` revision'ına manuel `helm rollback`; ilk install hatasında önceki revision yoktur. Kafka downgrade/veri formatı ayrıca incelenmeli. PVC/namespace/cluster-ID silinmemeli, K3s uninstall çalıştırılmamalı. Kaynak değişiklikleri incelenmiş Git revert ile geri alınabilir; otomasyon dosyasını geri getiren toplu revert kullanıcı isteğini tersine çevirir.
- GitHub'a kaynak commit/push sonucu aşağıda ayrıca kaydedilecek; push sunucuda komut çalıştırmaz.

## 2026-08-31 — Git hazırlığı

- `git add -A`, ardından yalnız yeni/güncellenen 10 shell scripti için `git update-index --chmod=+x` uygulandı. `git ls-files --stage` bu dosyaları `100755` gösterdi; dosya kopyası için rehberde `bash` yöntemi de var.
- `git diff --cached --check` geçti. 34 dosyada değişiklik var; eski workflow silinmesi bu sayıya dahil. Kökteki `Chart.yaml`, `Chart.lock`, `templates`, `charts`, `values` için staged diff boş.
- Staged metinlerde private-key başlığı, yaygın GitHub token ve AWS access-key kalıpları yalnız dosya adı döndüren denetimle tarandı: eşleşme yok. Bu dar kapsamlı kontrol tam bir secret tarayıcısı yerine geçmez. Gerçek credential dosyası eklenmedi; `artifacts/` dışlandı.

## 2026-08-31 — Commit ve GitHub sonucu

- Uygulama commit'i: `1f96f622ed1e08b4c392949c2090c8a52aff054b` — `Add standalone Apache Kafka lab and manual Ubuntu deployment`.
- `git push origin main` başarılı: `8e51b1a..1f96f62 main -> main`. Ardından `git ls-remote origin refs/heads/main` yukarıdaki tam SHA'yı döndürdü; GitHub'a gönderim doğrulandı.
- Commit sonrası çalışma ağacı temizdi. Bu bölüm ayrı, yalnız rapor içeren takip commit'inde tutulur; rapor commit'inin kendi SHA'sı `git log -1 --format=%H -- IMPLEMENTATION-REPORT.md` ile okunabilir.
- GitHub Actions workflow'u bu uygulama commit'inde kaldırıldı. Push sonrası SSH/deploy çalıştırılmadı; sunucuda çalışan revision hâlâ **yok / test edilmedi**.
- Sonuç: yerel geliştirme, offline doğrulama ve kaynakların GitHub'a gönderimi tamamlandı. Gerçek Ubuntu/K3s/Kafka testleri erişim ve izin sağlandıktan sonra yapılacak; production uygunluğu onaylanmadı.

## 2026-08-31 — Kalıcılık düzeltmesi ve ayrıntılı çakışma denetimi

Önceki "sunucuda test edilmedi" kayıtları ilk teslim anına aittir. Kullanıcı sonraki mesajlarda bootstrap (exit 0), 0.1.0 deploy ve smoke başarısını, restart FAIL ve mountinfo kanıtını paylaşmıştır. Güncel canlı durum eski 0.1.0 kaynak `0747716` / Helm revision 1'dir; yeni kod henüz orada çalıştırılmadı.

### Değiştirilen alanlar ve amaç

- `lab/kafka-apache/Chart.yaml`: chart 0.2.0; Kafka image/tag/digest değişmedi.
- `templates/statefulset.yaml`: PVC exact `/var/lib/kafka/data`; Kafka `/var/lib/kafka/data/kraft`. Diğer iki image VOLUME readonly emptyDir ile açık tanımlandı. `minReadySeconds=30`; identity/layout annotation'ları. Eksik StatefulSet'li upgrade ve eski PVC'li fresh install için guard.
- `templates/_helpers.tpl`: legacy layout'a upgrade ret; immutable namespace/release/quorum/Secret/domain/PVC size/class imzası. Eski annotation'ı elle değiştirerek bu kontrolün aşılmaması rehberde belirtildi.
- `files/start.sh`: format öncesi exact mount, container-local root, nested mount, symlink denetimi. Log dizini dışındaki PVC root marker, daha önce initialized volume'da metadata kaybının yeni formatla gizlenmesini engeller. Marker ilk format niyeti öncesinde yazılır; yarım format sonrası otomatik tekrar denemek yerine inceleme gerekir.
- `scripts/lab/storage_audit.py` ve `storage-audit.sh`: read-only üç-pod mount/PVC/effective log.dirs/metadata denetimi; `--inspect` eski layout'ta da mount kanıtını toplar fakat FAIL döner. Snapshot'larda credential/cluster ID gövdesi değil kimlik hash'i tutulur. K3s local-path kaynak dizini Bound PV adıyla eşleştirilir.
- `scripts/contabo/deploy.sh`: Helm mutation öncesi storage audit/legacy ret; rollout sonrası tekrar audit. `--check` eski kurulumu değiştirmeden reddeder.
- `scripts/lab/smoke-test.sh`: default context'e sessiz düşüş kaldırıldı. Audit başarısızsa topic/pod mutation başlamaz. Restart öncesi/sonrası üç pod'un semantik storage kimliği, PVC UID/PV ve mount kaynağı karşılaştırılır. Yorum/timestamp farkı göz ardı edilir, directory/cluster/node ID değişimi reddedilir; FAIL checkpoint'i görünür.
- `tests/test_storage.py`, image volume fixture ve startup testleri eklendi/genişletildi. Mock kubectl akışı API hatası/eski layout/kalmış PVC durumlarının ilk aşamada reddini ve üç-pod snapshot karşılaştırmasını doğrular.
- `CHART-AUDIT.md`: önem dereceleriyle 9 bulgu, image/mount/RBAC/DNS/probe/update/Bitnami birlikte bulunma incelemesi; sınırlar ve artık riskler.
- `deploy/contabo/STORAGE-RECOVERY.md`: salt-okunur envanter, tutarlı yedek/restore kapısı, broker bazlı hedef düzeni, kontrollü replacement kabul kriterleri ve yasak/tehlikeli işlemler. **Çalıştırılabilir otomatik canlı veri taşıma scripti yazılmadı**; sağlıklı yedek ve hosta özel durdurma/GC koşulları bilinmeden güvenli olduğu iddia edilemez.
- Ana/Contabo/chart README dosyalarına eski cluster için deploy/restart uyarısı ve güncel test durumu eklendi. `.helmignore` yeni audit raporunu eski chart paketinden dışlar. Eski Bitnami template/values dosyaları korunur; GitHub otomasyonu eklenmedi.

### Komutlar, sonuçlar ve hatalar

| Komut / kontrol | Sonuç |
| --- | --- |
| `docker buildx imagetools inspect apache/kafka:4.0.2 --format '{{json .Image}}'` | İzinli registry okuması: amd64/arm64 üzerinde aynı 3 VOLUME yolu, appuser; fixture/sözleşme ile uyumlu |
| `shellcheck --external-sources --source-path=SCRIPTDIR <sh dosyaları>` | Geçti, uyarı yok |
| `HELM_BIN=<Helm 3.21.4> PYTHON_BIN=python bash scripts/validate.sh` | Geçti: 6 render + 10 storage Python testi; 12 startup senaryosu + 4 cluster-ID senaryosu; Bash syntax |
| `helm package lab/kafka-apache --destination artifacts` | Geçti; 0.2.0 paketi yalnız ignored artifacts altında |
| `helm lint artifacts/kafka-apache-lab-0.2.0.tgz --strict` | Geçti; yalnız öneri seviyesinde icon mesajı |
| `helm template kafka-lab artifacts/kafka-apache-lab-0.2.0.tgz -n kafka-lab --output-dir artifacts/packaged-render` | Geçti; paket içi startup/config/template çözümü doğrulandı |
| `helm lint . -f values-template.yaml --strict` | Eski kök Bitnami chart için geçti; kökte values.yaml yok INFO mesajı, açık values-template kullanıldı. Production deploy kanıtı değil |
| `git diff --check` | Geçti |
| `docker version --format '{{.Server.Version}}'` | Başarısız: Docker daemon named pipe yok. İlk sandbox denemesinde config erişimi de engelliydi; izinli tekrarda da daemon yok. Gerçek container/K3s testi yapılmadı |

Testler önce küçük grup (7 storage testi), sonra fake API/snapshot akışı eklenerek 10 storage testiyle tekrarlandı; ikisi de geçti. Doğrulanmamış sunucu taşıması, CSI alternatifleri, load/CVE taraması ve yeni chart restart testi PASS olarak gösterilmedi.

### Şu anki teslim ve kalan iş

- Kod düzeltmesi ve offline denetim tamamlandı. Mevcut canlı release tehlikeli layout'ta kalmaya devam ediyor; dosyaları pull etmek onu düzeltmez.
- Kullanıcıdan gereken sonraki güvenli çıktı: `bash scripts/lab/storage-audit.sh --inspect` (üç broker). Eski layout için FAIL beklenir; bu bir güvenlik engelidir.
- Snapshot/yedek olanağı, korunacak veriler ve bakım aralığı doğrulanmadan veri taşıma/replacement yapılmayacak. PVC/Secret silmek, raw helm rollback, toplu restart veya containerd cleanup önerilmedi.
- Sunucuda bu tur hiçbir komut çalıştırılmadı. Sunucu kanıtları kullanıcı tarafından paylaşılmıştır; yeni fixture'lar sentetik/mock kanıttır, gerçek mount testi değildir.

### Düzeltme commit/push kanıtı

- Commit: `92b8d6bb08e9972f171125d7f1546e6d85726d07` — `Fix Kafka PVC shadow mounts and gate legacy storage upgrades` (19 dosya).
- `git push origin main`: başarılı, `0747716..92b8d6b main -> main`. `git ls-remote origin refs/heads/main` tam SHA ile eşleşti.
- `storage-audit.sh` Git executable mode `100755`; Python dosyası interpreter ile çalıştırılır. Staged diff whitespace denetimi geçti; eski root Chart/lock/templates/values için diff yok.
- Staged dosyalar private-key başlığı ve yaygın GitHub/AWS token kalıplarıyla, yalnız dosya adları gösterecek şekilde tarandı: eşleşme yok. Tam secret/security scan yerine geçmez. Test tool/paket/render çıktıları ignored artifacts dizininde kaldı.
- Bu son sonuç kaydı ayrı dokümantasyon commit'idir; kendi SHA'sı Git history'den okunur. GitHub otomasyonu hâlâ yoktur; push sunucuda dağıtım veya veri taşıma çalıştırmadı.

## 2026-08-31 — Staj roadmap gereksinimlerine uyarlama

### Amaç ve kanıt sınırı

Kullanıcının “A Stajyeri 2. Staj - Hafta 1 Roadmap” belgesi tamamen okundu; istenen araştırma, alternatif karşılaştırması, values deneyi, gerçek deploy/test notları ve final demo dosyaları repo ile eşleştirildi. Kullanıcı sunucuda `git pull` ile 0c0c5ce'ye geçtiğini ve `storage-audit.sh --inspect` çıktısında üç pod'un da legacy shadow mount nedeniyle FAIL olduğunu bildirdi. Bu sonuç yeni chart'ın dağıtıldığı anlamına gelmez: son bildirilen çalışan release hâlâ kaynak 0747716 / chart 0.1.0 / Helm revision 1.

Bu tur gerçek Kafka chart template'i veya sunucu konfigürasyonu değiştirilmedi. Eski verinin korunması/silinmesi seçimi cevaplanmadığından herhangi bir recovery, restart, PVC silme veya sunucu deploy komutu çalıştırılmadı. GitHub otomasyonu eklenmedi.

### Anlamlı işlemler ve değiştirilen dosyalar

1. `ROADMAP-COMPLIANCE.md`: Gün 1–5 teslim matrisi, mentor kontrol listesi ve eksikler. Roadmap başarısız denemenin teknik açıklamasını kabul ediyor; ideal başarılı kalıcılık hâlâ bekliyor. Ekran görüntüsü eksikliği nedeniyle yüzde 100 teslim iddiası yok.
2. `kafka-kraft-bitnami-image-research/README.md`: tarihsel “deploy yapılmadı / custom image hedefi” metni güncel final araştırma girişine dönüştürüldü; eski başarılı 0.1.0 testleri, restart FAIL ve 0.2.0 canlı doğrulama eksikliği ayrıldı.
3. `chart-analysis/kraft-architecture.md`: ZooKeeper/KRaft, broker/controller, single-host sınırı ve gerçek `git ls-files lab/kafka-apache` komut çıktısı. `image-dependencies.md`: vendored common ile registry kaynağı ayrımı düzeltildi. `bitnami-usage-points.md`: statik beklenen init hatası gerçek çalıştırılmış hata gibi sunulmadı; sınırlı demo kapsamı netleştirildi.
4. `alternatives/image-comparison.md`, `manifest-evidence.md`, `security-evaluation.md`, `selected-image-decision.md`: beş yayıncı alternatifi + custom + Docker Official Images değerlendirmesi; lisans, güvenilir kaynak, mimari, güncelleme/CVE, KRaft, StatefulSet, command/env/path uyumu. Confluent kafka-images Apache-2.0 lisansı bütün platforma genellenmedi. Red Hat ürün matrisi somut image manifesti sayılmadı.
5. `helm-values/image-only-override.yaml`: orijinal chart için yalnız offline negatif deney. `non-bitnami-values.yaml`: eski hayalî kurum-image taslağı yerine gerçek bağımsız chart values. `diff-notes.md`: iki deneyin hedefleri ve command/args/env/UID/PVC farklılıkları.
6. `tests/helm-template-output.md`: iki gerçek render/lint deneyi ve literal bağımlılık sayıları. `deploy-notes.md`, `producer-consumer-test.md`, `topic-management-test.md`: kullanıcının paylaşılmış terminal kanıtları esas alınarak güncellendi; topic create/describe, 1→3 partition, üç mesaj ve başarısız restart ayrı durumlar.
7. `DEMO-NOTES.md`: yaklaşık altı dakikalık sunum, güvenli offline demo ve yalnız read-only legacy gözlem komutları. `screenshots/README.md`: istenen gerçek ekran görüntüleri ve eksik durumları; sentetik ekran görüntüsü oluşturulmadı.
8. `tests/test_roadmap.py`: teslim dosyaları/yerel linkler, root negatif image-only deneyi ve gerçek yeni values/PVC/image sözleşmesi için üç test. `scripts/validate.sh` bunları çalıştırır. Root README giriş linkleri ve `.helmignore` rapor dışlaması eklendi. `original-values.yaml` orijinal referans alt kümesi olarak korundu.

### Araştırma komutları ve sonuçlar

| Komut / kaynak kontrolü | Sonuç |
| --- | --- |
| `docker buildx imagetools inspect confluentinc/cp-kafka:8.2.0` | GEÇTİ; amd64 ve arm64/v8, index digest ve alt manifestler manifest-evidence.md içinde |
| `docker buildx imagetools inspect quay.io/strimzi/kafka:0.47.0-kafka-4.0.0` | GEÇTİ; amd64/arm64/ppc64le/s390x; örnek eski tag, en güncel/güvenli iddiası yok |
| `docker buildx imagetools inspect cgr.dev/chainguard/kafka:latest` | BAŞARISIZ: anonim token 403; yayıncı yetkili organization yolu istiyor. Mimari/digest uydurulmadı |
| `gh api repos/docker-library/official-images/contents/library` + kafka adı filtresi | Sonuç `[]`; library/kafka girdisi bulunmadı. ASF resmi image, Docker Official Images programından ayrıldı |
| ASF CVE, Confluent lisans/Docker, Strimzi security, Red Hat ürün matrisi, Chainguard kullanım/provenance sayfaları | Birincil kaynaklar incelendi ve ilgili araştırma belgelerinde URL ile gösterildi. CVE-2026-35554 için 4.0.2 düzeltme örneği, tüm image'ın güvenli olmasıyla eşitlenmedi |
| Apache image digest/mimarisi | Önceki registry/config doğrulaması yeniden kullanıldı; bu tur image/digest değiştirilmedi |

Registry/ağ erişimi gereken sandbox denemeleri izinli tekrarla yürütüldü; credential içerikleri rapora eklenmedi. Gerçek vulnerability scanner, SBOM üretimi ve signature verification bu tur çalıştırılmadı. Değerlendirme güvenlik onayı değildir.

### Test hatası ve düzeltmesi

Yeni roadmap testinin ilk çalıştırması bir FAIL ve bir ERROR verdi: test, root common helper'ın `tag@digest` render edeceğini ve yeni lab image değerinin ayrı `registry` anahtarı içerdiğini varsaymıştı. Gerçek sözleşme root'ta `repository@digest`, lab'da registry dahil tam `repository` idi. Test beklentileri kaynaktaki iki farklı şemaya göre düzeltildi; chart'a bu nedenle değişiklik yapılmadı. Sonraki üç testin tamamı geçti. İlk assertion çıktısındaki sentetik render/Secret değerleri rapora taşınmadı.

### Son doğrulama durumları

| Test / komut | Sonuç |
| --- | --- |
| `helm lint . --strict -f values-template.yaml -f kafka-kraft-bitnami-image-research/helm-values/image-only-override.yaml` | GEÇTİ; yalnız values.yaml yok INFO |
| Aynı root chart/values ile `helm template` | GEÇTİ; `/opt/bitnami` 4, `libkafka.sh` 1, `KAFKA_CFG_` 1 literal occurrence. Bu beklenen negatif uyumluluk bulgusudur |
| Yeni lab chart + non-bitnami-values lint/render | GEÇTİ; tam image/digest, 3 replika, exact PVC mount ve 5Gi local-path doğrulandı; yasaklı Bitnami path/env/image eşleşmesi yok |
| `HELM_BIN=<Helm 3.21.4> PYTHON_BIN=python bash scripts/validate.sh` | GEÇTİ; 6 chart + 10 storage + 3 roadmap = 19 Python testi; 12 mock startup + 4 mock cluster-ID senaryosu; Bash syntax |
| `shellcheck --external-sources --source-path=SCRIPTDIR scripts/validate.sh` | GEÇTİ; bu tur değişen tek shell dosyası |
| `git diff --check` | GEÇTİ |
| Orijinal image-only deneyi canlı deploy | ÇALIŞTIRILMADI; statik uyumsuzluk gösterildi |
| 0.2.0 canlı deploy/mount/restart/producer-consumer | ÇALIŞTIRILMADI; güvenli geçiş için veri koruma/yedek veya ayrı test ortamı kararı gerekiyor |
| 0.1.0 canlı testler | Kullanıcı kanıtı: deploy/quorum/topic/mesajlaşma/partition artırma GEÇTİ; restart BAŞARISIZ |
| Ekran görüntüleri | EKSİK; gerçek terminal metni mevcut, görsel henüz sağlanmadı |
| CVE scanner / SBOM / signature / çift mimari runtime | ÇALIŞTIRILMADI; manifest kontrolü bunların yerine geçmez |

### Kalan işler ve geri alma

- Kullanıcıdan gerçek deploy/test ekran görüntüleri ve eski verilerin korunma gereksinimi bekleniyor. Gizli credential içeriği talep edilmiyor.
- Veri geçişi veya ayrı test ortamı onayı ve güvenli erişim sağlanınca 0.2.0'ın exact mount, metadata/PVC kimliği, restart sonrası eski okuma + yeni yazma kabulü yapılmalı. Geçiş kapıları STORAGE-RECOVERY.md içinde; guard devre dışı bırakılmamalı.
- Bu tur yalnız araştırma/values deney/test/rapor dosyaları değişti; sunucuda geri alınacak işlem yok. Kaynak düzeyinde incelenmiş ters diff/revert kullanılabilir. Önceki 0.2.0 storage koruması kaldırılmamalı; geniş revert ile otomasyon veya eski mount hatası geri getirilmemeli.
- Commit/push sonucu aşağıdaki takip kaydında tutulacak. Push sunucuda komut çalıştırmaz.

### Roadmap teslimi — Git sonucu

- Commit: `d3a1edee12404c290e9384deb7ddbd1238dc7415` — `Align internship roadmap research, evidence and values tests`; 23 dosya, 693 ekleme / 266 silme.
- `git push origin main` GEÇTİ: `0c0c5ce..d3a1ede main -> main`. Ardından `git ls-remote origin refs/heads/main` aynı tam SHA'yı döndürdü.
- Staged diff whitespace kontrolü geçti; `scripts/validate.sh` executable mode 100755 korundu. Eski root Chart/lock/templates/values ve yeni lab chart için staged diff yoktu.
- Staged dosyalarda private-key başlığı ve yaygın GitHub/AWS token kalıpları, yalnız dosya adı döndürecek şekilde tarandı: eşleşme yok. Bu sınırlı kontrol tam secret scanner değildir. Git'in sandbox içindeki kullanıcı ignore dosyası erişim uyarısı kontrol sonuçlarını değiştirmedi; izinli commit/push başarılı oldu.
- Sunucuya bu tur bağlanılmadı. Son bildirilen çalışan Kafka revision'ı 0747716 / Helm 1 olarak kalır; kaynak push'u deploy kanıtı değildir.
- Bu sonuç kaydı ayrı rapor commit'inde tutulur; rapor commit'inin SHA'sı Git history'den okunabilir. Gerçek ekran görüntüleri, veri koruma kararı ve 0.2.0 canlı kalıcılık testi hâlâ açık maddelerdir.

## 2026-08-31 — Sunucu testlerinin yeniden başlatılması: salt-okunur ön kontrol

- Kullanıcı testleri sunucuda kendisi çalıştırıp çıktıları paylaşmak istedi. Bu aşamada yalnız kaynak SHA/çalışma ağacı, Helm release, pod/PVC/StatefulSet/Service, üç-pod storage audit ve quorum durumunun okunması yönlendirildi.
- Mevcut `scripts/lab/storage-audit.sh`, `storage_audit.py` ve `deploy/contabo/STORAGE-RECOVERY.md` tamamen okunarak komutların mevcut arayüze uygunluğu kontrol edildi. Audit `--inspect`, legacy layout'ta kanıt toplar fakat çıkış 1 verir; bu beklenen güvenlik reddi başarılı kalıcılık testi sayılmaz.
- Sunucu komut bloğu her kontrolün çıkış kodunu ve UTC zamanını, repo altında `artifacts/server-check-<UTC>-<benzersiz>.md` dosyasına kaydeder. Gerçek kubeconfig veya Secret içerikleri yazdırılmaz. Kaynak SHA ile çalışan Helm chart/revision ayrı alınır; git pull veya push deploy olarak değerlendirilmez.
- Durum: **ÇALIŞTIRILMADI / kullanıcı çıktısı bekleniyor**. Ajan sunucuda komut çalıştırmadı. Bu kayıt test sonucu değil hazırlık kaydıdır; kullanıcı çıktıları geldikçe ayrı geçti/başarısız durumları eklenecek.
- Henüz deploy, smoke topic oluşturma, restart, rollback, silme veya veri taşıma yönlendirilmedi. Eski layout sürüyorsa önce korunacak veri ve güvenli geçiş kararı gerekir. Test yönlendirme talebi veri silme izni sayılmaz.
- Bu hazırlık kaydı yerel Markdown raporuna eklendi; bu aşamada yeni commit/push yapılmadı.

## 2026-08-31 12:30:30 UTC — Kullanıcı sunucu ön kontrol sonucu

### Kanıt ve kapsam

- Kullanıcı `artifacts/server-check-20260831T123030Z-CAHfug.md` çıktısını ve terminal dökümünü paylaştı. Mesaj gövdesinde bazı satırlar `>` ile kesilmişti; ekli metin tamamen okundu ve Helm chart sürümü, tam image digest'i, üç pod mount kaynakları ve üç quorum üyesi oradan doğrulandı. Ek dosyanın başındaki komut yapıştırma metni bozulmuş görünse de sonuç bölümleri ve çıkış kodları tamdır; komutları ajan sunucuda yeniden çalıştırmadı.
- Önceki hazırlık bölümündeki “kullanıcı çıktısı bekleniyor” durumu bu kayıtla sonuçlandırıldı. Bu tur yalnız salt-okunur kontrollerin kullanıcı kanıtı değerlendirildi; producer/consumer veya restart yeniden yapılmadı.

### Ayrı test sonuçları

| Kontrol / komut | Çıkış | Sonuç |
| --- | --- | --- |
| `id -un` | 0 | GEÇTİ: kafka-deploy |
| `git rev-parse HEAD` | 0 | Checkout: `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c` |
| `git status --short` | 0 | GEÇTİ: çıktı boş, checkout temiz |
| `kubectl config current-context` | 0 | GEÇTİ: kafka-lab |
| `helm list -n kafka-lab --all` | 0 | Release kafka-lab, revision 1, deployed; **kafka-apache-lab-0.1.0**, app 4.0.2 |
| `kubectl get pods,pvc,sts,svc -n kafka-lab -o wide` | 0 | Durum okuması GEÇTİ: üç pod 1/1 Running, StatefulSet 3/3, üç ayrı 5Gi local-path PVC Bound; client/headless servisler mevcut |
| `bash scripts/lab/storage-audit.sh --inspect` | 1 | **BAŞARISIZ / güvenlik engeli:** UNSAFE LEGACY STORAGE; üç pod'da image VOLUME explicit mount eksikliği ve PVC'yi örten container-local data mount'u |
| `kafka-metadata-quorum.sh --bootstrap-server localhost:9092 describe --status` (pod 0 içinde) | 0 | GEÇTİ: leader 2, epoch 2, high watermark 11436, max follower lag 0, max follower lag time 20 ms; voters 0/1/2, observer yok |
| Yeni topic / producer-consumer / restart testi | — | ÇALIŞTIRILMADI: storage engeli çözülmeden sonraki mutation testine geçilmedi |

### Teknik yorum ve sonraki adım

- Çalışan image hâlâ `docker.io/apache/kafka:4.0.2@sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f`. Checkout güncel, **çalışan Helm chart eski 0.1.0**; kaynak güncellemesi 0.2.0 deploy kanıtı değildir. Bu çıktı deploy SHA'sını ayrıca ölçmez; önceki deploy kaydı 0747716 idi.
- Her üç pod'da `/var/lib/kafka` mount kaynağı K3s PVC dizini, `/var/lib/kafka/data` kaynağı ise containerd `containers/<id>/volumes/<id>` dizini. Gerçek Kafka verisinin PVC yerine container-local mount altında kaldığı tekrar doğrulandı. Uzun host/container kimlikleri raporda gereksiz tekrar edilmedi; cluster-ID gövdesi yazılmadı.
- Running/Bound ve quorum lag 0, kalıcı disk güvenliğinin kanıtı değildir. Pod RESTARTS=0 yalnız mevcut pod içindeki container restart sayısını gösterir; önceki pod silinip yeniden oluşmasını dışlamaz. Bu kontrol topic ISR'sini veya bütün kayıtların sağlamlığını doğrulamaz.
- Düzeltme dağıtılmadan aynı restart/smoke testini tekrarlamak yerine veri koruma kararı alınmalı. Kullanıcı henüz mevcut topic/veri/consumer offset'lerinin silinebileceğini onaylamadı. Bu nedenle deploy, restart, rollback, veri taşıma veya silme komutu verilmedi.
- Sonraki gerekli kullanıcı bilgisi: mevcut Kafka verisinin korunması gerekiyor mu, yoksa silinmesine izin verilen yalnız test verisi mi? Yanıta göre veri korumalı geçiş veya açıkça onaylanmış temiz test kurulumu planlanacak; şu anda silme yapılmadı.
- Bu tur yerel `IMPLEMENTATION-REPORT.md` ve araştırma `tests/deploy-notes.md` güncellendi. `git diff --check` ile biçim kontrolü yapıldı; yeni kod testi, commit/push veya sunucu müdahalesi yapılmadı.

## 2026-08-31 — Kullanıcı onayı: disposable lab sıfırlaması, aşama 1

### Açık onay ve kapsam

- Kullanıcı, yalnız `kafka-lab` ortamındaki topic, mesaj, consumer offset ve Kafka disk verilerinin silinerek düzeltilmiş 0.2.0 ile sıfırdan kurulması sorusuna **“onaylıyorum”** yanıtını verdi. Önceki “silme onayı bekleniyor” durumu bu kayıtla değişti. Bu onay mevcut verilerin korunarak taşınması değil, veri kaybı kabul edilen yeni test kurulumu içindir.
- K3s, containerd servisi/host dizinleri, diğer namespace/release'ler, bootstrap namespace/RBAC, deploy kullanıcı tokenı ve `/etc/kafka-kraft` erişim ayarları sıfırlama kapsamı dışında tutulur. Namespace veya host storage kökü topluca silinmeyecek.

### İncelenen kod ve işlem sırası

- Bootstrap, namespace RBAC, deploy scripti, lab StatefulSet/upgrade guard/start scripti, smoke test ve cluster-ID oluşturma scripti incelendi. Cluster-ID scripti ilk olarak yanlış `ensure-cluster-id.sh` adıyla aranıp bulunamadı; `rg --files` ile gerçek `scripts/lab/create-cluster-id.sh` yolu bulundu ve okundu.
- Eski chart'ın PVC retention sözleşmesi nedeniyle Helm uninstall sonrası üç PVC'nin kalması bekleniyor. Bunlar ancak pod'ların durduğu doğrulandıktan sonra açık adlarıyla silinecek. Yeni cluster-ID eski pod/PVC'ler mevcutken üretilmeyecek; deploy scripti ve chart guard'ları değiştirilmedi.
- **İlk sunucu aşaması:** Helm liste çıktısında yalnız beklenen `kafka-lab` release / chart 0.1.0 / revision 1 / deployed durumunu doğrula; ardından `helm uninstall kafka-lab --namespace kafka-lab --wait --timeout 10m --no-hooks` çalıştır. Release eşleşmezse mutation öncesi dur. Hooks çalıştırılmaz; namespace/RBAC/token korunur.
- Sonra `kubectl get pods,sts,pvc,svc -n kafka-lab` ile kalan kaynakları göster. Beklenti Kafka pod/StatefulSet/service'lerinin gitmesi ve üç data PVC'nin kalmasıdır. Timeout, Terminating veya beklenmeyen kaynak varsa force/finalizer temizliği önerilmeyecek.
- İşlem bloğu UTC, checkout SHA, komut çıktıları ve exit kodunu repo `artifacts/reset-stage1-<UTC>-<benzersiz>.md` dosyasına kaydeder. Log oluşturma yalnız rapor yazımıdır; Secret/kubeconfig içeriği yazdırılmaz.
- **Veri etkisi:** uninstall Kafka hizmetini durdurur. PVC'ler tutulsa bile gerçek veri eski container-local mount'larda olduğundan pod kaldırma sonrasında veri kaybı olabilir; bu işlem doğrulanmış bir geri alma/yedek yöntemi değildir. Kullanıcının açık disposable-data onayı esas alındı; fiziksel secure erase iddia edilmez.

### Test ve kalan iş

- Durum: **YÖNLENDİRİLDİ / kullanıcı çalıştırma çıktısı bekleniyor**. Ajan sunucuda Helm uninstall veya herhangi bir silme çalıştırmadı; henüz veri silindiği/kurulum tamamlandığı iddia edilmiyor.
- Bu turun yerel değişikliği yalnız Markdown işlem raporudur; `git diff --check` ile doğrulandı. Commit/push yapılmadı; sunucu adımları mevcut checkout'taki araçlarla çalışır.
- Aşama 1 sonucu alınınca, durduğu doğrulanmış eski Kafka'nın yalnız üç PVC'sinin kaldırılması ve cluster-ID yenilenmesi yönlendirilecek. Ardından 0.2.0 deploy, gerçek storage audit, topic/producer-consumer ve kontrollü restart ayrı aşamalar olarak raporlanacak.

## 2026-08-31 13:03:07 UTC — Aşama 1 sonucu ve koşullu aşama 2

- Kullanıcı kanıtı: checkout `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c`; beklenen 0.1.0 / revision 1 release kontrolü geçti; `release "kafka-lab" uninstalled`, komut bloğu exit 0. Sunucu raporu: `artifacts/reset-stage1-20260831T130307Z-kzmfMi.md`.
- Son durum listesinde StatefulSet ve Service yok; üç pod **Terminating**, üç PVC hâlâ Bound / 5Gi / local-path. Bu, Helm uninstall başarılı olsa bile alt pod'ların kaldırılmasının henüz tamamlanmadığını gösterir. Önceki “pod'lar gider” beklentisi asenkron kapanış nedeniyle bu çıktıda henüz gerçekleşmedi. Pod sonlandırma tamamlandı veya storage temizlendi şeklinde PASS verilmedi.
- Kaldırıldığı doğrulanan: Helm release. Eski verilerin geri getirilebilir olduğu garantisi yok; container-local veriler pod/container yaşam döngüsüyle kaybolabilir. PVC silme henüz çalıştırılmadı. Kullanıcı veri kaybını açıkça onaylamıştı.
- Aşama 2 yönlendirmesi: en fazla 180 saniye pod silinmesini bekle; namespace'te pod/StatefulSet ve Helm release kalmadığını doğrula. Ardından üç PVC'nin hem tam adını hem önceki rapordaki PV eşlemesini Python ile doğrula. Eşleşmezse hiçbir PVC silme.
- Onaylı tam hedefler: `data-kafka-lab-0` → `pvc-b802c30b-f526-47e5-b193-8e46c946f9af`; `data-kafka-lab-1` → `pvc-352611cc-e1b2-4bdb-bb87-17814e662746`; `data-kafka-lab-2` → `pvc-74277cb1-ad46-4757-906d-560c7f908941`. Silme komutu yalnız bu üç PVC adını içerir, selector veya `--all` ile silme yoktur.
- PVC silme ve API'de PVC kalmadığı kontrolü sonrası yalnız `kafka-lab-cluster-id` Secret'ı kaldırılıp mevcut `scripts/lab/create-cluster-id.sh` ile yeni kimlik oluşturulması yönlendirildi. `kafka-lab-deployer-token`, namespace/RBAC ve kubeconfig korunur; Secret içeriği rapora yazdırılmaz.
- Son kontrol `storage-audit.sh --pre-deploy`: boş release/pod/PVC durumunun PASS olması beklenir. Bu yalnız yeni kuruluma hazırlık kontrolüdür, çalışan Kafka veya kalıcılık testi değildir. Fiziksel disk temizliği/PV reclamation/secure erase doğrulanmış sayılmaz; host dizinlerine elle müdahale yoktur.
- Koşullu adımlar `set -Eeuo pipefail` ve rapor/exit trap ile verildi. Timeout veya beklenmeyen kaynakta akış durur; force-delete/finalizer kaldırma yapılmaz. Aşama 2 henüz **ÇALIŞTIRILMADI / kullanıcı çıktısı bekleniyor**; deploy ve mesaj/restart testleri sonraki aşamadadır.
- Yerel işlem: bu Markdown kaydı güncellendi, `git diff --check` çalıştırıldı; sunucu bağlantısı, yeni kod değişikliği veya commit/push yapılmadı.

## 2026-08-31 13:05:10 UTC — Aşama 2 tamamlandı, temiz 0.2.0 kurulumu hazırlanıyor

### Kullanıcı tarafından gerçekleştirilen sıfırlama sonucu

- Sunucu raporu: `artifacts/reset-stage2-20260831T130510Z-L0WFiP.md`; UTC 13:05:10; blok çıkış kodu **0**. Kullanıcı terminal çıktısı kanıttır; ajan sunucuda çalıştırma yapmadı.
- Onaylanan üç eski PVC/PV eşleşmesi doğrulandı; `data-kafka-lab-0`, `data-kafka-lab-1`, `data-kafka-lab-2` için ayrı `deleted` çıktıları alındı. Pod/StatefulSet ve Helm release yokluğu ön koşulları geçildi.
- Yalnız `kafka-lab-cluster-id` Secret'ı silinip yeniden oluşturuldu. Yeni cluster kimliğinin içeriği paylaşılmadı/raporlanmadı. Erişim tokenı, kubeconfig, namespace/RBAC veya diğer servisler için silme komutu yoktu.
- `storage-audit.sh --pre-deploy`: **GEÇTİ**, `PASS: no existing release, pods or PVCs (pre-deploy only)`. Son `kubectl get pods,sts,pvc,svc -n kafka-lab`: `No resources found in kafka-lab namespace.` Bu ifade yalnız sorgulanan kaynak türleri içindir; namespace/Secret/RBAC kaldırılmış demek değildir.
- Eski test verileri yeni cluster'a taşınmadı. PVC silme sonrası doğrulanmış geri yükleme olanağı yok; fiziksel PV dizinleri/containerd volume'larının temizlendiği veya güvenli biçimde üzerine yazıldığı iddia edilmiyor. Host filesystem üzerinde manuel temizleme yapılmadı.

### Aşama 3 — kuruluma geçiş

- Kullanıcıya mevcut checkout'ta chart sürümü 0.2.0 kontrolü, `scripts/validate.sh`, `scripts/contabo/deploy.sh --check`, ardından `scripts/contabo/deploy.sh` sırasıyla verildi. `set -Eeuo pipefail` ile hata sonrası sonraki aşamaya geçilmez; UTC/SHA/çıktı/exit kodu ayrı artifacts raporuna alınır.
- Mevcut deploy scripti yeniden okundu: deployment öncesi boş storage kontrolü, Helm lint/render ve API server dry-run; deployment sonrası rollout ve gerçek storage audit var. Bootstrap'i tekrar çalıştırmak veya erişim kimliklerini yeniden üretmek gerekmiyor.
- Deployment scripti ayrıca `/var/log/kafka-lab/deploy-*.md` üretir. İlk kuruluma ait yeni Helm revision'ın 1 olması normaldir; sürüm karşılaştırmasında `kafka-apache-lab-0.2.0`, yeni PVC eşlemeleri ve storage audit esas alınacaktır.
- Aşama 3 durumu: **YÖNLENDİRİLDİ / kullanıcı çıktısı bekleniyor**. Yeni image pull/pod readiness/mount doğrulaması henüz PASS değil. Topic/producer-consumer ve restart testleri dağıtım sonucu incelendikten sonra yönlendirilecek.
- Bu tur yerel işlem raporu ve araştırma deploy notları güncellendi; `git diff --check` kontrolü yapıldı. Chart/script değiştirilmedi, sunucuya bağlanılmadı, commit/push yapılmadı.

## 2026-08-31 21:40–21:41 UTC — Temiz chart 0.2.0 canlı deploy sonucu

### Kanıt ve sürüm ayrımı

- Kullanıcı tam terminal dökümünü ek dosya olarak sağladı. Sunucu raporu `artifacts/deploy-v020-20260831T214010Z-sePMvW.md`; dış blok exit **0**. Ajan sunucuya bağlanmadı.
- Komut root shell'de ve `/root/KafkaKRaft` checkout'unda çalıştırılmış; kaynak `0c0c5ce0acfc570c793035846c6f0254b52dfd5d`, chart 0.2.0. Önceki yönlendirmede kafka-deploy istenmişti; bu sapma raporlandı. Çıktıda namespace dışı işlem veya credential içeriği yoktur.
- Sunucudaki diğer checkout `430f8cb` olsa da `git diff 0c0c5ce..430f8cb -- lab/kafka-apache scripts/lab/smoke-test.sh scripts/lab/storage-audit.sh scripts/lab/storage_audit.py scripts/contabo/deploy.sh` yerelde boş çıktı verdi. Aradaki commitler roadmap/rapor teslimidir; çalışan chart ve sonraki smoke kodu bu yollar için aynıdır.

### Offline ve deploy kontrolleri

| Kontrol | Sonuç |
| --- | --- |
| Chart sürüm kapısı | GEÇTİ: 0.2.0 |
| Helm lint | GEÇTİ: 1 chart, 0 failed; icon yalnız INFO |
| Python chart testleri | 6/6 GEÇTİ |
| Python storage testleri | 10/10 GEÇTİ |
| Mock startup | 12 senaryo GEÇTİ |
| Mock cluster-ID | 4 senaryo GEÇTİ |
| `deploy.sh --check` | GEÇTİ: authorization, cluster-ID Secret varlığı, boş storage, lint/render ve API server dry-run |
| `deploy.sh` | GEÇTİ: yeni install, rollout ve canlı storage audit |

Sunucu checkout'u roadmap teslim commitinden önce olduğu için bu koşuda `tests/test_roadmap.py` bulunmuyor ve 19 yerine 16 Python testi çalıştı. Bu, chart/runtime yollarında fark anlamına gelmez; eksik üç test belge/link ve iki values render sözleşmesi testidir.

### Gerçek çalışma durumu

- Helm: release `kafka-lab`, status deployed, revision 1, chart `kafka-apache-lab-0.2.0`, app 4.0.2. Temiz install sonrası revision'ın yeniden 1 olması beklenir.
- StatefulSet rollout tamamlandı: revision `kafka-lab-58fcc86598`; üç pod 1/1 Running, restart 0; StatefulSet 3/3.
- Üç yeni PVC Bound / 5Gi / RWO / local-path. PV kimlikleri: pod 0 `pvc-a6db0802-2725-4d5c-bbb2-18f4ae4c9e0e`, pod 1 `pvc-438e86a7-755d-416b-9e29-ea3e420a9cf2`, pod 2 `pvc-bed58dc0-707f-42e0-836d-c3a9ed11cb71`.
- Her pod için yalnız `/var/lib/kafka/data` mount'u kendi `/var/lib/rancher/k3s/storage/<PV>_kafka-lab_<claim>` kaynağına bağlı; containerd `containers/.../volumes/...` data mount'u yok. Üçünde de effective log/metadata ve kimlik kontrolü `explicit PVC mount and metadata verified`; audit `PASS (read-only storage audit)`.
- Service'ler hazır: client ClusterIP 9092 ve headless 9092/9093. Image önceki sabit Apache Kafka 4.0.2 digest'i; çıktı satırı Helm tabloda app sürümünü, mount audit ise runtime storage'ı doğruladı.

### Kalan kabul ve sonraki test

- **Kalıcılık hedefinin ilk yarısı geçti:** exact PVC mount ve ilk metadata kimliği gerçek cluster'da doğrulandı. Quorum status, topic create/describe, producer-consumer, full ISR, pod 0 replacement, restart sonrası eski mesaj okuma, aynı PVC/PV + metadata kimliği ve yeni yazı bu 0.2.0 koşusunda henüz test edilmedi.
- Sonraki yönlendirme, normal `kafka-deploy` checkout'unda `scripts/lab/smoke-test.sh --restart` çalıştırmaktır. Script önce salt-okunur snapshot/audit yapar; ardından disposable topic ve 3 mesaj oluşturur, tam ISR kontrol eder, yalnız pod 0'ı replacement eder, storage kimliklerini karşılaştırır, eski mesajları okur, yeni mesaj yazar ve topic'i 3 partition'a çıkarır.
- Test hata verirse tekrar restart/silme/deploy yapılmadan çıktı incelenecek. Başarılı olması tek-host production HA/TLS/SASL/JMX/CVE onayı değildir.
- Belgelerde eski “0.2.0 deploy bekliyor” kayıtları tarihsel kalır; bu bölüm güncel sonucu geçersiz kılar. Roadmap matrisi/araştırma README/deploy notları güncellendi. `git diff --check` geçti; yerel rapor değişiklikleri henüz commit/push edilmedi.

## 2026-08-31 21:45 UTC — 0.2.0 mesaj ve restart kalıcılık kabulü

### Kaynak ve başlangıç durumu

- Kullanıcı normal `kafka-deploy` hesabında `/home/kafka-deploy/KafkaKRaft` checkout'undan çalıştırdı. Kaynak: `430f8cb068d7b19ab8bebe61530a80b8a4f3ff3c`; context kafka-lab. Komut: `bash scripts/lab/smoke-test.sh --restart`.
- Kullanıcının ekli terminal dökümü tam okundu; ajan sunucuya SSH ile bağlanmadı. Test scriptinin kendi rapor dosyası terminal çıktısında gösterilmedi; script default olarak checkout altındaki `artifacts/smoke-<UTC>-<PID>.md` dosyasına yazar. Gerçek dosya adı verilmediği için uydurulmadı.
- Deploy kaynağı 0c0c5ce, smoke kaynağı 430f8cb'dir. Önceki yerel diff doğrulaması chart/deploy/storage/smoke yollarında iki SHA arasında fark olmadığını gösterdi.

### Kabul sonuçları

| Kontrol | Sonuç / kanıt |
| --- | --- |
| Rollout başlangıcı | GEÇTİ: 3 pod mevcut StatefulSet revision'ında complete |
| Restart öncesi storage audit | GEÇTİ: üç pod exact `/var/lib/kafka/data` PVC mount ve metadata |
| Image | Apache Kafka 4.0.2 sabit digest |
| İlk quorum | GEÇTİ: leader 1, epoch 2, voters 0/1/2, observer yok, max follower lag 0 |
| Topic oluşturma | GEÇTİ: `lab-smoke-20260831214527-8378`, partition 1, RF 3, minISR 2, ISR üç üye |
| Producer/consumer | GEÇTİ: acks=all ile üç mesaj, consumer exact sıralı payload; `Processed a total of 3 messages` |
| Pod replacement | GEÇTİ: yalnız `kafka-lab-0` silindi ve yeni pod Ready oldu |
| Restart sonrası storage audit | GEÇTİ: üç PV/PVC mount kaynağı ve semantik storage kimliği değişmedi |
| Restart sonrası eski okuma | GEÇTİ: aynı üç mesaj yeniden okundu |
| İkinci quorum / ISR | GEÇTİ: cluster kimliği aynı, leader 1, voters 0/1/2, max follower lag 0; partition ISR yeniden üç üye |
| Restart sonrası yeni yazı/okuma | GEÇTİ: dördüncü mesaj yazıldı ve toplam dört mesaj exact doğrulandı |
| Topic yönetimi | GEÇTİ: 1 → 3 partition; her partition RF=3 ve üç üyeli ISR |
| Script sonucu | `PASS: replacement pod, unchanged metadata and persistent messages`; `Result: PASS` |

Cluster-ID ve uzun TopicId raporda tekrar edilmedi; bunlar credential değildir fakat kabul için gövde değeri gerekmez. PV kimlikleri önceki deploy bölümünde kayıtlıdır; test bunların değişmediğini doğruladı. Pod UID değerleri script içinde karşılaştırıldı fakat çıktıya/rapora yazdırılmadı.

### Hedef sonucu ve sınırlar

- **Teknik haftalık hedef tamamlandı:** Bitnami image/library bağımlılığı olmayan bağımsız chart, gerçek Apache Kafka 4.0.2 image ile 3-node combined KRaft deploy, storage, quorum, topic, producer/consumer, partition yönetimi ve pod replacement sonrası kalıcılık testlerini geçti.
- Eski 0.1.0 FAIL sonucu tarihsel ve önemlidir; 0.2.0 PASS bunu saklamaz, düzeltmenin işe yaradığını kanıtlar. PVC Bound/Running tek başına değil; exact mount + metadata kimliği + eski/yeni mesaj kabulü birlikte kullanıldı.
- Kalan roadmap teslim kalemi gerçek ekran görüntüleridir. Kullanıcının metin terminal kanıtı yeterli teknik rapor sağladı fakat PNG/JPG ekran görüntüsü gibi gösterilmez.
- Bu sonuç tek Contabo host üzerindeki laboratuvar için geçerlidir. Aynı host kaybı, aynı anda çoklu pod kaybı, uzun süre/yük, disk dolması, broker/controller ayrımı, TLS/SASL, dış erişim, JMX, backup/restore, upgrade/downgrade, CVE/SBOM/imza ve production HA test edilmedi/onaylanmadı.
- Test topic'i tutuldu ve kayıt retention'ı bir saattir; topic nesnesinin otomatik silindiği iddia edilmez. Yeniden pod silme veya smoke çalıştırma gerekmiyor.

### Belge ve doğrulama güncellemesi

- Güncellendi: `ROADMAP-COMPLIANCE.md`, `CHART-AUDIT.md`, araştırma README, ADR/seçim kararı, demo notları, deploy/producer-consumer/topic test notları ve bu rapor.
- Tarihsel bölümlerde o anki “bekliyor/başarısız” kayıtları işlem izi olarak bırakıldı; güncel sonuçlar daha sonraki tarihli başlıklar ve final özetlerde açıkça üstün gelir.
- Yerel belge link/regresyon kontrolü `tests/test_roadmap.py`, whitespace `git diff --check` ve staged secret-pattern kontrolü commit öncesinde çalıştırılacak. Chart/script kodunda bu raporlama turunda değişiklik yapılmadı.

### Final kabul raporu — Git sonucu

- `tests/test_roadmap.py`: 3/3 GEÇTİ; yeni lab values exact PVC render sözleşmesi, root image-only negatif deney ve belge/yerel linkler. Root negatif render sayıları değişmedi: `/opt/bitnami=4`, `libkafka.sh=1`, `KAFKA_CFG_=1`.
- `git diff --check` ve staged diff whitespace kontrolü geçti. Değişiklikler yalnız 10 Markdown rapor/araştırma dosyasıdır; chart/script kodu değiştirilmedi.
- Staged dosyalarda private-key başlığı ve yaygın GitHub/AWS token kalıpları yalnız dosya adı döndürecek şekilde tarandı: eşleşme yok. Bu sınırlı kontrol tam secret scanner değildir.
- Commit: `84419272035a427ea81b7595a74ca18a4edaa659` — `Record successful Kafka 0.2 persistence acceptance`; 10 dosya, 284 ekleme / 32 silme.
- `git push origin main`: başarılı, `430f8cb..8441927 main -> main`. Sonraki `git ls-remote origin refs/heads/main` aynı tam SHA'yı döndürdü.
- Bu sonuç bölümü ayrı rapor takip commit'inde saklanır. Push sunucuda otomatik deploy çalıştırmaz; çalışan Kafka release'in deploy kaynağı 0c0c5ce ve kalıcılık test kaynağı 430f8cb olarak kalır. GitHub otomasyonu yoktur.
