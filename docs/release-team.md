# Give the app to the whole team

Two things to do: iPhone through a TestFlight link, and Android through a download link.
Keep every key file in `D:\codit system\` and never send them in chat.

## 0. Renew Apple first
Your Apple Developer membership ends around 24 November. If it lapses, TestFlight stops working for everyone.
https://developer.apple.com/account → Membership → Renew.

## 1. iPhone: a TestFlight link (once)
1. https://appstoreconnect.apple.com → Apps → **code it CRM** → **TestFlight**.
2. On the left, next to **External Testing**, click **+** → name the group `code it team` → Create.
3. In the group: **Builds** → **+** → pick the latest build → Next.
   - Test information: "Internal CRM for the code it team".
   - **Sign-in required**: tick it, and give an account Apple can sign in with (make a user in the CRM, for example `review@coditvision.com`, with the موظف role only).
   - Contact: your name, email and phone. Submit for review.
4. Apple reviews the first build (usually under a day). Later builds of the same version go out without waiting.
5. Once it says **Testing**: in the group, **Public Link** → **Enable Public Link** → copy it.
6. Send the link to the team. Each person installs **TestFlight** from the App Store, opens the link, then taps **Install**.

Every new build: open the group → Builds → + → pick it. Everyone gets an update notice.
TestFlight builds stop working after 90 days, so add a new build at least every 3 months.

## 2. Android: the release key (once)
Without it every build is signed with a throwaway test key, and phones refuse to update the app.

In CMD, inside `D:\codit system\android` (make the folder):

```
set OSSL="C:\Program Files\Git\usr\bin\openssl.exe"
%OSSL% req -x509 -newkey rsa:2048 -nodes -keyout codeit-upload.key -out codeit-upload.crt -days 10000 -subj "/CN=code it/O=code it/C=EG"
%OSSL% pkcs12 -export -inkey codeit-upload.key -in codeit-upload.crt -name codeit -out codeit-upload.p12
certutil -encodehex -f codeit-upload.p12 keystore.txt 0x40000001
notepad keystore.txt
```

When it asks for an Export Password, choose a strong one and write it in `D:\codit system\codeit-secrets.txt`.
**Back up `codeit-upload.p12` and its password.** If they are lost, the Android app can never be updated again; everyone would have to uninstall it.

Then github.com/mankey-sadek/codeit-crm-app → Settings → Secrets and variables → Actions → New repository secret, four times:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | everything in keystore.txt (Ctrl+A, copy) |
| `ANDROID_KEYSTORE_PASSWORD` | the Export Password |
| `ANDROID_KEY_PASSWORD` | the same Export Password |
| `ANDROID_KEY_ALIAS` | `codeit` |

## 3. Android: publish the download
github.com/mankey-sadek/codeit-crm-app → **Actions** → **Build app** → **Run workflow** → branch `feature/native-app` → Run.
When it finishes (about 15 minutes) the link for the team is:

https://github.com/mankey-sadek/codeit-crm-app/releases/latest/download/codeit-crm.apk

Each person opens it on the phone → download → open the file → allow "install unknown apps" for the browser once → Install.
For a new version, run the workflow again: the same link gives the new APK, and installing it updates the app (the data stays).

## 4. For everyone
- Sign in with the same email and password as the web CRM.
- Allow notifications when the app asks.
- Each person only sees what their role allows (same as the web).
