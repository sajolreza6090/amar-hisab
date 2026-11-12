# আমার হিসাব — Flutter Android source

এটি একটি অফলাইন হিসাবখাতা অ্যাপের প্রাথমিক Flutter source project।

## ফিচার
- কাস্টমার যোগ ও তালিকা
- জমা/পাওনা এবং খরচের লেনদেন
- মোট পাওনা, মোট জমা ও খরচের সারাংশ
- SQLite লোকাল ডাটাবেজে ডাটা সংরক্ষণ
- বাংলা UI

## APK তৈরি
এই পরিবেশে Flutter SDK ও Android SDK নেই, তাই এখানে APK compile করা সম্ভব হয়নি।
কম্পিউটারে Flutter stable এবং Android Studio/Android SDK ইনস্টল করে:
1. এই ফোল্ডার খুলুন
2. `flutter pub get`
3. `flutter build apk --release`
4. APK পাবেন `build/app/outputs/flutter-apk/app-release.apk`-এ

প্রথমবার চালুর আগে Android Studio-তে Android SDK ও license configure করুন।
