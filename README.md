# Mazdek Mobil Uygulaması

Bu depo Mazdek Flutter istemcisinin doğrudan kaynak kodunu `mobile/` altında tutar. GitHub Actions, Flutter platform dosyalarını geçici olarak üretir; uygulamayı analiz eder, test eder ve Android/iOS derleme çıktıları oluşturur.

## Yerel doğrulama

```bash
python3 ci_verify_security.py
cd mobile
flutter pub get
flutter analyze
flutter test
```

Canlı sürüm yalnızca `https://api.izozer.com` API kökenine bağlanır. Özel geliştirme sunucusu seçimi yalnızca debug derlemelerinde kullanılabilir.

Depoda API anahtarı, parola, keystore veya Apple/Firebase özel anahtarı tutulmaz. Bu değerler gerektiğinde GitHub Actions secrets veya güvenli yayın ortamından sağlanmalıdır.
