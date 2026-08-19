# Öğrenme Asistanı

Flutter ile geliştirilen, yapay zeka destekli kişisel öğrenme asistanı Android uygulaması. Ders notlarını yapıştırıp otomatik hafıza kartı veya çoktan seçmeli test üretebilir, konularla ilgili AI ile sohbet edip özel ders alabilir, derslerini organize edip ilerlemeni takip edebilirsin.

## Özellikler

- **Ana Sayfa**: Sınav hedefi geri sayımı, günlük çalışma serisi (streak) durumu ve Sohbet/Derslerim/Keşfet/Ders Yolları'na hızlı erişim kartları.
- **AI Sohbet**: Google Gemini ile bağlamı koruyarak (tüm konuşma geçmişiyle) sohbet et, aynı anda birden fazla sohbet oturumu yönet; yanıtlar markdown olarak render edilir. Fotoğraf çekip/yükleyip (kırpma/döndürme dahil) o fotoğraftaki soruyu AI'a sorabilirsin.
- **Hafıza Kartları**: Bir metin yapıştırıp istediğin sayıda (5/10/15/20) soru-cevap kartı AI ile oluştur, ya da kartları elle tek tek yaz (manuel setler bir rozetle işaretlenir). Kartlara dokunup çevir, cevabı gördükten sonra sağa "bildim" / sola "bilemedim" kaydırarak tekrar et.
- **Testler**: Aynı metinden Çoktan Seçmeli, Boşluk Doldurma veya Doğru/Yanlış formatında 10-20 arası soru üret; her çözümde soru ve şık sırası karışır, yanlış cevaplarda açıklama gösterilir. Geçmiş denemelerin (hangi soruda ne işaretlediğin dahil) tutulur ve analiz edilebilir; set listelerinde formatı gösteren bir rozet bulunur.
- **Dersler**: Sohbetlerini, kart setlerini ve testlerini derslere (ör. "Matematik", "CompTIA A+") göre grupla; her dersin kendi sohbet/kart/test sekmeleri var.
- **Ders Yolları**: Duolingo tarzı, seçili derslerde ünite/konu haritasında ilerle. Her konu düğümünün etrafında 4 içerik tipini (Hafıza Kartı, Çoktan Seçmeli, Boşluk Doldurma, Doğru/Yanlış) gösteren bir ilerleme halkası bulunur; bir konunun 4 içerik tipi de tamamlanınca sıradaki konunun kilidi açılır.
- **Keşfet**: Herkese açık, hazır örnek ders paketleriyle (özet + kartlar + test) yeni bir konuyu hemen dene; beğendiğini tek dokunuşla kendi derslerine kopyala.
- **Sınav Hedeflerim**: Sınav adı ve tarihiyle hedef oluştur, Ana Sayfa'da geri sayımını takip et.
- **Profil & İlerleme**: Özelleştirilebilir avatar/isim/yaş, toplam sohbet/set sayısı ve ortalama test başarısı gibi istatistikler, otomatik açılan başarım rozetleri, günlük çalışma serisi (streak) takibi.
- **Ayarlar**: Açık/Koyu/Sistem tema seçimi, sohbet yazı boyutu, hesap yönetimi (çıkış / hesabı kalıcı silme), bildirim tercihi yer tutucusu.
- **Hesap & Senkronizasyon**: Firebase Authentication (Google girişi veya misafir) ve Firestore ile tüm veriler hesaba bağlı, cihaz değişse de kaybolmaz.

## Kullanılan teknolojiler

Flutter, Google Gemini API, Firebase (Authentication, Cloud Firestore), flutter_markdown_plus, flutter_native_splash, image_picker + image_cropper (fotoğrafla soru sorma), SharedPreferences (yerel tercihler/misafir modu).
