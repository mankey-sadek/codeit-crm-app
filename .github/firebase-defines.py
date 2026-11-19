"""Turn the Firebase config files (GitHub secrets FIREBASE_ANDROID_JSON / FIREBASE_IOS_PLIST, pasted as
plain text or as base64) into --dart-define values for the app. No secrets = empty file = app without push."""
import base64, json, os, plistlib, re, sys


def raw(name):
    v = os.environ.get(name, "").replace("\r", "").strip()
    if not v:
        return None
    if v[0] in "{<":
        return v.encode()
    v = "\n".join(l for l in v.split("\n") if not l.startswith("-----"))  # certutil -encode header/footer
    return base64.b64decode(re.sub(r"\s", "", v))


out = {}
a = raw("FIREBASE_ANDROID_JSON")
if a:
    j = json.loads(a)
    c = next(c for c in j["client"] if c["client_info"]["android_client_info"]["package_name"] == "com.coditvision.crm")
    out.update(FB_PROJECT=j["project_info"]["project_id"], FB_SENDER=j["project_info"]["project_number"],
               FB_ANDROID_APP=c["client_info"]["mobilesdk_app_id"], FB_ANDROID_KEY=c["api_key"][0]["current_key"])
i = raw("FIREBASE_IOS_PLIST")
if i:
    p = plistlib.loads(i)
    if p.get("BUNDLE_ID") != "com.coditvision.crm":
        sys.exit("GoogleService-Info.plist is for %s, not com.coditvision.crm" % p.get("BUNDLE_ID"))
    out.update(FB_PROJECT=p["PROJECT_ID"], FB_SENDER=p["GCM_SENDER_ID"], FB_IOS_APP=p["GOOGLE_APP_ID"], FB_IOS_KEY=p["API_KEY"])
json.dump(out, open(sys.argv[1], "w"))
print("push:", "on (" + ", ".join(sorted(out)) + ")" if out else "off (no FIREBASE_* secrets)")
