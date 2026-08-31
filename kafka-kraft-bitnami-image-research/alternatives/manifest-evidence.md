# OCI mimari ve erişim kanıtı — 2026-08-31

Kontrol: `docker buildx imagetools inspect IMAGE`. Bu işlem registry manifestini okur; image'ı çalıştırmaz veya CVE taramaz. Windows sandbox ağ/credential erişimi gereken çağrılar izinli tekrarla yürütüldü. Bilinmeyen/attestation platformları runtime mimarisi sayılmadı.

| Image / deney | Sonuç | Digest |
| --- | --- | --- |
| `apache/kafka:4.0.2` | Önceki doğrulama: linux/amd64, linux/arm64; sonraki config kontrolünde iki mimaride üç image VOLUME aynı | `sha256:836cafdad9f4825880d7cf1d5a21202915ae2527bd0ef1c3600c526ed7814d1f` |
| `confluentinc/cp-kafka:8.2.0` | Bu denemede linux/amd64 ve linux/arm64/v8 doğrulandı | `sha256:acbbf674f2ed40e5d0a8ca51beb0f00692c866fc22b5ce06f8cadbdc54cd4436` |
| `quay.io/strimzi/kafka:0.47.0-kafka-4.0.0` | Bu denemede linux/amd64, linux/arm64, linux/ppc64le, linux/s390x doğrulandı | `sha256:0854e32551f4e762125126b15a91ad8cbb7cb7af9b309b19db8e2fe07de01760` |
| `cgr.dev/chainguard/kafka:latest` | Anonymous token isteği **403 Forbidden**; digest/mimari doğrulanamadı | Yok; uydurulmadı |
| Red Hat Streams image | Belirli registry image/tag manifesti bu ortamda sorgulanmadı; ürün support matrisi ayrı incelendi | Doğrulanmadı |

Confluent alt manifestleri: amd64 `sha256:e1b1d853560fd5b849eb05bdb21b4b64fab89b7f44c712bbbc26b29f35ed1492`; arm64/v8 `sha256:e9ceaf79237c0346f0ebecaf3c90a32578aa13e04d2d6c98f545341045c2804e`.

Strimzi alt manifestleri: amd64 `sha256:c0bbce91ab98bcd998054931bc47b31e456547c60dcf7d9941ed4e6411cdf095`; arm64 `sha256:cafcaba4ab4a1ddaf15b83d8ecadf99122268b718b2164ff6aae358a285c9ba2`.

Seçilen Strimzi tag'i karşılaştırma örneğidir; en güncel/güvenli sürüm olduğu iddia edilmez. Confluent ve Strimzi farklı Kafka/bileşen sürümleri içerebilir; performans veya eşdeğer CVE karşılaştırması yapılmadı. Demo image'ı bu araştırma sırasında değiştirilmedi.

## Docker Official Image ayrımı

`gh api repos/docker-library/official-images/contents/library` yanıtında adı `kafka` olan kayıt filtrelendi; sonuç `[]`. Kontrol anında `library/kafka` için resmi katalog girdisi bulunmadı. `apache/kafka` ASF tarafından yayımlanan resmi proje imajıdır; bu, Docker Official Images programındaki `library/*` ile aynı ifade değildir. [Katalog](https://github.com/docker-library/official-images/tree/master/library).

Chainguard dokümanı `cgr.dev/ORGANIZATION/kafka` için yetkilendirilmiş organization yolu tarif eder. 403, ürünün Kafka/KRaft desteklemediği anlamına gelmez; anonim erişimin bu denemede sağlanamadığı anlamına gelir. [Yayıncı kullanım/erişim belgesi](https://images.chainguard.dev/directory/image/kafka/overview).
