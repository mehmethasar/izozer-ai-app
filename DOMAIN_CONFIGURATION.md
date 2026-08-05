# Mazdek canlı alan adı yapılandırması

- Uygulamanın görünen mağaza adı: **Mazdek**
- Ana web sitesi: `https://izozer.com`
- Canlı uygulama sunucusu: `https://api.izozer.com`
- API: `https://api.izozer.com/api/...`
- Gizlilik politikası: `https://api.izozer.com/privacy`
- Sağlık kontrolü: `https://api.izozer.com/health`
- Hazırlık kontrolü: `https://api.izozer.com/ready`
- Apple Android dönüş adresi: `https://api.izozer.com/auth/apple/callback`
- Android Application ID: `com.mazdek.mazdekai`
- iOS Bundle ID: `com.mazdek.mazdekai`

`izozer.com` mevcut web sitesine ayrılmış olarak kalır. DNS üzerinde yalnızca `api.izozer.com` alt alanı Mazdek uygulama sunucusuna yönlendirilir. WordPress, e-posta, SEO sayfaları ve ana sitenin dosyaları uygulama sunucusuyla karıştırılmaz.

Önerilen DNS kaydı:

```text
Tür: A
Ad/Host: api
Değer: Mazdek uygulama sunucusunun sabit IPv4 adresi
TTL: Otomatik veya 300
```

Uygulama sunucusunda `api.izozer.com` için geçerli HTTPS sertifikası zorunludur. Mobil release sürümleri düz HTTP adreslerine bağlanmaz.
