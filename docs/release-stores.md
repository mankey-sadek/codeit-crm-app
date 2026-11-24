# Publish the app on the App Store and Google Play

The files for the stores are in the project files, in `mobile/native/store/`:
- `app-store/ios-1.png` … `ios-8.png`: iPhone 6.9" screenshots (1320 × 2868).
- `google-play/android-1.png` … `android-8.png`: phone screenshots (1080 × 2160), `play-feature-1024x500.png`, `icon-512.png`.

Links to paste:
- Privacy policy: https://crm.coditvision.com/app/privacy
- Support: https://crm.coditvision.com/app/support
- Website: https://coditvision.com

**Sign-in for the reviewers** (both stores). It opens a demo with made-up data built into the app: reviewers never see the company's CRM.
- Email: `review@coditvision.com`
- Password: `CodeIt-Review-2026`

---

## Part 1: App Store

### 1. Before you start
- Renew the Apple Developer membership (it ends around 24 November).
- The build to submit is the newest in TestFlight.

### 2. App Information
appstoreconnect.apple.com → Apps → code it CRM → **App Information**:
- Name: `code it CRM`
- Subtitle: `إدارة شغل الفريق`
- Category: **Business**, secondary **Productivity**
- Content Rights: "does not contain third-party content"
- Age Rating → Edit → answer **None / No** everywhere → 4+
- Localizations (top right): add **Arabic**, and fill the texts below for both Arabic and English.

### 3. Pricing and Availability
Price: **Free**. Availability: all countries, or Egypt only.

### 4. App Privacy
Privacy Policy URL: the privacy link above. Then **Get Started** → "Yes, we collect data" → tick:
- Contact Info → **Name**, **Email Address**, **Phone Number**
- User Content → **Emails or Text Messages** (team chat), **Photos or Videos**, **Other User Content** (files, notes)
- Identifiers → **User ID**

For each one: used for **App Functionality** only, **linked to the user**, **not used for tracking**.

### 5. The version page (1.0)
- Screenshots: drag `ios-1.png` … `ios-8.png` into **iPhone 6.9" Display**. They are enough for every iPhone size.
- Promotional Text, Description, Keywords: from the texts below.
- Support URL and Marketing URL: the links above.
- Copyright: `2026 code it`
- **Build**: + → pick the newest build. If it asks about encryption, the answer is already in the app (standard HTTPS only).
- **App Review Information**: tick **Sign-in required**, enter the reviewer email and password, and your phone and email.
  Notes:
  > code it CRM is the internal app of the code it team. It connects to our company CRM; accounts are created by the company, so there is no sign-up. The review account above opens a built-in demo with sample data so you can try every screen (tasks, sales, chat, HR, settings) without access to our customers' data.
- Version Release: **Manually release this version**.

Then **Add for Review** → **Submit**. Apple answers in 1 to 3 days.

**If Apple says it's only for one company's employees** (guideline 3.2), answer that you're fine with **Unlisted** distribution and send the form at https://developer.apple.com/contact/request/unlisted-app/ . The app stays on the App Store, but only people with the link can find it.

---

## Part 2: Google Play

### 1. Developer account (once)
https://play.google.com/console/signup, $25 once.
- **Organization** account: needs the company's D-U-N-S number (free, about 1 to 2 weeks to get). The app can go public straight away.
- **Personal** account: Google first asks for a closed test with **at least 12 people for 14 days** before production.

### 2. The release key and the app file (.aab)
1. Make the Android key and add its 4 secrets: section 2 of `release-team.md` (do it once, keep the key backed up).
2. GitHub → Actions → **Build app** → **Run workflow**.
3. When it finishes, open the run → **Artifacts** → download `codeit-crm-android-<number>`. Inside is `app-release.aab`.

### 3. Create the app
Play Console → **Create app**: name `code it CRM`, default language **Arabic**, App, Free, accept the declarations.

### 4. Dashboard → "Set up your app" (each item)
- **Privacy policy**: the privacy link.
- **App access**: "All or some functionality is restricted" → add instructions: the reviewer email and password, with the note: "Internal company app. This account opens a built-in demo with sample data."
- **Ads**: No.
- **Content rating**: category **Utility, Productivity, Communication or other** → No to everything.
- **Target audience**: **18 and over**.
- **News app**: No. **Government app**: No. **Financial features**: none. **Health**: none.
- **Data safety**:
  - Collects data: Yes. Encrypted in transit: Yes. Users can ask for deletion: Yes (by email to support@coditvision.com).
  - Personal info → **Name**, **Email address**, **Phone number**
  - Messages → **Other in-app messages**
  - Photos and videos → **Photos**; Files and docs → **Files and docs**
  - Device or other IDs → **Device or other IDs** (the notification token)
  - For each one: collected, not shared, required, purpose **App functionality** and **Account management**.

### 5. Store listing
Grow → Store presence → **Main store listing**:
- App name, short description, full description: from the texts below (Arabic). Add English under **Manage translations**.
- App icon: `icon-512.png`. Feature graphic: `play-feature-1024x500.png`.
- Phone screenshots: `android-1.png` … `android-8.png`.
- Category: **Business**. Email: support@coditvision.com. Website: https://coditvision.com

### 6. Release
- Test and release → **Production** (organization account) or **Closed testing** (personal account, 12 people for 14 days first) → **Create new release**.
- When it asks about **Play App Signing**, keep Google's choice ("Use Google-generated key"). Our key becomes the upload key.
- Upload `app-release.aab`. Release name `1.0.0`. Release notes: "أول إصدار".
- **Review release** → **Start rollout**. Google answers in a few days (the first time can take up to a week).

### Every update after that
Run the workflow again and upload the new `.aab` to a new release. The build number goes up by itself.

---

## Texts for the stores

### Arabic
**Name:** code it CRM
**Subtitle (App Store, 30 max):** إدارة شغل الفريق
**Short description (Google Play, 80 max):** مهام الفريق والعملاء والشات والحضور، كله من موبايلك.
**Promotional text (App Store):** كل شغل فريق code it في جيبك: المهام والتذاكر والفرص والشات والحضور والإجازات.
**Keywords (App Store, 100 max):** crm,مهام,فريق,عملاء,مبيعات,تذاكر,دعم,شات,حضور,إجازات,فواتير,مشاريع,موظفين

**Description:**
تطبيق code it CRM هو التطبيق الرسمي لفريق code it. بيوصلك بنظام إدارة العملاء بتاع الشركة، علشان تتابع شغلك من أي مكان.

• الرئيسية: يومك كله في شاشة واحدة. مهامك، والتذاكر اللي محتاجة رد، والطلبات اللي مستنية قرارك.
• المهام: مهام الفريق أول بأول، مين شغال على إيه، واللي متأخر قبل ما يتأخر.
• المبيعات: الفرص ومراحلها، العملاء والشركات، عروض الأسعار والأنشطة.
• المشاريع والدعم: المشاريع بمراحلها وفريقها، تذاكر الدعم ومواعيد الرد، وباقات الدعم.
• الفواتير: إصدار ومتابعة الفواتير وتسجيل الدفعات.
• شات الفريق: محادثات وجروبات وملفات، مع إشعار لكل رسالة.
• الموظفين: سجّل حضورك وانصرافك، شوف شهرك ورصيد إجازاتك، واطلب إجازة. والمديرين بيوافقوا على الطلبات ويتابعوا الحضور والمرتبات.
• الإعدادات: المستخدمين والصلاحيات ومراحل البيع وإعدادات الدوام.

كل واحد بيشوف اللي دوره في الشركة بيسمح بيه بس، زي الويب بالظبط. الدخول بحساب الشركة.

### English
**Subtitle:** Your team's work, together
**Short description:** Team tasks, customers, chat and attendance, all from your phone.
**Promotional text:** All of code it's work in your pocket: tasks, tickets, deals, team chat, attendance and leave.
**Keywords:** crm,tasks,team,customers,sales,tickets,support,chat,attendance,leave,invoices,projects,hr

**Description:**
code it CRM is the official app of the code it team. It connects to the company's CRM, so you can follow your work from anywhere.

• Home: your whole day on one screen. Your tasks, tickets waiting for a reply, and requests waiting for your decision.
• Tasks: the team's tasks as they move, who is on what, and what is about to be late.
• Sales: deals and their stages, people and companies, quotes and activities.
• Projects and support: projects with their stages and team, support tickets with response times, and support packages.
• Invoices: issue and follow invoices and record payments.
• Team chat: conversations, groups and files, with a notification for every message.
• HR: clock in and out, see your month and leave balance, and request leave. Managers approve requests and follow attendance and payroll.
• Settings: users, roles, sales pipelines and work hours.

Everyone sees only what their role allows, exactly like the web. Sign in with your company account.
