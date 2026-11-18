# نسخة الآيفون: التوقيع من ويندوز (من غير ماك)

الهدف: 7 حاجات بتتحط في GitHub كـ Secrets، وبعدها كل بناء بيطلع نسخة آيفون موقّعة وبتترفع على TestFlight لوحدها.
**الملفات دي سرية:** متبعتهاش في الشات ولا تحطها جوه الريبو. احفظها في `D:\codit system\ios-signing\` بس.

## 0) جهّز الفولدر و OpenSSL
افتح CMD:
```
mkdir "D:\codit system\ios-signing"
cd /d "D:\codit system\ios-signing"
set OSSL="C:\Program Files\Git\usr\bin\openssl.exe"
%OSSL% version
```
لو آخر سطر ماطلعش رقم إصدار يبقى Git مش متسطب. سطّب Git for Windows من git-scm.com وارجع جرّب تاني.

## 1) سجّل الـ App ID
developer.apple.com/account ← Certificates, IDs & Profiles ← **Identifiers** ← زرار **+**
← App IDs ← App ← Description: `code it CRM` ← Bundle ID: **Explicit** = `com.coditvision.crm` ← Continue ← Register.

## 2) اعمل مفتاح وطلب شهادة (CSR)
```
%OSSL% genrsa -out codeit-dist.key 2048
%OSSL% req -new -key codeit-dist.key -out codeit-dist.csr -subj "/CN=code it/C=EG"
```

## 3) شهادة التوزيع
Certificates ← **+** ← **Apple Distribution** ← Continue ← ارفع `codeit-dist.csr` ← Continue ← **Download**.
حط الملف اللي نزل (`distribution.cer`) في نفس الفولدر.

## 4) حوّلها لملف p12
```
%OSSL% x509 -inform DER -in distribution.cer -out codeit-dist.pem
%OSSL% pkcs12 -export -inkey codeit-dist.key -in codeit-dist.pem -out codeit-dist.p12 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
```
هيطلب منك باسورد مرتين. اختار باسورد جديد واحفظه في `codeit-secrets.txt`، ده هيبقى **IOS_P12_PASSWORD**.

## 5) الـ Provisioning Profile
Profiles ← **+** ← تحت Distribution اختار **App Store Connect** ← Continue ← App ID: `com.coditvision.crm` ← اختار الشهادة اللي عملتها
← الاسم: `codeit crm appstore` ← Generate ← **Download**. حط الملف (`.mobileprovision`) في الفولدر.

## 6) الـ Team ID
developer.apple.com/account ← **Membership details** ← Team ID (10 حروف وأرقام). ده **IOS_TEAM_ID**.

## 7) اعمل التطبيق على App Store Connect (عشان TestFlight)
appstoreconnect.apple.com ← Apps ← **+** ← New App:
iOS · الاسم `code it CRM` (لو مستخدم قبل كده اكتب `code it CRM Team`) · اللغة Arabic · Bundle ID `com.coditvision.crm` · SKU `codeit-crm` ← Create.

## 8) مفتاح API عشان GitHub يرفع على TestFlight
App Store Connect ← **Users and Access** ← **Integrations** ← App Store Connect API ← Team Keys ← **+**
← الاسم `github` ← Access: **App Manager** ← Generate.
- نزّل ملف `AuthKey_XXXXXXXXXX.p8`. **بينزل مرة واحدة بس**، فاحفظه في الفولدر.
- انسخ **Key ID** (ده **ASC_KEY_ID**) و **Issuer ID** اللي فوق الجدول (ده **ASC_ISSUER_ID**).

## 9) حوّل الملفات لنص (base64)
```
certutil -encodehex -f codeit-dist.p12 p12.txt 0x40000001
certutil -encodehex -f "codeit_crm_appstore.mobileprovision" profile.txt 0x40000001
```
(لو اسم ملف الـ profile مختلف اكتب اسمه زي ما هو في الفولدر.)

## 10) حطهم في GitHub
افتح https://github.com/mankey-sadek/codeit-crm-app/settings/secrets/actions ← **New repository secret** لكل واحد:

| Name | القيمة |
|---|---|
| `IOS_P12_BASE64` | كل محتوى `p12.txt` (افتحه بـ `notepad p12.txt` واعمل Ctrl+A ثم Ctrl+C) |
| `IOS_P12_PASSWORD` | باسورد خطوة 4 |
| `IOS_PROFILE_BASE64` | كل محتوى `profile.txt` |
| `IOS_TEAM_ID` | من خطوة 6 |
| `ASC_KEY_ID` | من خطوة 8 |
| `ASC_ISSUER_ID` | من خطوة 8 |
| `ASC_KEY_P8` | افتح ملف `AuthKey_....p8` بالـ notepad وانسخه كله، بسطور BEGIN و END |

## 11) قولّي "خلصت"
هشغّل البناء، وبعد ما يخلص Apple بتاخد حوالي 15 لـ 30 دقيقة تعالج النسخة. بعدها:
App Store Connect ← التطبيق ← **TestFlight** ← Internal Testing ← ضيف نفسك والفريق (لازم يكونوا متضافين الأول في Users and Access).
كل واحد ينزّل تطبيق **TestFlight** من الـ App Store، وهيلاقي code it CRM جواه.

ملحوظة: الشهادة والـ profile بيخلصوا بعد سنة. لما يخلصوا هنعيد خطوات 3 و 4 و 5 و 9 بس.
