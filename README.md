# Öğrenme Asistanı

Flutter ile geliştirilen, yapay zeka destekli kişisel öğrenme asistanı Android uygulaması. Ders notlarını yapıştırıp otomatik hafıza kartı veya çoktan seçmeli test üretebilir, konularla ilgili AI ile sohbet edip özel ders alabilir, derslerini organize edip ilerlemeni takip edebilirsin.

## Özellikler

- **AI Sohbet**: Google Gemini ile bağlamı koruyarak (tüm konuşma geçmişiyle) sohbet et; yanıtlar markdown olarak (kalın, başlık, madde işareti) render edilir. İlk yanıt kısa bir özet olarak gelir, detay istersen derinleşir. Mesajları tek dokunuşla kopyalayabilirsin.
- **Hafıza Kartları**: Bir metin yapıştırıp istediğin sayıda (5/10/15/20) soru-cevap kartı oluştur; kartları çevirerek çalış, quiz modunda "Bildim/Bilemedim" ile kendini sına.
- **Çoktan Seçmeli Testler**: Aynı metinden 5-20 arası test sorusu üret; her çözümde soru ve şık sırası karışır, yanlış cevaplarda açıklama gösterilir. Geçmiş denemelerin (hangi soruda hangi şıkkı işaretlediğin dahil) tutulur ve analiz edilebilir.
- **Dersler**: Sohbetlerini, kart setlerini ve testlerini derslere (ör. "Matematik", "CompTIA A+") göre grupla; her dersin kendi sohbet/kart/test sekmeleri var.
- **Keşfet**: Herkese açık, hazır örnek ders paketleriyle (özet + kartlar + test) yeni bir konuyu hemen dene; beğendiğini tek dokunuşla kendi derslerine kopyala.
- **Profil & İlerleme**: Özelleştirilebilir avatar/isim/yaş, toplam sohbet/set sayısı ve ortalama test başarısı gibi istatistikler, otomatik açılan başarım rozetleri, günlük çalışma serisi (streak) takibi ve "Bugün Ne Çalışayım?" hatırlatma kutusu.
- **Ayarlar**: Açık/Koyu/Sistem tema seçimi, sohbet yazı boyutu, hesap yönetimi (çıkış / hesabı kalıcı silme), bildirim tercihi yer tutucusu.
- **Hesap & Senkronizasyon**: Firebase Authentication (Google girişi veya misafir) ve Firestore ile tüm veriler hesaba bağlı, cihaz değişse de kaybolmaz.

## Kullanılan teknolojiler

Flutter, Google Gemini API, Firebase (Authentication, Cloud Firestore), flutter_markdown_plus, flutter_native_splash, SharedPreferences (yerel tercihler/misafir modu).
