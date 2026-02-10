# İlaç Takip Uygulaması (Medication Tracker)

A fully local, privacy-focused medication tracking application built with Flutter. This app helps users manage their medication schedule with custom audible reminders and a responsive design that works on any device.

## 🌟 Features

- **🔒 Fully Local**: No servers, no sign-ups. All data is stored securely on your device using **Hive**.
- **🔔 Custom Notifications**: Triggers a unique alarm sound (`medication_alarm.mp3`) for reminders, ensuring you differentiate it from standard system notifications.
- **📱 Responsive Design**: UI adapts perfectly to different screen sizes using `flutter_screenutil`.
- **🚀 Onboarding**: Quick and easy setup for your first medication.
- **⚡ Background Support**: Notifications work even when the app is completely closed.

## 🛠️ Technologies

- **[Flutter](https://flutter.dev/)**: Cross-platform UI toolkit.
- **[Hive](https://docs.hivedb.dev/)**: Lightweight and fast key-value database.
- **[Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)**: Advanced notification scheduling.
- **[ScreenUtil](https://pub.dev/packages/flutter_screenutil)**: Screen adaptation for responsive layouts.

## 📦 Installation & Setup

1.  **Clone the project**
    ```bash
    git clone https://github.com/yourusername/ilac_takip.git
    cd ilac_takip
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Generate Hive Adapters** (if you modify models)
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## ⚙️ Configuration

### Custom Notification Sound

The app uses a custom sound file named `medication_alarm.mp3`.

-   **Android**: The file is located at `android/app/src/main/res/raw/medication_alarm.mp3`.
-   **iOS**: The file should be added to the root of the Xcode project and included in the app bundle.

*Note: If you want to change the sound, simply replace this file with your own audio file (keep the same name).*

## 📂 Project Structure

```
lib/
├── models/         # Data models (Medicine)
├── pages/          # UI Screens (Onboarding, HomePage)
├── services/       # Core Logic (Storage, Notifications)
└── main.dart       # App Entry & Initialization
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
