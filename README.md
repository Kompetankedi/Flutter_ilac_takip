# İlaç Takip Uygulaması (Medication Tracker)

Modern, kullanıcı dostu ve akıllı bildirim sistemine sahip bir ilaç takip uygulaması.

## 🚀 Özellikler

- **Akıllı Hatırlatıcılar**: İlaç saatiniz geldiğinde bildirim alırsınız.
- **Dürtme (Nagging) Bildirimi**: İlacı içtiğinizi işaretlemediğiniz sürece, 15 dakika boyunca her dakika başı tekrar hatırlatma yapılır.
- **Günlük Takip**: Ana ekranda "Bugünkü İlaçlar" ve "Tamamlananlar" olarak gruplandırılmış liste.
- **Kolay İşaretleme**: İlacı içtiğinizde tek tıkla işaretleyin. Yanlışlıkla işaretlediyseniz, üzerine basılı tutarak (Long Press) geri alabilirsiniz.
- **İstatistikler ve Seri**: İlaç içme alışkanlığınızı takip edin. Haftalık uyum grafiği ve üst üste kaç gün içtiğinizi gösteren "Seri" (Streak) özelliği.
- **Modern Arayüz**: Responsive tasarım, mavi/beyaz ferah tema ve akıcı animasyonlar.
- **Pil Tasarrufu Uyarıları**: Xiaomi, Huawei gibi cihazlarda bildirimlerin kesilmemesi için gerekli yönlendirmeler.

## 🛠️ Teknik Detaylar

- **Framework**: Flutter
- **Yerel Depolama**: [Hive](https://pub.dev/packages/hive) (Hızlı ve güvenli yerel veritabanı)
- **Bildirimler**: [Awesome Notifications](https://pub.dev/packages/awesome_notifications)
- **Grafikler**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Responsive UI**: [flutter_screenutil](https://pub.dev/packages/flutter_screenutil)

## 📦 Kurulum

1. Depoyu klonlayın:
   ```bash
   git clone https://github.com/Kompetankedi/Flutter_ilac_takip.git
   ```
2. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
3. Hive adaptörlerini oluşturun (Gerekliyse):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## 🔔 Bildirim Notları (Android)

Özellikle Android 12+ ve kısıtlı pil yönetimi olan cihazlarda bildirimlerin çalışması için:
1. Uygulama ayarlarından **"Tam Ekran Niyeti"** ve **"Kilit Ekranında Göster"** izinlerini kontrol edin.
2. Pil tasarrufu modundan **"Kısıtlama Yok"** seçeneğini seçin.

## 📄 Lisans

Bu proje MIT lisansı ile korunmaktadır.
