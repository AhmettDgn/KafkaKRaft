# Uygulama raporu

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
