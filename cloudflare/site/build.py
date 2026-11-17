#!/usr/bin/env python3
"""Builds the TunisGO landing pages (public/index.html, /fr/, /ar/, /ru/),
robots.txt and sitemap.xml. Edit the texts below and run:

    cd cloudflare/site && python3 build.py      (needs: pip install segno)

Deploy: npx wrangler pages deploy public --project-name tunisgo --branch main
"""
import html
import json
import urllib.parse
import pathlib

import segno  # pip install segno

import routes as R

BASE = "https://tunisgo.pages.dev"
EMAIL = "mnik.dev@proton.me"
CONTACT_LABEL = {"en": "Contact:", "fr": "Contact :", "ar": "للتواصل:", "ru": "Контакты:"}
PLAY = "https://play.google.com/store/apps/details?id=com.tunisgo"
PUBLIC = pathlib.Path(__file__).resolve().parent / "public"

LANGS = {
    "en": {
        "path": "/",
        "dir": "ltr",
        "play_hl": "en",
        "title": "TunisGO — Tunisia train, metro and TGM timetable, live delays",
        "description": "Train, metro and TGM schedules in Tunisia: SNCFT trains and the TRANSTU light metro and TGM between any two stations, live train delays, works offline. Free Android app in English, French, Arabic and Russian.",
        "h1": "Train, metro and TGM timetable for Tunisia",
        "lead": "TunisGO shows SNCFT train schedules and the TRANSTU light metro and TGM between any two stations in Tunisia, with live train delays and cancellations — and it works without internet.",
        "cta": "Get it on Google Play",
        "qr_caption": "Scan to install on your phone",
        "features_h": "What you get",
        "features": [
            ("Train times between two stations", "Departure and arrival times, duration, train number and every stop."),
            ("Station timetable", "All departures and arrivals at your station, main lines and suburban trains."),
            ("Light metro and TGM", "All 6 Tunis light metro lines and the TGM to La Marsa, from TRANSTU's first and last departures and frequency (times at stations are estimated)."),
            ("Live delays", "Which trains are on time, late or cancelled, from data published by SNCFT."),
            ("Reminders and favorites", "Save your daily trains and get a reminder before departure."),
            ("Works offline", "The whole timetable is on your phone — no data needed in the metro or while roaming."),
            ("Always up to date", "Winter, summer and Ramadan timetables are updated automatically."),
        ],
        "routes_h": "Popular train routes",
        "routes": ["Tunis – Sousse", "Tunis – Sfax", "Tunis – Monastir", "Sousse – Mahdia", "Tunis – Gabès", "Tunis – Bizerte", "Tunis – Nabeul", "Tunis – Hammam-Lif", "Tunis – Borj Cédria", "Tunis – Jendouba", "Tunis – Gafsa", "Monastir – Sousse"],
        "routes_note": "Around 240 stations of the SNCFT network: Tunis, Sousse, Monastir, Mahdia, Sfax, Gabès, Gafsa, Tozeur, Bizerte, Béja, Jendouba, Ghardimaou, Kasserine, Nabeul, Hammamet and the southern suburbs (Banlieue Sud).",
        "faq_h": "Questions",
        "faq": [
            ("Where can I find the SNCFT train schedule?", "TunisGO has the full SNCFT timetable for all of Tunisia. Pick your departure and arrival stations to see every train of the day."),
            ("Can I see if my train is late?", "Yes. The live departure board and the trip details show delays and cancellations published by SNCFT."),
            ("Does it have the Tunis metro and the TGM?", "Yes. The six light metro lines and the TGM Tunis Marine – La Marsa are in search and in Lines. TRANSTU publishes only first and last departures and the frequency, so times at each station are estimates."),
            ("Does it work without internet?", "Yes. Timetables are stored on the phone; only live delays need a connection."),
        ],
        "disclaimer": "TunisGO is an independent app and is not affiliated with SNCFT (Société Nationale des Chemins de Fer Tunisiens) or TRANSTU (Société des Transports de Tunis). Timetables may change; for important trips, check with the operator or at the station.",
        "shots_alt": "TunisGO app screenshot",
    },
    "fr": {
        "path": "/fr/",
        "dir": "ltr",
        "play_hl": "fr",
        "title": "TunisGO — Horaires train, métro et TGM en Tunisie, retards en direct",
        "description": "Horaires des trains SNCFT, du métro léger et du TGM de la TRANSTU en Tunisie entre deux stations, retards des trains en direct, fonctionne hors ligne. Application Android gratuite en français, arabe, anglais et russe.",
        "h1": "Horaires des trains, du métro et du TGM en Tunisie",
        "lead": "TunisGO affiche les horaires des trains SNCFT et du métro léger et du TGM de la TRANSTU entre deux stations en Tunisie, avec les retards et suppressions des trains en direct — et fonctionne sans internet.",
        "cta": "Disponible sur Google Play",
        "qr_caption": "Scannez pour installer sur votre téléphone",
        "features_h": "Fonctionnalités",
        "features": [
            ("Horaires entre deux gares", "Heures de départ et d'arrivée, durée, numéro du train et tous les arrêts."),
            ("Horaires par gare", "Tous les départs et arrivées de votre gare, grandes lignes et banlieue."),
            ("Métro léger et TGM", "Les 6 lignes du métro léger de Tunis et le TGM vers La Marsa, d'après les premiers et derniers départs et la fréquence de la TRANSTU (heures aux stations estimées)."),
            ("Retards en direct", "Trains à l'heure, en retard ou supprimés, d'après les données publiées par la SNCFT."),
            ("Rappels et favoris", "Enregistrez vos trains quotidiens et recevez un rappel avant le départ."),
            ("Hors ligne", "Tous les horaires sont sur votre téléphone — pas besoin de connexion dans le métro ou en roaming."),
            ("Toujours à jour", "Horaires d'hiver, d'été et du Ramadan mis à jour automatiquement."),
        ],
        "routes_h": "Trajets en train populaires",
        "routes": ["Tunis – Sousse", "Tunis – Sfax", "Tunis – Monastir", "Sousse – Mahdia", "Tunis – Gabès", "Tunis – Bizerte", "Tunis – Nabeul", "Tunis – Hammam-Lif", "Tunis – Borj Cédria", "Tunis – Jendouba", "Tunis – Gafsa", "Monastir – Sousse"],
        "routes_note": "Environ 240 gares du réseau SNCFT : Tunis, Sousse, Monastir, Mahdia, Sfax, Gabès, Gafsa, Tozeur, Bizerte, Béja, Jendouba, Ghardimaou, Kasserine, Nabeul, Hammamet et la banlieue sud.",
        "faq_h": "Questions fréquentes",
        "faq": [
            ("Où trouver les horaires des trains SNCFT ?", "TunisGO contient tous les horaires SNCFT de la Tunisie. Choisissez la gare de départ et d'arrivée pour voir tous les trains de la journée."),
            ("Y a-t-il le métro de Tunis et le TGM ?", "Oui. Les six lignes du métro léger et le TGM Tunis Marine – La Marsa sont dans la recherche et dans Lignes. La TRANSTU ne publie que les premiers et derniers départs et la fréquence : les heures à chaque station sont donc estimées."),
            ("Puis-je savoir si mon train est en retard ?", "Oui. Le tableau des départs en direct et le détail du trajet affichent les retards et suppressions publiés par la SNCFT."),
            ("L'application fonctionne-t-elle sans internet ?", "Oui. Les horaires sont enregistrés sur le téléphone ; seuls les retards en direct nécessitent une connexion."),
        ],
        "disclaimer": "TunisGO est une application indépendante, non affiliée à la SNCFT (Société Nationale des Chemins de Fer Tunisiens) ni à la TRANSTU (Société des Transports de Tunis). Les horaires peuvent changer ; pour un trajet important, vérifiez auprès de l'opérateur ou en station.",
        "shots_alt": "Capture d'écran de l'application TunisGO",
    },
    "ar": {
        "path": "/ar/",
        "dir": "rtl",
        "play_hl": "ar",
        "title": "TunisGO — مواعيد القطار والمترو و ت.ح.م في تونس، التأخير مباشرة",
        "description": "مواعيد قطارات SNCFT والمترو الخفيف و ت.ح.م لشركة نقل تونس بين أي محطتين، تأخير القطارات مباشرة، ويعمل بدون إنترنت. تطبيق أندرويد مجاني بالعربية والفرنسية والإنجليزية والروسية.",
        "h1": "مواعيد القطار والمترو و ت.ح.م في تونس",
        "lead": "يعرض TunisGO أوقات قطارات SNCFT والمترو الخفيف و ت.ح.م لشركة نقل تونس بين أي محطتين، مع تأخير القطارات وإلغائها مباشرة — ويعمل بدون إنترنت.",
        "cta": "احصل عليه من Google Play",
        "qr_caption": "امسح الرمز لتثبيت التطبيق على هاتفك",
        "features_h": "المميزات",
        "features": [
            ("أوقات القطار بين محطتين", "وقت الانطلاق والوصول، مدة الرحلة، رقم القطار وجميع المحطات."),
            ("جدول المحطة", "كل القطارات المغادرة والواصلة إلى محطتك، الخطوط الكبرى وقطارات الضاحية."),
            ("المترو الخفيف و ت.ح.م", "خطوط المترو الخفيف الستة بتونس و ت.ح.م نحو المرسى، حسب أول وآخر سفرة والتواتر لشركة نقل تونس (الأوقات في المحطات تقديرية)."),
            ("التأخير مباشرة", "القطارات في الموعد أو المتأخرة أو الملغاة حسب البيانات التي تنشرها SNCFT."),
            ("التذكيرات والمفضلة", "احفظ قطاراتك اليومية واحصل على تذكير قبل الانطلاق."),
            ("بدون إنترنت", "جميع المواعيد على هاتفك — لا حاجة للاتصال في المترو أو أثناء التجوال."),
            ("محدّث دائمًا", "مواعيد الشتاء والصيف ورمضان تُحدَّث تلقائيًا."),
        ],
        "routes_h": "رحلات القطار الأكثر طلبًا",
        "routes": ["تونس – سوسة", "تونس – صفاقس", "تونس – المنستير", "سوسة – المهدية", "تونس – قابس", "تونس – بنزرت", "تونس – نابل", "تونس – حمام الأنف", "تونس – برج السدرية", "تونس – جندوبة", "تونس – قفصة", "المنستير – سوسة"],
        "routes_note": "حوالي 240 محطة في شبكة SNCFT: تونس، سوسة، المنستير، المهدية، صفاقس، قابس، قفصة، توزر، بنزرت، باجة، جندوبة، غار الدماء، القصرين، نابل، الحمامات والضاحية الجنوبية.",
        "faq_h": "أسئلة شائعة",
        "faq": [
            ("أين أجد مواعيد قطارات SNCFT؟", "يحتوي TunisGO على جميع مواعيد SNCFT في كامل تونس. اختر محطة الانطلاق والوصول لترى كل قطارات اليوم."),
            ("هل يتضمن مترو تونس و ت.ح.م؟", "نعم. خطوط المترو الخفيف الستة و ت.ح.م تونس البحرية – المرسى موجودة في البحث وفي الخطوط. تنشر شركة نقل تونس أول وآخر سفرة والتواتر فقط، لذا فالأوقات في كل محطة تقديرية."),
            ("هل يمكنني معرفة إن كان القطار متأخرًا؟", "نعم. لوحة المغادرة المباشرة وتفاصيل الرحلة تعرض التأخير والإلغاء الذي تنشره SNCFT."),
            ("هل يعمل التطبيق بدون إنترنت؟", "نعم. المواعيد محفوظة على الهاتف؛ فقط التأخير المباشر يحتاج إلى اتصال."),
        ],
        "disclaimer": "TunisGO تطبيق مستقل وغير تابع للشركة الوطنية للسكك الحديدية التونسية (SNCFT) ولا لشركة نقل تونس (TRANSTU). قد تتغير المواعيد؛ بالنسبة للرحلات المهمة، يرجى التأكد لدى الناقل أو في المحطة.",
        "shots_alt": "لقطة شاشة من تطبيق TunisGO",
    },
    "ru": {
        "path": "/ru/",
        "dir": "ltr",
        "play_hl": "ru",
        "title": "TunisGO — расписание поездов, метро и TGM в Тунисе, задержки онлайн",
        "description": "Расписание поездов SNCFT, лёгкого метро и TGM компании TRANSTU в Тунисе между любыми станциями, задержки поездов онлайн, работает без интернета. Бесплатное приложение для Android на русском, английском, французском и арабском.",
        "h1": "Расписание поездов, метро и TGM в Тунисе",
        "lead": "TunisGO показывает расписание поездов SNCFT, лёгкого метро и TGM компании TRANSTU между любыми станциями Туниса, задержки и отмены поездов в реальном времени — и работает без интернета.",
        "cta": "Доступно в Google Play",
        "qr_caption": "Отсканируйте, чтобы установить на телефон",
        "features_h": "Возможности",
        "features": [
            ("Поезда между двумя станциями", "Время отправления и прибытия, время в пути, номер поезда и все остановки."),
            ("Расписание по станции", "Все отправления и прибытия на вашем вокзале — дальние поезда и электрички."),
            ("Лёгкое метро и TGM", "Все 6 линий лёгкого метро Туниса и TGM до Ла-Марсы — по первому и последнему рейсу и интервалу TRANSTU (время на станциях примерное)."),
            ("Задержки онлайн", "Какие поезда идут по расписанию, опаздывают или отменены, по данным SNCFT."),
            ("Напоминания и избранное", "Сохраняйте ежедневные поезда и получайте напоминание перед отправлением."),
            ("Без интернета", "Всё расписание хранится в телефоне — в метро и в роуминге интернет не нужен."),
            ("Всегда актуально", "Зимнее, летнее и рамаданское расписание обновляется автоматически."),
        ],
        "routes_h": "Популярные направления",
        "routes": ["Тунис – Сусс", "Тунис – Сфакс", "Тунис – Монастир", "Сусс – Махдия", "Тунис – Габес", "Тунис – Бизерта", "Тунис – Набёль", "Тунис – Хаммам-Лиф", "Тунис – Бордж-Седрия", "Тунис – Джендуба", "Тунис – Гафса", "Монастир – Сусс"],
        "routes_note": "Около 240 станций сети SNCFT: Тунис, Сусс, Монастир, Махдия, Сфакс, Габес, Гафса, Тозёр, Бизерта, Беджа, Джендуба, Гардимау, Кассерин, Набёль, Хаммамет и южные пригороды.",
        "faq_h": "Вопросы",
        "faq": [
            ("Где посмотреть расписание поездов SNCFT?", "В TunisGO есть полное расписание SNCFT по всему Тунису. Выберите станции отправления и прибытия, чтобы увидеть все поезда за день."),
            ("Есть ли метро Туниса и TGM?", "Да. Шесть линий лёгкого метро и TGM Тунис-Марин – Ла-Марса есть в поиске и в «Линиях». TRANSTU публикует только первый и последний рейс и интервал, поэтому время на каждой станции примерное."),
            ("Можно узнать, опаздывает ли поезд?", "Да. Табло отправлений и детали поездки показывают задержки и отмены, которые публикует SNCFT."),
            ("Работает ли приложение без интернета?", "Да. Расписание хранится в телефоне; интернет нужен только для задержек в реальном времени."),
        ],
        "disclaimer": "TunisGO — независимое приложение, не связанное с SNCFT (Société Nationale des Chemins de Fer Tunisiens) и TRANSTU (Société des Transports de Tunis). Расписание может меняться; перед важной поездкой уточняйте у перевозчика или на станции.",
        "shots_alt": "Скриншот приложения TunisGO",
    },
}

LANG_NAMES = {"en": "English", "fr": "Français", "ar": "العربية", "ru": "Русский"}

# Public roadmap on the home page. Seasons only, no exact dates, no ticket sales
# (depends on an SNCFT agreement). Internal plan: brain/Growth/Roadmap.md.
ROADMAP = {
    "en": {
        "h": "Coming next",
        "lead": "TunisGO keeps growing. Here is what we are working on.",
        "items": [
            ("done", "Now", "Home-screen widget", "Your next favourite trains right on the Android home screen."),
            ("next", "Winter 2027", "Ramadan timetable", "SNCFT Ramadan schedules in the app before the month starts."),
            ("next", "Spring 2027", "Timetable vs reality", "A “this time is wrong” button and automatic checks against live data, so the timetable stays accurate."),
            ("done", "Now", "Tunis light metro and TGM", "All 6 TRANSTU light metro lines and the TGM, with estimated times from the official first and last departures and frequency."),
            ("later", "2027", "Intercity buses", "SNTRI coach timetables for towns without a railway."),
        ],
        "idea": "Have an idea? Write to us",
        "subject": "TunisGO idea",
    },
    "fr": {
        "h": "Bientôt dans TunisGO",
        "lead": "TunisGO continue d'évoluer. Voici ce qui arrive.",
        "items": [
            ("done", "Disponible", "Widget d'écran d'accueil", "Vos prochains trains favoris directement sur l'écran d'accueil Android."),
            ("next", "Hiver 2027", "Horaires du Ramadan", "Les horaires SNCFT du Ramadan dans l'application avant le début du mois."),
            ("next", "Printemps 2027", "Horaires vérifiés", "Un bouton « horaire incorrect » et une comparaison automatique avec les données en direct, pour des horaires toujours justes."),
            ("done", "Disponible", "Métro léger de Tunis et TGM", "Les 6 lignes du métro léger et le TGM de la TRANSTU, avec des heures estimées d'après les premiers et derniers départs et la fréquence officiels."),
            ("later", "2027", "Bus interurbains", "Les horaires des cars SNTRI pour les villes sans gare."),
        ],
        "idea": "Une idée ? Écrivez-nous",
        "subject": "Idée pour TunisGO",
    },
    "ar": {
        "h": "قريبًا في TunisGO",
        "lead": "يتطور TunisGO باستمرار. إليك ما نعمل عليه.",
        "items": [
            ("done", "متوفر الآن", "أداة الشاشة الرئيسية", "قطاراتك المفضلة التالية مباشرة على الشاشة الرئيسية في أندرويد."),
            ("next", "شتاء 2027", "مواعيد رمضان", "مواعيد قطارات الشركة الوطنية للسكك الحديدية في رمضان داخل التطبيق قبل بداية الشهر."),
            ("next", "ربيع 2027", "مواعيد دقيقة", "زر «الموعد غير صحيح» ومقارنة تلقائية مع البيانات المباشرة لتبقى المواعيد دقيقة."),
            ("done", "متوفر الآن", "المترو الخفيف و ت.ح.م", "خطوط المترو الخفيف الستة و ت.ح.م لشركة نقل تونس، بأوقات تقديرية حسب أول وآخر سفرة والتواتر الرسمية."),
            ("later", "2027", "الحافلات بين المدن", "مواعيد حافلات الشركة الوطنية للنقل بين المدن للمدن التي لا تمر بها السكك الحديدية."),
        ],
        "idea": "لديك فكرة؟ راسلنا",
        "subject": "فكرة لتطبيق TunisGO",
    },
    "ru": {
        "h": "Скоро в TunisGO",
        "lead": "TunisGO развивается. Вот над чем мы работаем.",
        "items": [
            ("done", "Уже есть", "Виджет на главный экран", "Ближайшие избранные поезда прямо на главном экране Android."),
            ("next", "Зима 2027", "Расписание на Рамадан", "Расписание SNCFT на Рамадан в приложении до начала месяца."),
            ("next", "Весна 2027", "Сверка с реальностью", "Кнопка «время неверное» и автоматическая сверка с онлайн-данными, чтобы расписание оставалось точным."),
            ("done", "Уже есть", "Лёгкое метро и TGM", "Все 6 линий лёгкого метро и TGM компании TRANSTU, с примерным временем по официальным первому и последнему рейсу и интервалу."),
            ("later", "2027", "Междугородние автобусы", "Расписание автобусов SNTRI для городов без железной дороги."),
        ],
        "idea": "Есть идея? Напишите нам",
        "subject": "Идея для TunisGO",
    },
}


CSS = """
:root{--bg:#f7f8fa;--fg:#14202b;--muted:#5b6672;--card:#fff;--line:#e3e7ec;--accent:#c8102e;--accent-fg:#fff}
@media (prefers-color-scheme:dark){:root{--bg:#0f1418;--fg:#e8edf2;--muted:#9aa6b2;--card:#182027;--line:#26313a;--accent:#ff4d5e;--accent-fg:#111}}
*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Arabic",sans-serif}
.wrap{max-width:960px;margin:0 auto;padding:0 16px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:16px 0;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;font-size:20px;color:inherit;text-decoration:none}
.brand img{width:40px;height:40px;border-radius:10px}
nav a{color:var(--muted);text-decoration:none;margin-inline-start:12px;font-size:14px}
nav a[aria-current]{color:var(--fg);font-weight:600}
.hero{display:grid;gap:24px;padding:24px 0 8px}
@media(min-width:760px){.hero{grid-template-columns:1.2fr 1fr;align-items:center}}
h1{font-size:clamp(28px,5vw,44px);line-height:1.15;margin:0 0 12px}
.lead{font-size:18px;color:var(--muted);margin:0 0 20px}
.get{display:flex;align-items:center;gap:20px;flex-wrap:wrap}
.play img{display:block;height:64px;width:auto}
.qr{display:none;align-items:center;gap:14px;background:var(--card);border:1px solid var(--line);border-radius:18px;padding:10px;padding-inline-end:16px}
.qr svg{display:block;width:132px;height:132px;background:#fff;border-radius:12px}
.qr span{font-size:14px;color:var(--muted);max-width:150px;line-height:1.35}
@media(min-width:760px){.qr{display:flex}}
.shots{display:flex;gap:10px;justify-content:center}
.shots img{width:31%;max-width:180px;height:auto;border-radius:14px;border:1px solid var(--line)}
h2{font-size:24px;margin:40px 0 16px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(240px,1fr))}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px}
.card h3{margin:0 0 6px;font-size:17px}.card p{margin:0;color:var(--muted)}
.routes{display:flex;flex-wrap:wrap;gap:8px;padding:0;margin:0;list-style:none}
.routes li{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 12px;font-size:15px}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 16px;margin-bottom:8px}
summary{cursor:pointer;font-weight:600}
footer{color:var(--muted);font-size:13px;padding:40px 0 32px}
.contact{font-size:15px;color:var(--fg);margin-bottom:16px}.contact a{font-weight:600}
.routes a{color:inherit;text-decoration:none}
.crumbs{font-size:14px;color:var(--muted);margin:8px 0 0}.crumbs a{color:var(--muted)}
.facts{display:flex;flex-wrap:wrap;gap:10px;margin:16px 0 8px;padding:0;list-style:none}
.facts li{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px}
.facts b{display:block;font-size:20px}
.tt{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;font-variant-numeric:tabular-nums}
.tt th,.tt td{padding:10px 12px;text-align:start;border-bottom:1px solid var(--line)}
.tt th{font-size:13px;color:var(--muted);font-weight:600}
.tt tr:last-child td{border-bottom:0}
.tt .t{font-weight:700;font-size:17px}
.note{color:var(--muted);font-size:14px}
.promo{display:flex;align-items:center;gap:16px;flex-wrap:wrap;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin:28px 0}
.promo p{margin:0;flex:1;min-width:220px;font-weight:600}
.promo img{display:block;height:56px;width:auto}
.cities{columns:2 220px;padding:0;list-style:none}.cities li{break-inside:avoid;margin-bottom:14px}
.road{list-style:none;padding:0;margin:0;display:grid;gap:10px}
.road li{display:flex;gap:14px;align-items:flex-start;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px}
.road .when{flex:0 0 auto;font-size:13px;font-weight:600;border-radius:999px;padding:3px 10px;border:1px solid var(--line);color:var(--muted);white-space:nowrap}
.road .done .when{background:#319349;border-color:#319349;color:#fff}
.road .next .when{color:var(--accent);border-color:var(--accent)}
.road h3{margin:0 0 4px;font-size:17px}.road p{margin:0;color:var(--muted)}
.idea{margin:12px 0 0}.idea a{font-weight:600;color:var(--accent)}
.cities h3{margin:0 0 6px;font-size:16px}.cities a{display:inline-block;margin:0 10px 4px 0;color:inherit}
"""


def qr_svg(url):
    """QR in the site's style: dark dots, rounded finders with a red core,
    the app icon in the middle (error correction H). Always on white so it scans
    in dark mode too."""
    qr = segno.make(url, error="h", boost_error=False)
    rows = [list(r) for r in qr.matrix]
    n, q = len(rows), 3
    size = n + 2 * q
    hole = int(n * 0.24) | 1
    lo, hi = (n - hole) // 2, (n - hole) // 2 + hole

    def finder(r, c):
        return (r < 7 and c < 7) or (r < 7 and c >= n - 7) or (r >= n - 7 and c < 7)

    dots = "".join(
        f'<circle cx="{c + q + .5}" cy="{r + q + .5}" r=".46"/>'
        for r in range(n) for c in range(n)
        if rows[r][c] and not finder(r, c) and not (lo <= r < hi and lo <= c < hi)
    )
    fs = "".join(
        f'<rect x="{c + q + .5}" y="{r + q + .5}" width="6" height="6" rx="1.8" fill="none" stroke="#14202b"/>'
        f'<rect x="{c + q + 2}" y="{r + q + 2}" width="3" height="3" rx=".9" fill="#c8102e"/>'
        for r, c in ((0, 0), (0, n - 7), (n - 7, 0))
    )
    x = lo + q
    logo = (
        f'<rect x="{x + .3}" y="{x + .3}" width="{hole - .6}" height="{hole - .6}" rx="{hole * .24:.2f}" fill="#fff"/>'
        f'<image href="/img/icon-192.png" x="{x + .8}" y="{x + .8}" width="{hole - 1.6}" height="{hole - 1.6}"/>'
    )
    return (
        f'<svg viewBox="0 0 {size} {size}" role="img" aria-label="QR {esc(url)}" xmlns="http://www.w3.org/2000/svg">'
        f'<g fill="#14202b">{dots}</g>{fs}{logo}</svg>'
    )


def esc(s):
    return html.escape(s, quote=True)


def page(code, t):
    url = BASE + t["path"]
    play = f"{PLAY}&hl={t['play_hl']}"
    alternates = "\n".join(
        f'<link rel="alternate" hreflang="{c}" href="{BASE}{v["path"]}">' for c, v in LANGS.items()
    ) + f'\n<link rel="alternate" hreflang="x-default" href="{BASE}/">'
    current = ' aria-current="page"'
    nav = "".join(
        f'<a href="{v["path"]}" hreflang="{c}" lang="{c}"{current if c == code else ""}>{LANG_NAMES[c]}</a>'
        for c, v in LANGS.items()
    )
    features = "".join(
        f'<div class="card"><h3>{esc(h)}</h3><p>{esc(p)}</p></div>' for h, p in t["features"]
    )
    routes = "".join(
        f'<li><a href="{route_path(code, a, b)}">{esc(R.name(a, code))} – {esc(R.name(b, code))}</a></li>'
        for a, b in POPULAR if (a, b) in ROUTES
    ) + f'<li><a href="{lang_prefix(code)}/train/">{esc(RT[code]["all_routes"])} →</a></li>'
    rm = ROADMAP[code]
    road = "".join(
        f'<li class="{st}"><span class="when">{esc(w)}</span><div><h3>{esc(h)}</h3><p>{esc(p)}</p></div></li>'
        for st, w, h, p in rm["items"]
    )
    idea = f'mailto:{EMAIL}?subject={urllib.parse.quote(rm["subject"])}'
    faq = "".join(
        f"<details><summary>{esc(q)}</summary><p>{esc(a)}</p></details>" for q, a in t["faq"]
    )
    shots = "".join(
        f'<img src="/img/{code}/screen-{i}.jpg" width="360" height="720" alt="{esc(t["shots_alt"])}" loading="lazy">'
        for i in (1, 2, 3)
    )
    ld = [
        {
            "@context": "https://schema.org",
            "@type": "MobileApplication",
            "name": "TunisGO",
            "operatingSystem": "Android",
            "applicationCategory": "TravelApplication",
            "description": t["description"],
            "inLanguage": code,
            "url": url,
            "installUrl": PLAY,
            "image": f"{BASE}/img/icon-192.png",
            "offers": {"@type": "Offer", "price": "0", "priceCurrency": "TND"},
        },
        {
            "@context": "https://schema.org",
            "@type": "FAQPage",
            "mainEntity": [
                {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
                for q, a in t["faq"]
            ],
        },
    ]
    return f"""<!doctype html>
<html lang="{code}" dir="{t['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(t['title'])}</title>
<meta name="description" content="{esc(t['description'])}">
<link rel="canonical" href="{url}">
{alternates}
<link rel="icon" href="/img/icon-192.png">
<meta name="google-play-app" content="app-id=com.tunisgo">
<meta name="google-site-verification" content="LlYS0HDvg_0xFt3syUgaHUahpLX2YQTxFq1Ctx7EY0c">
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(t['title'])}">
<meta property="og:description" content="{esc(t['description'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{BASE}/img/feature.jpg">
<meta name="twitter:card" content="summary_large_image">
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
<header><a class="brand" href="{t['path']}"><img src="/img/icon-192.png" width="40" height="40" alt="">TunisGO</a><nav>{nav}</nav></header>
<main>
<section class="hero">
<div><h1>{esc(t['h1'])}</h1><p class="lead">{esc(t['lead'])}</p><div class="get"><a class="play" href="{play}"><img src="/img/badge-{code}.png" alt="{esc(t['cta'])}" height="64"></a><div class="qr">{qr_svg(url)}<span>{esc(t['qr_caption'])}</span></div></div></div>
<div class="shots">{shots}</div>
</section>
<h2>{esc(t['features_h'])}</h2>
<div class="grid">{features}</div>
<h2>{esc(rm['h'])}</h2>
<p class="lead">{esc(rm['lead'])}</p>
<ul class="road">{road}</ul>
<p class="idea"><a href="{esc(idea)}">{esc(rm['idea'])} →</a></p>
<h2>{esc(t['routes_h'])}</h2>
<ul class="routes">{routes}</ul>
<p>{esc(t['routes_note'])}</p>
<h2>{esc(t['faq_h'])}</h2>
{faq}
</main>
<footer><div class="contact"><strong>{CONTACT_LABEL[code]}</strong> <a href="mailto:{EMAIL}">{EMAIL}</a></div>{esc(t['disclaimer'])}<br><br><a href="/privacy/">Privacy Policy</a> · <a href="/terms/">Terms of Service</a></footer>
</div>
</body>
</html>
"""


# ---------------------------------------------------------------- route pages

ROUTES, SEASON = R.build_routes()

POPULAR = [
    ("tunis", "sousse"), ("tunis", "sfax"), ("tunis", "monastir"), ("sousse", "monastir"),
    ("sousse", "mahdia"), ("tunis", "gabes"), ("tunis", "bizerte"), ("tunis", "nabeul"),
    ("tunis", "hammamet"), ("tunis", "hammam-lif"), ("tunis", "borj-cedria"), ("tunis", "jendouba"),
    ("tunis", "gafsa"), ("tunis", "tozeur"), ("sousse", "tunis"), ("monastir", "sousse"),
]

RT = {
    "en": {
        "title": "{a} to {b} train times — SNCFT timetable | TunisGO",
        "desc": "{a} → {b} train schedule (SNCFT): {n} direct trains, first at {first}, last at {last}, journey from {dur}. Live delays in the free TunisGO app.",
        "h1": "Train {a} → {b}",
        "lead": "Timetable of direct SNCFT trains from {a} to {b}.",
        "f_n": "Direct trains", "f_first": "First", "f_last": "Last", "f_dur": "Fastest",
        "th": ["Departure", "Arrival", "Duration", "Train", "Days"],
        "valid": "Timetable valid {from_} – {to}. Ramadan timetable not included. Times can change: check live delays in the app or with SNCFT.",
        "promo": "See live delays and get a reminder before your train leaves.",
        "back": "Return trains: {b} → {a}", "more": "Other trains from {a}",
        "home": "Home", "all_routes": "All routes", "index_title": "Train timetables in Tunisia — all SNCFT routes | TunisGO",
        "index_desc": "SNCFT train timetables between Tunisian cities: Tunis, Sousse, Sfax, Monastir, Mahdia, Gabès, Bizerte, Nabeul and more.",
        "index_h1": "Train timetables by route", "from": "From {a}",
        "h": "h", "min": "min",
    },
    "fr": {
        "title": "Horaires train {a} – {b} (SNCFT) | TunisGO",
        "desc": "Horaires des trains {a} → {b} (SNCFT) : {n} trains directs, premier départ {first}, dernier {last}, trajet à partir de {dur}. Retards en direct dans l'application gratuite TunisGO.",
        "h1": "Train {a} → {b}",
        "lead": "Horaires des trains SNCFT directs de {a} à {b}.",
        "f_n": "Trains directs", "f_first": "Premier", "f_last": "Dernier", "f_dur": "Le plus rapide",
        "th": ["Départ", "Arrivée", "Durée", "Train", "Jours"],
        "valid": "Horaires valables du {from_} au {to}. Horaires du Ramadan non inclus. Les horaires peuvent changer : vérifiez les retards en direct dans l'application ou auprès de la SNCFT.",
        "promo": "Suivez les retards en direct et recevez un rappel avant le départ de votre train.",
        "back": "Trains retour : {b} → {a}", "more": "Autres trains au départ de {a}",
        "home": "Accueil", "all_routes": "Tous les trajets", "index_title": "Horaires des trains en Tunisie — tous les trajets SNCFT | TunisGO",
        "index_desc": "Horaires des trains SNCFT entre les villes de Tunisie : Tunis, Sousse, Sfax, Monastir, Mahdia, Gabès, Bizerte, Nabeul et plus.",
        "index_h1": "Horaires des trains par trajet", "from": "Au départ de {a}",
        "h": "h", "min": "min",
    },
    "ar": {
        "title": "مواعيد قطار {a} – {b} (SNCFT) | TunisGO",
        "desc": "مواعيد القطار من {a} إلى {b} (SNCFT): {n} قطارات مباشرة، أول قطار {first}، آخر قطار {last}، مدة الرحلة من {dur}. التأخير مباشرة في تطبيق TunisGO المجاني.",
        "h1": "قطار {a} ← {b}",
        "lead": "مواعيد قطارات SNCFT المباشرة من {a} إلى {b}.",
        "f_n": "قطارات مباشرة", "f_first": "أول قطار", "f_last": "آخر قطار", "f_dur": "الأسرع",
        "th": ["الانطلاق", "الوصول", "المدة", "القطار", "الأيام"],
        "valid": "المواعيد صالحة من {from_} إلى {to}. مواعيد رمضان غير مشمولة. قد تتغير المواعيد: تابع التأخير مباشرة في التطبيق أو لدى SNCFT.",
        "promo": "تابع التأخير مباشرة واحصل على تذكير قبل انطلاق قطارك.",
        "back": "قطارات العودة: {b} ← {a}", "more": "قطارات أخرى من {a}",
        "home": "الرئيسية", "all_routes": "كل الرحلات", "index_title": "مواعيد القطارات في تونس — كل رحلات SNCFT | TunisGO",
        "index_desc": "مواعيد قطارات SNCFT بين المدن التونسية: تونس، سوسة، صفاقس، المنستير، المهدية، قابس، بنزرت، نابل وغيرها.",
        "index_h1": "مواعيد القطارات حسب الرحلة", "from": "من {a}",
        "h": "س", "min": "د",
    },
    "ru": {
        "title": "Расписание поездов {a} — {b} (SNCFT) | TunisGO",
        "desc": "Расписание поездов {a} → {b} (SNCFT): прямых поездов — {n}, первый в {first}, последний в {last}, в пути от {dur}. Задержки онлайн в бесплатном приложении TunisGO.",
        "h1": "Поезд {a} → {b}",
        "lead": "Расписание прямых поездов SNCFT из {a_from} в {b_to}.",
        "f_n": "Прямых поездов", "f_first": "Первый", "f_last": "Последний", "f_dur": "Быстрее всего",
        "th": ["Отправление", "Прибытие", "В пути", "Поезд", "Дни"],
        "valid": "Расписание действует с {from_} по {to}. Рамаданское расписание не включено. Время может меняться: смотрите задержки онлайн в приложении или уточняйте в SNCFT.",
        "promo": "Смотрите задержки онлайн и получайте напоминание перед отправлением поезда.",
        "back": "Обратно: {b} → {a}", "more": "Другие поезда из {a_from}",
        "home": "Главная", "all_routes": "Все направления", "index_title": "Расписание поездов в Тунисе — все направления SNCFT | TunisGO",
        "index_desc": "Расписание поездов SNCFT между городами Туниса: Тунис, Сусс, Сфакс, Монастир, Махдия, Габес, Бизерта, Набёль и другие.",
        "index_h1": "Расписание поездов по направлениям", "from": "Из {a_from}",
        "h": "ч", "min": "мин",
    },
}
ARROW = {"ar": "←"}


def lang_prefix(code):
    return "" if code == "en" else f"/{code}"


def route_path(code, a, b):
    return f"{lang_prefix(code)}/train/{a}-{b}/"


def fmt_dur(m, code):
    t = RT[code]
    h, mm = divmod(m, 60)
    return f"{h} {t['h']} {mm:02d}" if code == "fr" else (f"{h} {t['h']} {mm} {t['min']}" if h else f"{mm} {t['min']}")


def season_dates(code):
    import re as _re
    m = _re.search(r"(\d\d)/(\d\d)/(\d{4})-(\d\d)/(\d\d)/(\d{4})", SEASON)
    if not m:
        return "", ""
    d1, m1, y1, d2, m2, y2 = m.groups()
    return f"{d1}.{m1}.{y1}", f"{d2}.{m2}.{y2}"


def shell(code, title, desc, paths, body, ld=None):
    """Full page: head, header with language links to the same page, body, footer."""
    t = LANGS[code]
    url = BASE + paths[code]
    alternates = "\n".join(f'<link rel="alternate" hreflang="{c}" href="{BASE}{p}">' for c, p in paths.items())
    alternates += f'\n<link rel="alternate" hreflang="x-default" href="{BASE}{paths["en"]}">'
    current = ' aria-current="page"'
    nav = "".join(
        f'<a href="{paths[c]}" hreflang="{c}" lang="{c}"{current if c == code else ""}>{LANG_NAMES[c]}</a>'
        for c in LANGS
    )
    ld_tag = f'<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>' if ld else ""
    return f"""<!doctype html>
<html lang="{code}" dir="{t['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{url}">
{alternates}
<link rel="icon" href="/img/icon-192.png">
<meta property="og:type" content="website">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{BASE}/img/feature.jpg">
{ld_tag}
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
<header><a class="brand" href="{t['path']}"><img src="/img/icon-192.png" width="40" height="40" alt="">TunisGO</a><nav>{nav}</nav></header>
<main>
{body}
</main>
<footer>{esc(t['disclaimer'])}<br><br><a href="mailto:{EMAIL}">{EMAIL}</a> · <a href="/privacy/">Privacy Policy</a> · <a href="/terms/">Terms of Service</a></footer>
</div>
</body>
</html>
"""


def promo(code):
    t = LANGS[code]
    return (f'<div class="promo"><p>{esc(RT[code]["promo"])}</p>'
            f'<a class="play" href="{PLAY}&hl={t["play_hl"]}"><img src="/img/badge-{code}.png" alt="{esc(t["cta"])}" height="56"></a></div>')


def ru_case(slug, case):
    """Russian names after из (genitive) / в (accusative) — only where they change."""
    gen = {"tunis": "Туниса", "sousse": "Сусса", "sfax": "Сфакса", "monastir": "Монастира", "gabes": "Габеса",
           "metlaoui": "Метлауи", "tozeur": "Тозера", "bizerte": "Бизерты", "mateur": "Матера", "nabeul": "Набёля",
           "hammamet": "Хаммамета", "grombalia": "Громбалии", "beja": "Беджи", "jendouba": "Джендубы",
           "le-kef": "Эль-Кефа", "hammam-lif": "Хаммам-Лифа", "borj-cedria": "Бордж-Седрии", "mahdia": "Махдии",
           "monastir-airport": "аэропорта Монастир"}
    acc = {"bizerte": "Бизерту", "grombalia": "Громбалию", "beja": "Беджу", "jendouba": "Джендубу",
           "borj-cedria": "Бордж-Седрию", "mahdia": "Махдию", "monastir-airport": "аэропорт Монастир"}
    table = gen if case == "gen" else acc
    return table.get(slug, R.name(slug, "ru"))


def route_page(code, a, b):
    conns = ROUTES[(a, b)]
    t = RT[code]
    an, bn = R.name(a, code), R.name(b, code)
    fill = dict(a=an, b=bn, a_from=ru_case(a, "gen"), b_to=ru_case(b, "acc"), n=len(conns),
                first=conns[0]["dep"], last=conns[-1]["dep"], dur=fmt_dur(min(c["dur"] for c in conns), code))
    from_, to = season_dates(code)
    rows = "".join(
        f'<tr><td class="t">{c["dep"]}</td><td class="t">{c["arr"]}</td><td>{fmt_dur(c["dur"], code)}</td>'
        f'<td><bdi dir="ltr">{esc(c["train"])}</bdi></td><td>{esc(R.days_label(c["mask"], code))}</td></tr>'
        for c in conns
    )
    others = [(x, y) for (x, y) in ROUTES if x == a and y != b]
    others.sort(key=lambda r: -len(ROUTES[r]))
    links = "".join(f'<li><a href="{route_path(code, x, y)}">{esc(R.name(x, code))} – {esc(R.name(y, code))}</a></li>' for x, y in others[:12])
    back = f'<p><a href="{route_path(code, b, a)}">{esc(t["back"].format(**fill))}</a></p>' if (b, a) in ROUTES else ""
    body = f"""<p class="crumbs"><a href="{LANGS[code]['path']}">{esc(t['home'])}</a> › <a href="{lang_prefix(code)}/train/">{esc(t['all_routes'])}</a></p>
<h1>{esc(t['h1'].format(**fill))}</h1>
<p class="lead">{esc(t['lead'].format(**fill))}</p>
<ul class="facts"><li>{esc(t['f_n'])}<b>{fill['n']}</b></li><li>{esc(t['f_first'])}<b>{fill['first']}</b></li><li>{esc(t['f_last'])}<b>{fill['last']}</b></li><li>{esc(t['f_dur'])}<b>{fill['dur']}</b></li></ul>
<div style="overflow-x:auto"><table class="tt"><thead><tr>{''.join(f'<th>{esc(h)}</th>' for h in t['th'])}</tr></thead><tbody>{rows}</tbody></table></div>
<p class="note">{esc(t['valid'].format(from_=from_, to=to))}</p>
{promo(code)}
{back}
<h2>{esc(t['more'].format(**fill))}</h2>
<ul class="routes">{links}</ul>"""
    paths = {c: route_path(c, a, b) for c in LANGS}
    ld = {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
        {"@type": "ListItem", "position": 1, "name": t["home"], "item": BASE + LANGS[code]["path"]},
        {"@type": "ListItem", "position": 2, "name": t["all_routes"], "item": f"{BASE}{lang_prefix(code)}/train/"},
        {"@type": "ListItem", "position": 3, "name": f"{an} – {bn}", "item": BASE + paths[code]},
    ]}
    return shell(code, t["title"].format(**fill), t["desc"].format(**fill), paths, body, ld)


def index_page(code):
    t = RT[code]
    groups = []
    for slug, *_ in R.CITIES:
        dests = sorted((y for (x, y) in ROUTES if x == slug), key=lambda y: -len(ROUTES[(slug, y)]))
        if not dests:
            continue
        links = "".join(f'<a href="{route_path(code, slug, y)}">{esc(R.name(y, code))}</a>' for y in dests)
        title = t["from"].format(a=R.name(slug, code), a_from=ru_case(slug, "gen"))
        groups.append(f"<li><h3>{esc(title)}</h3>{links}</li>")
    body = (f'<p class="crumbs"><a href="{LANGS[code]["path"]}">{esc(t["home"])}</a></p>'
            f'<h1>{esc(t["index_h1"])}</h1>{promo(code)}<ul class="cities">{"".join(groups)}</ul>')
    paths = {c: f"{lang_prefix(c)}/train/" for c in LANGS}
    return shell(code, t["index_title"], t["index_desc"], paths, body)


def main():
    for code, t in LANGS.items():
        out = PUBLIC / t["path"].strip("/") / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page(code, t), encoding="utf-8")
    # Legal pages: the sources live at the repository root.
    root = pathlib.Path(__file__).resolve().parents[2]
    for src, slug in (("terms-of-service.html", "terms"), ("privacy-policy.html", "privacy")):
        out = PUBLIC / slug / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text((root / src).read_text(encoding="utf-8"), encoding="utf-8")
    (PUBLIC / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\nSitemap: {BASE}/sitemap.xml\n",
        encoding="utf-8",
    )
    groups = [{c: v["path"] for c, v in LANGS.items()}, {c: f"{lang_prefix(c)}/train/" for c in LANGS}]
    groups += [{c: route_path(c, a, b) for c in LANGS} for (a, b) in ROUTES]
    for code in LANGS:
        pages = [(f"{lang_prefix(code)}/train/", index_page(code))]
        pages += [(route_path(code, a, b), route_page(code, a, b)) for (a, b) in ROUTES]
        for path, content in pages:
            out = PUBLIC / path.strip("/") / "index.html"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(content, encoding="utf-8")
    urls = "".join(
        f"<url><loc>{BASE}{g[c]}</loc>"
        + "".join(f'<xhtml:link rel="alternate" hreflang="{x}" href="{BASE}{g[x]}"/>' for x in LANGS)
        + "</url>"
        for g in groups for c in LANGS
    )
    (PUBLIC / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'
        f"{urls}</urlset>\n",
        encoding="utf-8",
    )
    print("Wrote", ", ".join(t["path"] for t in LANGS.values()), f"+ {len(ROUTES)} routes x {len(LANGS)} languages, robots.txt, sitemap.xml")


if __name__ == "__main__":
    main()
