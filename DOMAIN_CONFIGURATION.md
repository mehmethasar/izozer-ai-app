# Mazdek canlı alan adı yapılandırması

- Uygulamanın görünen mağaza adı: **Mazdek**
- Canlı sunucu tabanı: `https://izozer.com`
- API: `https://izozer.com/api/...`
- Gizlilik politikası: `https://izozer.com/privacy`
- Sağlık kontrolü: `https://izozer.com/health`
- Hazırlık kontrolü: `https://izozer.com/ready`
- Apple Android dönüş adresi: `https://izozer.com/auth/apple/callback`
- Android Application ID: `com.mazdek.mazdekai`
- iOS Bundle ID: `com.mazdek.mazdekai`

`izozer.com` tamamen API sunucusuna çevrilmez. Mevcut web sunucusu veya öndeki ters proxy yalnızca `/api/*`, `/privacy`, `/health`, `/ready` ve `/auth/apple/callback` yollarını Mazdek sunucusuna aktarır. Diğer bütün yollar mevcut web sitesine gider. Böylece ana site, WordPress ve SEO sayfaları aynı alan adında çalışmaya devam eder.
