#!/usr/bin/env bash
set -e

# Sicherstellen, dass kritische Verzeichnisse beschreibbar sind
chown -R www-data:www-data /var/www/html/app/tmp /var/www/html/app/log || true
chown -R www-data:www-data /var/www/html/media || true

# Falls ENV-Variablen gesetzt sind, können wir eine Default-setup.php generieren
# (Der Installer /setup.php führt dich dennoch interaktiv durch die DB-Einrichtung.)
# Erwartete Env Vars: CA_DB_HOST, CA_DB_DATABASE, CA_DB_USER, CA_DB_PASSWORD
if [ -f "/var/www/html/setup.php" ]; then
  sed -i "s/\('database_hostname' =>\).*/\1 getenv('CA_DB_HOST') ?: 'localhost',/;" /var/www/html/setup.php || true
  sed -i "s/\('database_login' =>\).*/\1 getenv('CA_DB_USER') ?: 'root',/;"       /var/www/html/setup.php || true
  sed -i "s/\('database_password' =>\).*/\1 getenv('CA_DB_PASSWORD') ?: '',/;"    /var/www/html/setup.php || true
  sed -i "s/\('database_name' =>\).*/\1 getenv('CA_DB_DATABASE') ?: 'providence',/;" /var/www/html/setup.php || true
fi

# Backblaze S3 Upload per curl (vereinfachter Adapter):
export CA_B2_UPLOAD_URL="${B2_S3_ENDPOINT}/${B2_BUCKET_NAME}"

# Ersetzen der lokalen Medienfolder mit Remote-Ziel
sed -i "s#media/collectiveaccess#${CA_B2_UPLOAD_URL}#g" /var/www/html/app/conf/local/app.conf || true

# Apache starten
apache2-foreground
