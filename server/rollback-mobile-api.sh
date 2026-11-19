#!/usr/bin/env bash
# Undo the mobile app API. The web CRM keeps working as before; phones get logged out.
#   bash /root/mobile-api/rollback-mobile-api.sh              remove the API, keep the phones table (unused)
#   bash /root/mobile-api/rollback-mobile-api.sh --drop-data  also drop the phones table
set -euo pipefail
CRM=${CRM:-/var/www/crm}
B=${B:-https://crm.coditvision.com}
PKG=packages/CodeIt/Mobile
BK=/var/backups/crm/rollback-mobile-api-$(date +%F-%H%M%S)
RUNAS=${RUNAS:-$(ps -o user= -C php-fpm 2>/dev/null | grep -v root | sort -u | head -1 || true)}; RUNAS=${RUNAS:-nginx}
cd "$CRM"
mkdir -p "$BK"; cp -p composer.json bootstrap/providers.php "$BK/"
envv() { { grep -E "^$1=" .env || true; } | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"; }
DBH=$(envv DB_HOST); DBP=$(envv DB_PORT)
sql() { MYSQL_PWD="$(envv DB_PASSWORD)" mysql --default-character-set=utf8mb4 -h "${DBH:-127.0.0.1}" -P "${DBP:-3306}" -u "$(envv DB_USERNAME)" -N -B "$(envv DB_DATABASE)" -e "$1"; }

echo "== log the app out everywhere (only the app's tokens)"
sql "DELETE FROM personal_access_tokens WHERE name = 'codeit-mobile'" 2>/dev/null && echo "   done" || echo "   no tokens table, skipped"

if [ "${1:-}" = "--drop-data" ]; then
  echo "== dropping the phones table (dump first -> $BK/mobile-data.sql)"
  MYSQL_PWD="$(envv DB_PASSWORD)" mysqldump -h "${DBH:-127.0.0.1}" -P "${DBP:-3306}" -u "$(envv DB_USERNAME)" --single-transaction --no-tablespaces \
    "$(envv DB_DATABASE)" codeit_mobile_devices > "$BK/mobile-data.sql" 2>/dev/null || true
  sql "DROP TABLE IF EXISTS codeit_mobile_devices; DELETE FROM migrations WHERE migration = '2026_11_18_000901_create_codeit_mobile_devices'"
  echo "   dropped"
fi

echo "== unregister + remove code (kept in $BK/mobile-package.tgz)"
sed -i '/MobileServiceProvider/d' bootstrap/providers.php
php -l bootstrap/providers.php >/dev/null || { cp -p "$BK/providers.php" bootstrap/; echo "providers.php broke, restored, stopping"; exit 1; }
rm -f bootstrap/cache/config.php bootstrap/cache/services.php bootstrap/cache/routes-v7.php
if [ -d "$PKG" ]; then
  tar czf "$BK/mobile-package.tgz" "$PKG"
  rm -rf -- "${CRM:?}/packages/CodeIt/Mobile"
fi
python3 - composer.json <<'PY'
import json, re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = re.sub(r'^[ \t]*"CodeIt\\\\Mobile\\\\": "packages/CodeIt/Mobile/src",?[ \t]*\n', '', s, flags=re.M)
s = re.sub(r',(\s*\n\s*\})', r'\1', s)
json.loads(s)
open(p, "w", encoding="utf-8").write(s)
PY
VOWNER=$(stat -c %U vendor/composer/autoload_psr4.php)
if [ "$VOWNER" = root ]; then COMPOSER_ALLOW_SUPERUSER=1 composer dump-autoload --no-scripts --no-interaction -q
else sudo -u "$VOWNER" env HOME=/tmp COMPOSER_HOME=/tmp/composer-$VOWNER composer dump-autoload --no-scripts --no-interaction -q; fi
sudo -u "$RUNAS" php artisan package:discover -q
sudo -u "$RUNAS" php artisan optimize:clear >/dev/null
sudo -u "$RUNAS" php artisan optimize >/dev/null
systemctl reload php-fpm 2>/dev/null || systemctl reload php83-php-fpm 2>/dev/null || true
echo "web login page $(curl -s -o /dev/null -w '%{http_code}' $B/admin/login)  (want 200)"
echo "app API        $(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' $B/api/mobile/v1/me)  (want 404 now)"
echo "done (backup: $BK)"
