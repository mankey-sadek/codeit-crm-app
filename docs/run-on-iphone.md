# Run the app on your iPhone from Xcode

This needs a Mac. Xcode doesn't run on Windows.

## Once
1. Install **Xcode** from the Mac App Store and open it once, so it finishes installing its parts.
2. In Terminal:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv zsh)"
   brew install --cask flutter
   sudo xcodebuild -runFirstLaunch
   flutter doctor
   ```
   `flutter doctor` should show ✓ next to Flutter and Xcode. The Android line can stay ✗: it isn't needed for the iPhone.
3. Xcode → Settings → **Accounts** → **+** → Apple ID → sign in with the Apple Developer account.
4. On the iPhone: Settings → Privacy & Security → **Developer Mode** → On (it restarts).

## Get the code
```
git clone -b feature/native-app https://github.com/mankey-sadek/codeit-crm-app.git
cd codeit-crm-app/app
flutter pub get
flutter build ios --config-only --release
open ios/Runner.xcworkspace
```
The app lives on the `feature/native-app` branch (`main` has no `app` folder yet), hence `-b feature/native-app`.
The project uses Swift Package Manager, so there is no Podfile and no `pod install`. `flutter build ios --config-only` prepares everything Xcode needs.
Open **Runner.xcworkspace**, not Runner.xcodeproj.

## Signing (once)
In Xcode, click **Runner** at the top of the left list → target **Runner** → **Signing & Capabilities**:
- Tick **Automatically manage signing**.
- Team: pick your team (WH59D9JVTK).
- Bundle Identifier stays `com.coditvision.crm`.

If the Team list only shows **"(Personal Team)"** and Xcode says personal teams don't support Push Notifications:
- Best fix: pick the company's paid team instead. It appears only if Xcode is signed in with the Apple ID that owns the Apple Developer membership, and the membership is active (renew it if it expired). With it, nothing else changes.
- Quick fix with the free Personal Team, for testing only:
  1. In **Signing & Capabilities**, click **All** at the top, then the 🗑 next to **Push Notifications** (keep Background Modes).
  2. Change **Bundle Identifier** to something of your own, for example `com.codeit.crm.mahmoud`.
  3. Run. The app works normally, only without notifications. A Personal Team build stops opening after 7 days; just press Run again.
  Don't commit these two changes (`git checkout -- ios` undoes them before the next `git pull`).

## Run
1. Connect the iPhone with a cable, unlock it, and tap **Trust**.
2. At the top of Xcode, pick your iPhone as the device.
3. Product → Scheme → Edit Scheme → Run → Build Configuration → **Release**. (A Debug build only opens while the Mac is connected.)
4. Press **▶ Run**.
5. The first time, the iPhone says "Untrusted Developer": Settings → General → VPN & Device Management → your account → **Trust**. Then open the app.

The app talks to the real CRM (crm.coditvision.com). Push notifications don't work in a build from Xcode, only in the TestFlight build.

Faster from Terminal, without opening Xcode: `flutter run --release` inside `app/` with the iPhone connected.

## After each update
```
cd ~/codeit-crm-app && git checkout -- app/ios && git pull && cd app && flutter pub get && flutter build ios --config-only --release
```
Then press ▶ Run again in Xcode.
