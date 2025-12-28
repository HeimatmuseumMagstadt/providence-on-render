# ---- Base: PHP 8.3 + Apache (Providence 2.0 ist mit PHP 8.2/8.3 kompatibel) ----
# Quelle Kompatibilität: Providence README
# https://github.com/collectiveaccess/providence
FROM php:8.3-apache

# Systempakete & PHP-Extensions, die CollectiveAccess typischerweise braucht:
# (pdo_mysql, gd, intl, mbstring, exif, zip). Siehe Install-Doku.
# https://docs.collectiveaccess.org/providence/user/setup/install/
RUN apt-get update && apt-get install -y \
    mariadb-client \
    libjpeg62-turbo-dev libpng-dev libfreetype6-dev \
    libzip-dev libonig-dev libxml2-dev libicu-dev \
    unzip git curl nano \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install pdo pdo_mysql gd mbstring zip intl exif

# Apache so konfigurieren, dass .htaccess greift (für Rewrites in CA)
RUN a2enmod rewrite \
 && sed -ri 's!/var/www/html!/var/www/html!g' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Composer installieren (für vendor-Abhängigkeiten)
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Code in den Webroot (Render checkt dein Repo aus; wir kopieren ins Image)
# Tipp: Falls du große Medien später via Persistent Disk mountest, liegen sie unter /var/www/html/media/collectiveaccess
COPY . /var/www/html
WORKDIR /var/www/html

# Composer-Abhängigkeiten installieren (ohne Dev)
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader || true

# Medien- und Temp-Ordner anlegen (Permissions laut Praxis-Hinweisen)
# https://imaginingfutures.github.io/if-documentation/content/developers/replicate/3-install.html
RUN mkdir -p \
    /var/www/html/media/collectiveaccess \
    /var/www/html/media/collectiveaccess/images \
    /var/www/html/media/collectiveaccess/tilepics \
    /var/www/html/media/collectiveaccess/workspace \
    /var/www/html/media/collectiveaccess/flv \
    /var/www/html/media/collectiveaccess/quicktime \
    /var/www/html/media/collectiveaccess/windowsmedia \
    /var/www/html/media/collectiveaccess/swf \
    /var/www/html/media/collectiveaccess/mp3 \
 && mkdir -p /var/www/html/app/tmp /var/www/html/app/log \
 && chown -R www-data:www-data /var/www/html

# setup.php bereitstellen (falls im Repo setup.php-dist heißt – Standard im Repo)
# Providence enthält setup.php-dist; wir kopieren es auf setup.php, wenn nicht vorhanden.
RUN if [ -f "/var/www/html/setup.php-dist" ] && [ ! -f "/var/www/html/setup.php" ]; then \
      cp /var/www/html/setup.php-dist /var/www/html/setup.php; \
    fi

# Kleine Laufzeit-Optimierung der PHP-Limits (für Uploads/Indexing; optional)
# Diese Werte entsprechen den Empfehlungen aus der Install-Doku (anpassbar via ENV)
# https://docs.collectiveaccess.org/providence/user/setup/install/
RUN { \
      echo "upload_max_filesize=128M"; \
      echo "post_max_size=128M"; \
      echo "memory_limit=512M"; \
      echo "max_execution_time=300"; \
    } > /usr/local/etc/php/conf.d/ca.ini

# Healthcheck/Entrypoint: Rechte prüfen & Apache starten
COPY docker/entrypoint-providence.sh /usr/local/bin/entrypoint-providence.sh
RUN chmod +x /usr/local/bin/entrypoint-providence.sh

EXPOSE 80
CMD ["/usr/local/bin/entrypoint-providence.sh"]
