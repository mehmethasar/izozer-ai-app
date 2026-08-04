# izozer.com kök alan adı yönlendirmesi

Mazdek mobil uygulaması `https://izozer.com` taban adresini kullanır.

Mevcut web sitesi korunarak yalnızca şu yollar Mazdek API sunucusuna yönlendirilmelidir:

- `/api/*`
- `/privacy`
- `/health`
- `/ready`
- `/auth/apple/callback`

Diğer bütün yollar mevcut izozer.com web sitesine gitmeye devam eder.
