# Push notifications (Firebase): setup steps

The app and the server are ready. Push stays off until these steps are done.
Keep every file in `D:\codit system\firebase` and never send any of them in chat.

## 1. Firebase project
https://console.firebase.google.com → Add project → `codeit-crm` → turn off Google Analytics → Create.

## 2. Android app
Android icon → Package name `com.coditvision.crm` → Register → download `google-services.json` → Next until you finish.

## 3. iPhone app
Add app → iOS → Bundle ID `com.coditvision.crm` → download `GoogleService-Info.plist` → Next until you finish.

## 4. Push permission from Apple
Do this before you make the provisioning profile; if the profile already exists, make it again afterwards.

1. https://developer.apple.com/account/resources/identifiers/list → `com.coditvision.crm` → tick **Push Notifications** → Save.
2. https://developer.apple.com/account/resources/authkeys/add
   1. Name it `codeit push` and tick **Apple Push Notifications service (APNs)**.
   2. Register, then Download (you can only download it once). Note the Key ID.
3. Firebase → ⚙️ Project settings → Cloud Messaging → Apple app configuration → APNs Authentication Key → Upload the .p8 file, with the Key ID and the Team ID.

## 5. Server key
1. In Firebase: ⚙️ Project settings → Service accounts → **Generate new private key**.
2. Rename the file to `codeit-fcm.json`.
3. From CMD, inside the `D:\codit system\firebase` folder, using the phone hotspot:

```
scp -i %USERPROFILE%\serv1_client_ed25519 codeit-fcm.json root@217.76.58.98:/root/
```

4. Wait a minute, then:

```
ssh -i %USERPROFILE%\serv1_client_ed25519 root@217.76.58.98 "cd /var/www/crm && U=$(ps -o user= -C php-fpm | grep -v root | sort -u | head -1) && install -D -m 640 -o $U -g $(id -gn $U) /root/codeit-fcm.json storage/app/private/codeit-fcm.json && rm /root/codeit-fcm.json && sudo -u $U php artisan codeit:mobile-push && echo PUSH-OK"
```

You should see `PUSH-OK`. From then on, every minute the server sends new bell notifications and chat messages to phones.

## 6. Two GitHub secrets (for the app)
github.com/mankey-sadek/codeit-crm-app → Settings → Secrets and variables → Actions → New repository secret:

| Name | Value |
|---|---|
| `FIREBASE_ANDROID_JSON` | Open `google-services.json` in Notepad, Ctrl+A, copy, and paste it as is |
| `FIREBASE_IOS_PLIST` | Open `GoogleService-Info.plist` in Notepad, Ctrl+A, copy, and paste it as is |

The next build gives an app with notifications. After installing the new version, sign in again once so the phone registers.
