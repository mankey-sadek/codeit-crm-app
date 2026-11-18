#!/usr/bin/env bash
# code it mobile app API: adds /api/mobile/v1 to the CRM (package CodeIt\Mobile). The web CRM is not changed.
# The app logs in with the CRM's own users and sees exactly what the web shows them (same roles and permissions).
# Run as root on serv1 (from the folder this script is in):   bash /root/mobile-api/apply-mobile-api.sh
# Undo:                                                        bash /root/mobile-api/rollback-mobile-api.sh
# Safe to run again: each step checks first and only adds what is missing.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CRM=${CRM:-/var/www/crm}
B=${B:-https://crm.coditvision.com}
PKG=packages/CodeIt/Mobile
MIG=$PKG/src/Database/Migrations/2026_11_18_000901_create_codeit_mobile_devices.php
BK=/var/backups/crm/before-mobile-api-$(date +%F-%H%M%S)

echo "== guards (nothing is changed if one fails)"
[ -d "$HERE/$PKG/src" ] || { echo "package not found next to this script ($HERE/$PKG), stopping"; exit 1; }
[ -f "$CRM/artisan" ] && [ -f "$CRM/composer.json" ] && [ -f "$CRM/bootstrap/providers.php" ] || { echo "no Krayin at $CRM, stopping"; exit 1; }
grep -q 'BrandServiceProvider::class,' "$CRM/bootstrap/providers.php" || { echo "providers.php has no BrandServiceProvider line, stopping"; exit 1; }
grep -q '"CodeIt\\\\Brand\\\\": "packages/CodeIt/Brand/src"' "$CRM/composer.json" || { echo "composer.json has no CodeIt\\Brand line, stopping"; exit 1; }
[ -d "$CRM/vendor/laravel/sanctum" ] || { echo "laravel/sanctum is not installed in the CRM, stopping"; exit 1; }
COMPOSER=$(command -v composer || true); [ -n "$COMPOSER" ] || { echo "composer not found, stopping"; exit 1; }
command -v python3 >/dev/null || { echo "python3 missing, stopping"; exit 1; }
RUNAS=${RUNAS:-$(ps -o user= -C php-fpm 2>/dev/null | grep -v root | sort -u | head -1 || true)}; RUNAS=${RUNAS:-nginx}
id "$RUNAS" >/dev/null 2>&1 || { echo "php-fpm user '$RUNAS' not found, stopping"; exit 1; }
for f in $(cd "$HERE/$PKG" && find . -name '*.php'); do php -l "$HERE/$PKG/$f" >/dev/null || { echo "syntax error in $f, stopping"; exit 1; }; done
for m in Team Support Project Billing Hr Chat Careers; do [ -d "$CRM/packages/CodeIt/$m" ] || echo "   note: CodeIt/$m is not installed, its screens will be empty in the app"; done
echo "   CRM $CRM · php-fpm user $RUNAS · composer $COMPOSER"

echo "== backup -> $BK"
mkdir -p "$BK"
cp -p "$CRM/composer.json" "$CRM/bootstrap/providers.php" "$BK/"
[ -d "$CRM/$PKG" ] && tar czf "$BK/mobile-package.tgz" -C "$CRM" "$PKG"
echo "$BK" > /root/mobile-api-last-backup

echo "== code: $PKG"
OWNER=$(stat -c %U:%G "$CRM/packages/CodeIt/Brand/src/Providers/BrandServiceProvider.php")
DEST="${CRM:?}/${PKG:?}"
rm -rf -- "$DEST.new"
mkdir -p "$DEST.new" && cp -r "$HERE/$PKG/." "$DEST.new/"
rm -rf -- "$DEST"
mv "$DEST.new" "$DEST"
chown -R "$OWNER" "$DEST"; find "$DEST" -type d -exec chmod 755 {} +; find "$DEST" -type f -exec chmod 644 {} +
restorecon -R "$DEST" >/dev/null 2>&1 || true

echo "== register the package (only lines that are missing)"
python3 - "$CRM/composer.json" "$CRM/bootstrap/providers.php" <<'PY'
import json, re, sys
cj, pv = sys.argv[1], sys.argv[2]
s = open(cj, encoding="utf-8").read()
if '"CodeIt\\\\Mobile\\\\"' in s:
    print("   composer.json: already there")
else:
    m = re.search(r'^([ \t]*)"CodeIt\\\\Brand\\\\": "packages/CodeIt/Brand/src",\s*$', s, re.M)
    if not m:
        sys.exit("composer.json: CodeIt\\Brand line not found")
    s = s[:m.start()] + m.group(1) + '"CodeIt\\\\Mobile\\\\": "packages/CodeIt/Mobile/src",\n' + s[m.start():]
    json.loads(s)  # still valid JSON or stop
    open(cj, "w", encoding="utf-8").write(s)
    print("   composer.json: added CodeIt\\Mobile")
p = open(pv, encoding="utf-8").read()
if "MobileServiceProvider" in p:
    print("   providers.php: already there")
else:
    m = re.search(r'^([ \t]*)BrandServiceProvider::class,[ \t]*$', p, re.M)
    if not m:
        sys.exit("providers.php: BrandServiceProvider line not found")
    p = p[:m.end()] + "\n" + m.group(1) + "\\CodeIt\\Mobile\\Providers\\MobileServiceProvider::class," + p[m.end():]
    open(pv, "w", encoding="utf-8").write(p)
    print("   providers.php: added MobileServiceProvider")
PY
php -l "$CRM/bootstrap/providers.php" >/dev/null || { echo "providers.php syntax error, run the rollback"; exit 1; }

echo "== autoload"
cd "$CRM"
VOWNER=$(stat -c %U "$CRM/vendor/composer/autoload_psr4.php")
if [ "$VOWNER" = root ]; then
  COMPOSER_ALLOW_SUPERUSER=1 "$COMPOSER" dump-autoload --no-scripts --no-interaction -q
else
  sudo -u "$VOWNER" env HOME=/tmp COMPOSER_HOME=/tmp/composer-$VOWNER "$COMPOSER" dump-autoload --no-scripts --no-interaction -q
fi
grep -q 'CodeIt\\\\Mobile\\\\' vendor/composer/autoload_psr4.php || { echo "autoload does not have CodeIt\\Mobile, run the rollback"; exit 1; }
sudo -u "$RUNAS" php artisan package:discover -q

echo "== database: login tokens table (Laravel Sanctum, if missing) + 1 new table for phones"
envv() { { grep -E "^$1=" "$CRM/.env" || true; } | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"; }
DBH=$(envv DB_HOST); DBP=$(envv DB_PORT)
sql() { MYSQL_PWD="$(envv DB_PASSWORD)" mysql --default-character-set=utf8mb4 -h "${DBH:-127.0.0.1}" -P "${DBP:-3306}" -u "$(envv DB_USERNAME)" -N -B "$(envv DB_DATABASE)" -e "$1"; }
HAS_PAT=$(sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'personal_access_tokens'")
if [ "$HAS_PAT" = 0 ]; then
  sudo -u "$RUNAS" php artisan migrate --path=vendor/laravel/sanctum/database/migrations --force
else
  echo "   personal_access_tokens: already there"
fi
sudo -u "$RUNAS" php artisan migrate --path="$MIG" --force

echo "== clear caches (as $RUNAS)"
sudo -u "$RUNAS" php artisan optimize:clear >/dev/null
sudo -u "$RUNAS" php artisan optimize >/dev/null
systemctl reload php-fpm 2>/dev/null || systemctl reload php83-php-fpm 2>/dev/null || true

echo "== checks"
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
echo "web login page         $(code $B/admin/login)  (want 200, the web CRM is unchanged)"
echo "app: profile, no login $(code -H 'Accept: application/json' $B/api/mobile/v1/me)  (want 401)"
echo "app: wrong password    $(code -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{"email":"nobody@coditvision.com","password":"x"}' $B/api/mobile/v1/auth/login)  (want 422)"
echo "app routes             $(sudo -u "$RUNAS" php artisan route:list --path=api/mobile/v1 2>/dev/null | grep -c 'api/mobile/v1')  (want 117)"
echo "phones table           $(sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'codeit_mobile_devices'")  (want 1)"
if crontab -l -u "$RUNAS" 2>/dev/null | grep -q 'schedule:run' || grep -rqs 'schedule:run' /etc/cron.d /etc/crontab /var/spool/cron; then
  echo "scheduler cron         found (push notifications will run once Firebase is set up)"
else
  echo "scheduler cron         not found (only needed later for push notifications)"
fi
echo "new errors in log:"
grep -h "^\[$(date +%F) .*\.ERROR" storage/logs/laravel*.log 2>/dev/null | awk -v t="$(date -d '-5 min' +%T)" '$2 >= t"]"' | cut -c1-250 | tail -n 5 || true
echo "done. The app talks to $B/api/mobile/v1 (backup: $BK)"
