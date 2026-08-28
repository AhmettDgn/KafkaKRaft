# Contabo + GitHub Actions kurulumu

Bu dizindeki gerçek production dosyaları Git'e eklenmez. GitHub'a yapılan her `main` push'ı önce Helm validation çalıştırır; başarılı olursa GitHub Actions, Contabo sunucusuna SSH ile bağlanır ve tam commit SHA'yı deploy eder. SSH anahtarı yalnız GitHub Secret'ta tutulur.

## 1. GitHub repository ve Secrets

Repo oluşturulduktan sonra GitHub'da **Settings → Environments → New environment** ile `contabo-production` environment'ını oluşturun. Production branch koruması/required reviewer etkinleştirmek önerilir.

Ardından **Settings → Secrets and variables → Actions** altında şu repository secret'larını ekleyin:

| Secret | Değer |
| --- | --- |
| `CONTABO_HOST` | Sunucunun IP adresi veya DNS adı |
| `CONTABO_PORT` | SSH portu (`22` değilse özel port) |
| `CONTABO_USER` | Sadece deploy için açılmış Linux kullanıcısı |
| `CONTABO_SSH_PRIVATE_KEY` | GitHub Actions için oluşturulan Ed25519 private key |
| `CONTABO_KNOWN_HOSTS` | Sunucu host key satırı; `ssh-keyscan` çıktısını körlemesine kabul etmeyin, sağlayıcının fingerprint'i ile doğrulayın |

## 2. Contabo'da bir defalık kurulum

Yerel makinenizde ayrı bir deploy anahtarı üretin; mevcut kişisel SSH anahtarınızı kullanmayın:

```bash
ssh-keygen -t ed25519 -f ./contabo-github-actions -C "github-actions-kafka-deploy"
ssh-copy-id -i ./contabo-github-actions.pub DEPLOY_USER@CONTABO_HOST
```

Private key'in tamamını `CONTABO_SSH_PRIVATE_KEY` secret'ına, public key'i sunucudaki deploy kullanıcısının `~/.ssh/authorized_keys` dosyasına ekleyin. Sunucunun fingerprint'ini güvenilir bir kanaldan doğruladıktan sonra şu komutun çıktısını `CONTABO_KNOWN_HOSTS` secret'ına girin:

```bash
ssh-keyscan -p CONTABO_PORT -H CONTABO_HOST
```

Bootstrap scriptini sunucuda çalıştırın (repository ilk kez erişilebilir olduktan sonra):

```bash
git clone git@github.com:GITHUB_OWNER/GITHUB_REPOSITORY.git /tmp/kafka-cluster-kraft
cd /tmp/kafka-cluster-kraft
DEPLOY_USER=DEPLOY_USER DEPLOY_DIR=/opt/kafka-cluster-kraft bash scripts/contabo/bootstrap.sh
sudo cp deploy/contabo/deploy.env.example /etc/kafka-kraft/deploy.env
sudo chmod 600 /etc/kafka-kraft/deploy.env
sudo chown root:root /etc/kafka-kraft/deploy.env
sudoedit /etc/kafka-kraft/deploy.env
sudoedit /etc/kafka-kraft/values-production.yaml
git clone git@github.com:GITHUB_OWNER/GITHUB_REPOSITORY.git /opt/kafka-cluster-kraft
```

`values-production.yaml` içerisine TLS/SASL için mevcut Kubernetes Secret adlarını ve ortam değerlerini yazın; plaintext parola eklemeyin. Deploy kullanıcısının seçili Kubernetes cluster için yalnız gereken namespace izinlerine sahip kubeconfig'e erişmesi gerekir.

## 3. Güvenli etkinleştirme sırası

1. `DEPLOY_ENABLED=false` ile ilk push yapın. GitHub Actions SSH bağlantısını ve server checkout'ını doğrular; `helm upgrade` çalışmaz.
2. Chart portu tamamlanmadan `ALLOW_UNPORTED_BITNAMI_CHART` değerini `true` yapmayın. Script, `/opt/bitnami/scripts/libkafka.sh` tespit ederse deploy'u bilinçli olarak durdurur.
3. Test cluster'ında KRaft/topic/producer/consumer kontrollerini tamamlayın.
4. Production values dosyasını gözden geçirip `DEPLOY_ENABLED=true` yapın.
5. `main` branch'e yapılan her push, doğrulama sonrasında tam SHA'yı `helm upgrade --install --atomic --wait` ile deploy eder. Hata durumunda Helm atomik rollback uygular.

## Geri alma

GitHub'da önceki iyi commit'i `main`e geri alın veya revert commit'i push edin. Deploy script commit SHA'yı kullandığı için server üzerinde “latest” yerine tam doğrulanmış revision çalışır. Kubernetes release geçmişi için:

```bash
helm history kafka-kraft -n kafka
helm rollback kafka-kraft REVISION -n kafka --wait --timeout 15m
```
