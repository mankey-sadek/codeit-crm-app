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
   brew install cocoapods
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
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
The app lives on the `feature/native-app` branch (`main` has no `app` folder yet), hence `-b feature/native-app`.
Open **Runner.xcworkspace**, not Runner.xcodeproj.

## Signing (once)
In Xcode, click **Runner** at the top of the left list → target **Runner** → **Signing & Capabilities**:
- Tick **Automatically manage signing**.
- Team: pick your team (WH59D9JVTK).
- Bundle Identifier stays `com.coditvision.crm`.

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
cd ~/codeit-crm-app && git pull && cd app && flutter pub get && cd ios && pod install && cd ..
```
Then press ▶ Run again in Xcode.
