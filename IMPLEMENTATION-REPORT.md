# Uygulama raporu

## GÜNCEL UYARI — 2026-08-31 kalıcılık olayı

Önceki bölümler tarihsel kayıttır. Kullanıcının sunucu çıktıları artık gerçek bootstrap/deploy/smoke başarısını, fakat restart kalıcılık testinin **başarısız** olduğunu gösteriyor. Sunucudaki uygulama kaynağı `0747716`, Helm revision 1. Yeni düzeltme henüz sunucuda uygulanmadı. Pod/PVC/Secret silmeyin ve eski kurulumu normal Helm upgrade ile değiştirmeyin.

- 10:56–10:57 UTC: üç pod Running, üç PVC Bound, quorum/mesajlaşma başarılı (kullanıcının paylaştığı kanıt; ajan sunucuya bağlanmadı).
- 11:05 UTC restart testi FAIL; yeni pod logunda `Formatting metadata directory /var/lib/kafka/data` görüldü. Üç mesajın okunması diğer replikaların varlığı nedeniyle pod-local kalıcılık kanıtı değildir.
- Mountinfo kök nedeni doğruladı: PVC `/var/lib/kafka` üzerinde, gerçek Kafka dizini `/var/lib/kafka/data` ise containerd `containers/<id>/volumes/<id>` kaynağı üzerinde. Kimlik/hash ve hosta özel uzun ID'ler rapora kopyalanmadı.
- Hata sorumluluğu: ilk chart, Apache image-defined child volume ile PVC ancestor mount çakışmasını ele almıyordu. Eski offline testler bu runtime davranışını modellemiyordu. PVC Bound/render PASS verinin gerçekten PVC'ye yazıldığını kanıtlamaz.
- Kullanıcı düzeltme, detaylı chart/çakışma denetimi, veri koruma rehberi ve Markdown raporunu onayladı. Bu çalışma sunucuda veri taşıma/silme işlemi yapmaz.
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
