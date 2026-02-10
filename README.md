# 🏥 İlaç Takip (Medication Tracker)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Hive-Database-FDB813?style=for-the-badge)](https://pub.dev/packages/hive)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Modern, kullanıcı dostu ve akıllı bildirim sistemiyle donatılmış, ilaç kullanım alışkanlıklarınızı düzene sokan kapsamlı bir mobil uygulama.

---

## ✨ Öne Çıkan Özellikler

### 🔔 Akıllı ve Israrcı Bildirimler
- **Çoklu Zamanlama**: Bir ilaç için günde birden fazla hatırlatma saati belirleyebilirsiniz.
- **Haftalık Planlama**: Sadece belirli günlerde (örn: Pazartesi, Çarşamba, Cuma) alınması gereken ilaçları kolayca yönetin.
- **Dürtme (Nagging) Sistemi**: İlacı içtiğinizi işaretlemediğiniz sürece uygulama sizi belirli aralıklarla nazikçe uyarır.

### 📊 İzleme ve Analiz
- **Günlük Özet**: Ana ekranda "Bekleyen" ve "Tamamlanan" ilaçlarınızı anlık olarak görün.
- **İlaç Serisi (Streak)**: Hiç gün kaçırmadan ilaçlarınızı aldığınız gün sayısını takip ederek motivasyonunuzu artırın.
- **Haftalık Uyum**: Geçmişe dönük performansınızı şık grafiklerle analiz edin.

### 🎨 Kullanıcı Deneyimi
- **Kompakt Tasarım**: İlaç kartlarında tüm saatleri ve dozaj bilgilerini bir bakışta görün.
- **Kolay Kontrol**: Tek tıkla işaretleme, uzun basışla yanlışlıkla yapılan işaretlemeyi geri alma.
- **Modern Arayüz**: `ScreenUtil` ile her ekran boyutuna uyumlu, ferah ve akıcı bir görsel tasarım.

---

## 🚀 Teknolojiler

Uygulamanın kalbinde güncel ve performanslı teknolojiler yer almaktadır:

- **Flutter**: Cross-platform uygulama geliştirme framework'ü.
- **Hive**: Ultra hızlı, NoSQL yerel veritabanı.
- **Awesome Notifications**: Gelişmiş, özelleştirilebilir yerel bildirimler.
- **FL Chart**: Veri görselleştirme ve grafikler.
- **ScreenUtil**: Cihaz bağımsız responsive tasarım.

---

## 🛠️ Kurulum

Projeyi yerel ortamınızda çalıştırmak için şu adımları izleyin:

1. **Repoyu Klonlayın**
   ```bash
   git clone https://github.com/Kompetankedi/Flutter_ilac_takip.git
   cd Flutter_ilac_takip
   ```

2. **Bağımlılıkları Yükleyin**
   ```bash
   flutter pub get
   ```

3. **Kod Oluşturucuyu Çalıştırın** (Hive adaptörleri için)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Uygulamayı Başlatın**
   ```bash
   flutter run
   ```

---

## ⚠️ Önemli Notlar (Android için)

Android 12 ve üzeri sürümlerde bildirimlerin zamanında ve kesintisiz iletilmesi için:
- Uygulama bilgilerinden **"Pil Kısıtlaması Yok"** modunu etkinleştirin.
- **"Tam Ekran Niyeti"** ve **"Kilit Ekranında Bildirimler"** izinlerinin verildiğinden emin olun.
- Xiaomi/Huawei gibi cihazlarda "Otomatik Başlatma" (Auto-start) iznini verin.

---

## 📄 Lisans

Bu proje **MIT Lisansı** altında sunulmaktadır. Daha fazla bilgi için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.

---

Developed with ❤️ by [Kompetankedi](https://github.com/Kompetankedi)
