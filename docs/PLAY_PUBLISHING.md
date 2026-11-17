# Публікація в Google Play через API (fastlane)

Релізи збираються й завантажуються командою з терміналу (або Claude) через
service account — окремий «технічний користувач» Google з правами лише на
TunisGO. Пароль від вашого Google-акаунта не потрібен; доступ можна відкликати
будь-коли в Play Console.

## 1. Service account (одноразово, ~10 хв)

1. **Google Cloud Console** → <https://console.cloud.google.com/> → вгорі виберіть
   або створіть проєкт (наприклад `tunisgo-publishing`).
2. **APIs & Services → Library** → знайдіть **Google Play Android Developer API**
   → **Enable**.
3. **IAM & Admin → Service Accounts → Create service account**
   - Name: `tunisgo-play-publisher`
   - Ролі в Google Cloud **не додавайте** (крок «Grant access» пропустіть) → **Done**.
4. Відкрийте створений акаунт → вкладка **Keys → Add key → Create new key → JSON**.
   Файл завантажиться в `Downloads`.
5. Перенесіть ключ **поза проєкт** і закрийте доступ іншим:
   ```bash
   mkdir -p ~/.config/tunisgo
   mv ~/Downloads/tunisgo-publishing-*.json ~/.config/tunisgo/play-service-account.json
   chmod 600 ~/.config/tunisgo/play-service-account.json
   ```
   Інший шлях можна задати змінною `PLAY_JSON_KEY`.
6. Скопіюйте email акаунта (`tunisgo-play-publisher@<проєкт>.iam.gserviceaccount.com`).

## 2. Права в Play Console

**Play Console → Users and permissions → Invite new users**

- Email: email service account з кроку 1.6.
- **Account permissions**: нічого не вмикайте.
- **App permissions → Add app → TunisGO**, лише:
  - *View app information and download bulk reports (read-only)*
  - *Release apps to testing tracks*
  - *Manage testing tracks and edit tester lists*
  - *Release to production, exclude devices, and use Play App Signing* — тільки якщо
    хочете, щоб `fastlane promote to:production` працював; інакше в продакшн
    випускаєте вручну.
  - *Manage store presence* — тільки для завантаження опису/скриншотів.
- Фінансові права, керування користувачами та адмін-права **не давайте**.
- **Invite user**. Права зазвичай діють за кілька хвилин (зрідка до доби).

## 3. Ключ підпису (upload key)

Play підписує додаток своїм ключем (Play App Signing), а ми підписуємо збірку
лише **upload key**, яким Play перевіряє, що завантажує саме власник.

Поточний upload key створено в листопаді 2026 (старий втрачено):

| Файл | Що це |
|---|---|
| `~/.config/tunisgo/upload-keystore.jks` | keystore (alias `upload`, RSA 4096, 10000 днів) |
| `android/key.properties` | шлях і пароль до нього (у `.gitignore`) |
| `~/.config/tunisgo/upload_certificate.pem` | публічний сертифікат для Play |

**Обов'язково зробіть резервну копію** `upload-keystore.jks` і пароля з
`android/key.properties` (менеджер паролів, зашифрований диск). Без них
оновлення знову доведеться відкладати на скидання ключа.

### Скидання upload key після втрати (одноразово)

1. **Play Console → TunisGO → Protected with Play → App signing**
   (раніше: *Test and release → App integrity → Play app signing*).
2. Переконайтеся, що є блок **App signing key** зі статусом *In use* — тобто
   ключем підпису керує Google. Якщо його немає, upload key скинути не можна.
3. Блок **Upload key** → **Request reset** → причина *I lost my upload key* →
   завантажте `~/.config/tunisgo/upload_certificate.pem` → **Request**.
   (`.config` — прихована папка: у вікні вибору файла натисніть
   `Cmd+Shift+G` і введіть `~/.config/tunisgo`.)
4. Google надішле лист власнику акаунта. Новий ключ починає діяти з дати,
   вказаної в Play Console (зазвичай через ~2 дні). До того `fastlane internal`
   збере `.aab`, але Play відхилить завантаження з помилкою про підпис.

Firebase додаток не використовує, тому `google-services.json` не потрібен.

## 4. Команди

```bash
cd android
fastlane check                                 # перевірка ключа, version codes на треках
fastlane internal                              # збірка .aab → Internal testing (чернетка)
fastlane internal status:completed             # … і одразу тестерам
fastlane promote to:production                 # internal → production (чернетка)
fastlane promote to:production rollout:0.2     # … одразу на 20 % користувачів
fastlane metadata_pull                         # опис/скриншоти з Play у fastlane/metadata
```

- Перед збіркою підніміть build number у `pubspec.yaml` (`version: 2.1.0+9`);
  `internal` зупиниться, якщо такий номер уже є в Play.
- Збірка автоматично отримує `--dart-define=WORKER_URL=https://tunisgo-live.tunisgo.workers.dev`
  (інший — змінною `WORKER_URL`).
- Нотатки до релізу: `android/fastlane/metadata/android/<мова>/changelogs/<versionCode>.txt`
  (з'являться після `metadata_pull`).
- За замовчуванням усе завантажується **чернеткою**: реліз видно в Play Console,
  але користувачам він не дістанеться, доки ви не натиснете «Опублікувати».

## Відкликати доступ

Play Console → Users and permissions → service account → **Remove access**, і/або
Google Cloud → Service Accounts → Keys → видалити ключ.
