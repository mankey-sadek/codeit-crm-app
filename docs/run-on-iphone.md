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
flutter build ios --config-only --profile
open ios/Runner.xcworkspace
```
The app lives on the `feature/native-app` branch (`main` has no `app` folder yet), hence `-b feature/native-app`.
The project uses Swift Package Manager, so there is no Podfile and no `pod install`. `flutter build ios --config-only` prepares everything Xcode needs.
Open **Runner.xcworkspace**, not Runner.xcodeproj.

## Signing (once)
In Xcode, click **Runner** at the top of the left list → target **Runner** → **Signing & Capabilities**:
- Tick **Automatically manage signing**.
- Team: pick your team (the free "Personal Team" works).

**▶ Run in Xcode builds the "Profile" configuration**, made for testing on your own iPhone:
- Bundle ID `com.codeit.crm.mahmoud` and no Push Notifications, so the free **Personal Team** can sign it.
- The app works normally, only without notifications. With a Personal Team it stops opening after 7 days: press Run again.
- The App Store / TestFlight build (Release, built on GitHub) keeps `com.coditvision.crm` and push. Nothing to change there.

If you leave the Edit Scheme screen set to Release, put it back: Product → Scheme → Edit Scheme → Run → Build Configuration → **Profile**.

## Run
1. Connect the iPhone with a cable, unlock it, and tap **Trust**.
2. At the top of Xcode, pick your iPhone as the device.
3. Press **▶ Run**.
4. The first time, the iPhone says "Untrusted Developer": Settings → General → VPN & Device Management → your account → **Trust**. Then open the app.

The app talks to the real CRM (crm.coditvision.com). Push notifications don't work in a build from Xcode, only in the TestFlight build.

Faster from Terminal, without opening Xcode: `flutter run --profile` inside `app/` with the iPhone connected.

## After each update
```
cd ~/codeit-crm-app && git checkout -- . && git pull && cd app && flutter pub get && flutter build ios --config-only --profile
```
Then press ▶ Run again in Xcode.
