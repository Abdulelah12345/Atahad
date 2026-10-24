# Atahad - Frontend (Flutter)

## First time on your Mac
```
cd frontend
flutter create --project-name atahad --org com.atahad --platforms ios,android .
flutter pub get
open -a Simulator
flutter run
```
- `flutter create .` only adds the missing files (ios/, android/ ...), it does not touch `lib/`.
- The backend must be running on port 8080.
- Backend address: iOS simulator = `localhost`, Android emulator = `10.0.2.2`, a real phone:
  `flutter run --dart-define=API_URL=http://<Mac IP>:8080` (same Wi-Fi).
- Hot reload: press `r` in the terminal.
- The app icon (once, after `flutter pub get`): `dart run flutter_launcher_icons`

## Structure
```
lib/
  main.dart                 the app (Arabic, right to left, light and dark)
  core/                     SHARED - owner: Fai. Ask before changing anything here.
    config.dart             backend address
    api/api_client.dart     the only place that calls the backend (Basic Auth + session cookie)
    auth/auth_state.dart    who is logged in (member / admin), the lock status
    router.dart             the pages and the redirects (login / lock / admin)
    main_shell.dart         the bottom bar: today / groups / my account
    theme/                  colors, fonts, spacing, motion from the design system
    widgets/                AtButton, StatusBadge, WeekTracker, RiyalAmount, AppCard, AsyncView ...
    utils/format.dart       Arabic digits, money, week days, levels
  features/
    account/                Abdulelah  - login, register, profile ("حسابي" tab), deactivate, Google Calendar
    commitments/            Turki      - home (today), habits, goals + AI plan, progress, grace days, points, stats, Wrapped
    proofs/                 Subhiyyah  - proofs (camera, quiz, location), excuses, objections, lock + donation, penalties, admin review
    groups/                 Fai        - groups, join (code/QR), proposals, board, chat, alerts + push, moments, settlement, matches
```

## Login (until the login page is ready)
There is no login page yet. In debug the app logs in by itself with `fai@test.com` / `12345678`
(register it in Postman first). Another account:
`flutter run --dart-define=DEV_EMAIL=sara@test.com --dart-define=DEV_PASSWORD=12345678`
After a logout the saved account is removed, run the app again to log in.

## Rules
1. Everybody works in his own branch and his own folder in `features/`.
2. Your pages go in your own `*_routes.dart` file. Do not edit `core/router.dart`.
3. Need something in `core/` (a new shared widget, a change in the API client)? Tell Fai.
4. Call the backend only with `context.read<ApiClient>()`:
   ```dart
   final api = context.read<ApiClient>();
   final habits = await api.get('/api/v1/habit/getMyHabits') as List;
   await api.post('/api/v1/habit/add', body: {'title': 'Gym', ...});
   ```
   Errors come as `ApiException` with the Arabic message from the server: `showError(context, e)`.
5. Colors only from the theme: `context.colors.primary` (never write a hex in a page).
   Text styles only from `Theme.of(context).textTheme`.
6. Endpoints and bodies: see the Postman collection.

## Design decisions (what we follow when the Figma file is different)
- Gold is for money only. Points and done marks use shadda green.
- Money: `RiyalAmount(70)` = ٧٠٫٠٠ with the riyal symbol. Never "ر.س" or "SAR".
  `assets/icons/riyal.svg` is a placeholder: replace it with the official SAMA symbol (same file name).
- There is NO card payment and NO booking ("التزم واحجز" / "يحجز من بطاقتك" in the design are wrong):
  the member sets an amount for every missed time, and when he misses, he donates by himself to Ehsan
  and proves it (screenshots or the bank email in Gmail). Until then the app shows the lock screen.
- Levels come from the backend: BEGINNER, COMMITTED, PERSEVERING, IRON (names in `levelsAr`).
- The week is Sunday to Saturday, the days in the backend are SUN MON TUE WED THU FRI SAT.
- Proof methods: PHOTO, LOCATION, QUIZ, TIMER (PLATFORM was removed).
- Writing: simple white Saudi Arabic, friendly, no blame. Buttons are verbs. Emojis only in social messages, never in buttons or titles.
- The logo is a picture, never written with a font: `AppLogo()` (assets/images: logo.png, logo_tagline.png, logo_white.png for dark backgrounds). The app icon is assets/images/app_icon.png.
