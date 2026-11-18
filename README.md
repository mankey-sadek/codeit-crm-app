# code it CRM app

Native mobile app (Android + iOS) for the code it CRM (crm.coditvision.com). Arabic, right to left, dark by default
(light and "follow the phone" in Settings), code it brand (mint `#2BFF88`, the `>` command bar, square dots, Western digits).

- `app/`: Flutter app, one codebase for Android and iOS.
- `server/`: the CRM side. Laravel package `CodeIt\Mobile` (the app's API at `/api/mobile/v1`) plus install and rollback scripts.
- `.github/workflows/build.yml`: builds the Android APK and the iOS app on GitHub.

## What is in the app

Every CRM module, with the same permissions as the web (the API calls the CRM's own controllers and ACL):
home (today, approvals, tickets, pipeline), search, bell notifications, team tasks (board, new, edit, status moves, comments, files),
projects (new, edit), support tickets (new, reply, internal note, status/priority/assignee, hours), support packages (renew, pause),
invoices (new, edit, payments), leads pipeline (new lead with an existing or new contact),
contacts and companies (new, call, WhatsApp, email), activities, quotes, products, mail (folders, read, reply, new),
team chat (files and images, plus the admins' read-only chat monitor), my HR file (check in / out, attendance calendar, leave balance, payslips), leaves (request, approve), employees,
attendance (managers can edit a day), payroll, careers applications. Each person only sees the modules their role allows.

## Server: install the API (once)

The web CRM is not changed. Run as root on serv1:

```bash
tar xzf /root/mobile-api.tgz -C /root
bash /root/mobile-api/apply-mobile-api.sh       # backup first, checks at the end
bash /root/mobile-api/rollback-mobile-api.sh    # undo (logs phones out, keeps the web as it was)
```

Build the bundle from this repo: `tar czf mobile-api.tgz --transform 's,^server,mobile-api,' server`.

## Builds (GitHub Actions)

Every push builds:

- **Android**: `codeit-crm-<n>.apk` in the run's artifacts. Without a keystore it is debug-signed: fine to install and test,
  not for the Play Store. For release signing add these repository secrets:
  `ANDROID_KEYSTORE_BASE64` (the .jks file, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
  Keep the same keystore forever: Android only updates an app signed with the same key.
- **iOS**: without signing secrets it only checks that the app builds. With an Apple Developer account, add
  `IOS_P12_BASE64` (Apple Distribution certificate + key as .p12, base64), `IOS_P12_PASSWORD`,
  `IOS_PROFILE_BASE64` (App Store provisioning profile for `com.coditvision.crm`, base64) and `IOS_TEAM_ID`: each push then
  builds a signed `.ipa`. Add `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (App Store Connect API key, the .p8 text) and it
  is uploaded to TestFlight too. Step-by-step guide for Windows: `docs/ios-signing-windows.md`.

## Run locally

```bash
cd app
flutter pub get
flutter run                                   # talks to https://crm.coditvision.com/api/mobile/v1
flutter run --dart-define=API=http://10.0.2.2:8000/api/mobile/v1   # a local CRM from the Android emulator
flutter build web --dart-define=DEMO=true --no-web-resources-cdn         # demo with recorded data, no server needed
```

`assets/demo/api.json` holds the demo answers (made-up data).

## Push notifications

Server: `codeit:mobile-push` runs every minute (Laravel scheduler) and sends new bell notifications and chat messages.
It is on once the Firebase service-account file is at `storage/app/private/codeit-fcm.json`.
App: the Firebase ids come from two repository secrets, `FIREBASE_ANDROID_JSON` (google-services.json) and
`FIREBASE_IOS_PLIST` (GoogleService-Info.plist), pasted as text; `.github/firebase-defines.py` turns them into
`--dart-define`s, so nothing Firebase is committed. Without them the app builds and works, just without push.
iPhones also need Push Notifications on the App ID (then a new provisioning profile) and an APNs key uploaded to Firebase.
Steps: `docs/push-firebase.md`.
