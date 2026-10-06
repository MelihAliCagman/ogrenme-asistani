# Öğrenme Asistanı

YKS'ye hazırlanan öğrenciler için Flutter ile geliştirilen, yapay zeka destekli kişisel çalışma asistanı (Android). TYT, AYT ve YDT müfredatını ders, ünite ve konu konu takip edebilir, her konuda hafıza kartı ve test çözebilir, yapay zeka öğretmenle sohbet edip fotoğrafını çektiğin soruyu sorabilirsin.

## Özellikler

- **Müfredat (TYT / AYT / YDT):** 23 ders yolu, 177 ünite ve 550'den fazla konu. Ders listesi, ünite listesi ve konu haritası resmî MEB/ÖSYM 2026 kazanım belgesine göre hazırlandı. Her konuda 4 içerik tipi var: hafıza kartı, çoktan seçmeli test, boşluk doldurma ve doğru/yanlış. İçeriği henüz hazır olmayan konular "Yakında" olarak listelenir; her dersin kartında ne kadarının hazır olduğu görünür.
- **Ders Yolu:** Konu düğümlerinde 4 dilimli ilerleme halkası; bir konunun içerikleri bitince sıradakinin kilidi açılır. TYT Biyoloji tam içerikle (ünite başına onlarca kart ve soru) hazır.
- **Ana Sayfa:** Sınav hedefi geri sayımı, günlük çalışma serisi, TYT dersleri şeridi, hızlı erişim ve günün tavsiyesi.
- **AI Sohbet:** Google Gemini ile bağlamı koruyarak sohbet, birden fazla oturum, markdown yanıtlar. Fotoğraf çekip/yükleyip (kırpma/döndürme dahil) fotoğraftaki soruyu sorabilirsin.
- **Setlerim:** Bir metin ya da PDF'ten istediğin sayıda soru-cevap kartı veya çoktan seçmeli / boşluk doldurma / doğru-yanlış test üret; kartları elle de yazabilirsin. Kartları sağa/sola kaydırarak tekrar et, test geçmişin tutulur.
- **Profil & İlerleme:** Özelleştirilebilir avatar ve isim, istatistikler, otomatik açılan başarım rozetleri, günlük seri takibi, sınav hedefleri.
- **Ayarlar:** Açık/Koyu/Sistem tema, sohbet yazı boyutu, hesap yönetimi.
- **Hesap & Senkronizasyon:** Firebase Authentication (Google girişi veya misafir) ve Firestore; veriler hesaba bağlıdır.

## İçerik üretimi

Müfredat taslağı `tool/yks_outline.txt` dosyasındadır. Hafıza kartları ve sorular Gemini ile üretilir; üretim, doğrulama ve Firestore'a yazma araçları `tool/` altında Dart betikleri olarak durur (ayrıntı için `CLAUDE.md`). Üretilen içerik yapay zeka çıktısıdır ve kaynak metne dayanmaz; hesap gerektiren derslerde (Matematik, Fizik, Kimya) bağımsız bir ikinci çözüm geçişiyle çelişen sorular elenir. Yine de yayımlanmadan önce bir öğretmen tarafından gözden geçirilmelidir.

## Kullanılan teknolojiler

Flutter, Google Gemini API, Firebase (Authentication, Cloud Firestore), flutter_markdown_plus, flutter_native_splash, image_picker + image_cropper, SharedPreferences.
