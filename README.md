# Öğrenme Asistanı

Flutter ile geliştirilen, yapay zeka destekli kişisel öğrenme asistanı Android uygulaması. Ders notlarını yapıştırıp otomatik flashcard üretebilir, konularla ilgili AI ile sohbet edip özel ders alabilir, oluşturduğun kartları quiz modunda tekrar edebilirsin.

Şu ana kadar tamamlanan özellikler:

- **AI Sohbet**: Google Gemini ile sohbet ederek soru sorma / özel ders alma.
- **Otomatik Flashcard Üretimi**: Bir ders notu/metin yapıştırıp tek tıkla soru-cevap kartı seti oluşturma.
- **Kalıcı Kart Setleri**: Oluşturulan kart setleri cihazda saklanır, uygulama kapanıp açılsa da kaybolmaz.
- **Quiz / Tekrar Modu**: Kartları karışık sırayla gösterip "Bildim / Bilemedim" ile kendi kendini sınama, sonunda özet skor.
- **Profil & Tema**: Uygulama bilgisi ve açık/koyu tema arasında kalıcı geçiş.

**Kullanılan teknolojiler:** Flutter, Google Gemini API, yerel depolama için SharedPreferences.
