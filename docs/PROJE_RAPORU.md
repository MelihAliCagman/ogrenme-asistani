# Öğrenme Asistanı — Proje Raporu

YKS'ye hazırlanan öğrenciler için geliştirilmiş, yapay zekâ destekli bir mobil çalışma asistanı. Bu rapor, uygulamanın ne yaptığını, nasıl çalıştığını ve alınan teknik kararları anlatır.

## 1. Amaç ve kapsam

Öğrencilerin dağınık çalışma materyallerini tek bir yerde toplamak ve her konuda hemen etkileşime geçebilmelerini sağlamak hedeflendi:

- **Müfredat takibi:** TYT, AYT ve YDT için ders > ünite > konu haritası.
- **Etkileşimli içerik:** Her konuda hafıza kartı, çoktan seçmeli test, boşluk doldurma, doğru/yanlış.
- **Yapay zekâ öğretmen:** Soru sorma, konu anlatma, fotoğraftan soru çözme.
- **Kişisel set üretimi:** Kendi metin/PDF'inden kart ve test üretme.
- **Motivasyon:** Seri, rozet, sınav geri sayımı, konu ilerleme halkaları.

Boyut: yaklaşık 14 bin satır uygulama kodu (87 Dart dosyası: 28 ekran, 19 model, 25 servis, 9 widget) ve 8 bin satır içerik/yönetim aracı.

## 2. Mimari

Uygulama katmanlı bir yapıdadır:

| Katman | Sorumluluk | Örnekler |
|---|---|---|
| **Ekranlar / widget'lar** | Arayüz ve kullanıcı etkileşimi | `HomeScreen`, `CurriculumScreen`, `PathDetailScreen`, `ChatScreen` |
| **Repository'ler** | Verinin nerede saklandığını gizler (Firestore) | `CardSetRepository`, `PathProgressRepository`, `ChatSessionRepository` |
| **Servisler** | Dış sistemlerle konuşur | `GeminiService`, `AuthService` |
| **Modeller** | Düz veri sınıfları (`fromJson`/`toJson`) | `QuizQuestion`, `CurriculumNode`, `NodeProgress` |
| **Kontrolcüler** | Uygulama genelindeki ayarlar (`ValueNotifier`) | `ThemeController`, `ChatFontSizeController` |

**Durum yönetimi:** Basit ve yeterli olduğu için `StatefulWidget` + `ValueNotifier` + `StreamBuilder` (Firestore dinleyicileri ve oturum durumu). Ayrı bir state management kütüphanesi kullanılmadı.

**Açılış akışı:** `SplashScreen` → `AuthGate` (oturumu dinler) → giriş yoksa `LoginScreen`, giriş var ama asistan profili yoksa `AvatarSelectionScreen`, aksi hâlde `MainScreen` (5 sekme, `IndexedStack` ile durum korunur).

## 3. Veri modeli (Cloud Firestore)

**Kullanıcıya özel veriler** (`users/{uid}/…`): `chats/{chatId}/messages`, `flashcard_sets`, `quiz_sets`, `subjects`, `exam_goals`, `flashcard_progress`, `quiz_progress`, `path_progress/{dersAnahtarı}`; ayrıca kullanıcı belgesinde `streak`, `userProfile` alanları.

**Herkese açık, istemciden yazılamayan veriler:**
- `curriculum_paths/{anahtar}` (ör. `tyt_fizik`): ders özeti (`title`, `unitCount`, `nodeCount`, `contentNodeCount`, `hasContent`) ve `units/{unitN}` alt koleksiyonu. Konular, okuma sayısını azaltmak için ünite belgesinin içine **dizi olarak gömülüdür** (bir ders = 1 + N belge okuması).
- `sample_lessons`: hazır örnek dersler (arayüzde şimdilik gizli).

**Liste saklama:** `FirestoreListStorage`, "liste = her öğe ayrı belge + `order` alanı" yaklaşımıyla çalışır, toplu yazma (batch) kullanır ve eski SharedPreferences tabanlı saklamanın API'siyle uyumludur; bu sayede yerelden buluta geçiş tek seferlik bir göç (`LocalToCloudMigration`) ile yapıldı.

## 4. Yapay zekâ entegrasyonu

Tüm çağrılar `GeminiService` içindedir (HTTP; anahtar URL'de değil `x-goog-api-key` başlığında).

- **Sohbet:** Her istekte konuşma geçmişi (`user`/`model` rolleriyle) gönderilir; yanıt **Server-Sent Events** ile parça parça gelir ve canlı gösterilir. Hata mesajı balonları geçmişe karışmaz. Yanıtlar markdown olarak render edilir.
- **Yapılandırılmış çıktı:** Kart ve test üretiminde `responseMimeType: application/json` ve `responseSchema` (dizi uzunluğu `minItems`/`maxItems` ile) kullanılır; dönen veri ayrıca doğrulanır (boş kayıt, geçersiz şık indeksi, bozuk karakter elenir).
- **Çok kipli girdi:** PDF dosyaları ve çekilen fotoğraflar `inlineData` (base64) ile metinle birlikte gönderilir.
- **Otomatik başlık:** İlk mesajdan 4 kelimelik sohbet başlığı üretilir.
- **Model:** `gemini-flash-lite` (hız ve ücretsiz kota nedeniyle).

## 5. Ders Yolları (müfredat haritası)

- **Yapı:** `CurriculumPath` → `CurriculumUnit` → `CurriculumNode`; her düğüm dört içerik türü taşır ve her tür küçük **parçalara** bölünür ("Kart Seti 1", "Test 2" …).
- **Tamamlanma mantığı:** Bir tür, ancak tüm parçaları en az bir kez tamamlanınca biter; bir düğüm, içeriği olan tüm türleri bitince tamamlanır ve sıradaki düğümün kilidi açılır. İçeriği hiç olmayan ("Yakında") konular tamamlanmış sayılmaz ve kilit açmaz (birim testiyle güvence altında).
- **Yeniden kullanım:** Bir parça ilk açıldığında içeriği kullanıcının kendi `flashcard_sets`/`quiz_sets` koleksiyonuna **deterministik bir kimlikle** (`path_{ders}_{düğüm}_{tür}_{parça}`) kopyalanır, sonraki açılışlarda güncel içerikle eşitlenir. Böylece mevcut kart ve test ekranları hiç değiştirilmeden kullanıldı.
- **Arayüz:** Zikzak yol, noktalı bağlantılar, `CustomPaint` ile çizilen dört dilimli ilerleme halkası, akordeon ünite başlıkları.

## 6. İçerik üretim hattı

Yaklaşık 550 konunun içeriği elle yazılmadı; `tool/` altındaki Dart araçlarıyla üretildi.

1. **Müfredat:** MEB'in ~580 sayfalık kazanım belgesi programatik okunarak ünite/konu başlıkları çıkarıldı (`yks_outline.txt`).
2. **Üretim:** Konu başına tek istekle 5 kart, 5 test, 5 boşluk doldurma, 5 doğru/yanlış. Dersler sırayla dönülerek işlenir (kota bitse bile her dersin ilk üniteleri dolar). Dakikalık istek sınırlayıcı ve kaldığı yerden devam özelliği vardır.
3. **Doğrulama:** Yapı kontrolü, benzer soruların elenmesi (Jaccard), şık sırasının karıştırılması, bozuk karakter ve **Türkçe harf kaybı** tespiti.
4. **Bağımsız çözüm geçişi:** Hesaplı derslerde model soruları cevapsız baştan çözer; uyuşmayan sorular silinir.
5. **Onarım:** Kayıp harfler modelden geri istenir ve yalnızca "ASCII'ye çevrildiğinde orijinalle birebir aynı" ise kabul edilir (anlam/sözcük değişikliği imkânsız).
6. **Aktarım:** Yönetici yetkili servis hesabıyla Firestore'a yazılır; yazma yetkisi istemcide yoktur.

## 7. Karşılaşılan zorluklar ve çözümler

| Sorun | Çözüm |
|---|---|
| Model, istenen sayıda kart/soru döndürmüyor | Şema sınırları + dönen verinin doğrulanması |
| Model Türkçe karakterleri düşürüyor ("hucre", "gore") | Veri güdümlü dedektör + "geri katlanınca aynı" kuralıyla güvenli onarım |
| Bir ünitede metinler yanlış kodlanmıştı ("Ã§") | Hatanın kuralına (UTF-8'in yanlış okunması) göre kesin geri çevirme |
| Hesaplı sorularda yanlış cevap işaretleme | İkinci, bağımsız çözüm geçişi |
| Ücretsiz kotanın dolması | Kaldığı yerden devam, sırayla dönme, kota saatinin (Pasifik gece yarısı) doğru tespiti |
| İçeriksiz konuların "tamamlanmış" sayılıp kilit açması | Düğüm tamamlanma koşulunun düzeltilmesi + test |
| Sayfa geçişlerinde saydam ekranların üst üste görünmesi | Her sayfayı kendi arka planıyla saran özel `PageTransitionsBuilder` |

## 8. Test ve kalite

- **Birim testleri (9):** düğüm/ünite tamamlanma mantığı, ilerleme kümesi davranışı, ünite sıralaması, soru modeli JSON gidiş-dönüşü.
- `flutter analyze` temiz.
- İçerik için otomatik doğrulama ve örnekleme (yaklaşık 32 bin metin tarandı).
- Fiziksel Android cihazda elle uçtan uca test.

## 9. Güvenlik ve maliyet

- Gizli dosyalar (`.env`, servis hesabı anahtarı) depoda yoktur; yayın öncesi sır taraması yapıldı.
- **Bilinen risk:** Gemini anahtarı geliştirme kolaylığı için `.env` ile uygulamaya paketlenir. Yayın öncesi çağrılar bir sunucuya (Cloud Functions) taşınmalı ve kullanıcı başına sınır konmalıdır.
- Toplu içerik üretimi ücretsiz kotayla yapıldı; ücretli kullanım için harcama sayacı (bütçeyi aşacak isteği başlatmayan) hazırdır.

## 10. Sınırlamalar ve yol haritası

- Üretilen içerik yapay zekâ çıktısıdır; bir öğretmen tarafından gözden geçirilmedi. Hesaplı derslerde bazı açıklamalar dolaşık olabilir.
- 17 konunun içeriği ("Yakında") doğrulamadan geçemediği için eksiktir.
- Yol haritası: sunucu tarafı yapay zekâ çağrıları ve kota, öğretmen incelemesi, kullanıcı geri bildirimiyle soru kalitesinin ölçülmesi, arama, bildirimler, widget/entegrasyon testleri ve CI.
