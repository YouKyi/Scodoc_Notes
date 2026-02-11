# =============================================================================
# Scodoc_Notes - Docker Image
# Passerelle PHP/Apache entre Scodoc et les étudiants
# =============================================================================

FROM php:8.4-apache AS base

# -- OCI Labels ---------------------------------------------------------------
LABEL org.opencontainers.image.title="Scodoc_Notes" \
    org.opencontainers.image.description="Passerelle web PHP entre Scodoc et les étudiants (notes, absences, documents)" \
    org.opencontainers.image.url="https://github.com/SebL68/Scodoc_Notes" \
    org.opencontainers.image.source="https://github.com/SebL68/Scodoc_Notes" \
    org.opencontainers.image.licenses="GPL-3.0"

# -- System dependencies & PHP extensions (single layer) ----------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libxml2-dev \
    libldap2-dev \
    libonig-dev \
    libssl-dev \
    ; \
    docker-php-ext-install -j"$(nproc)" \
    curl \
    xml \
    ldap \
    mbstring \
    ; \
    # Enable Apache modules
    a2enmod rewrite ssl headers; \
    # Cleanup
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    libcurl4-openssl-dev \
    libxml2-dev \
    libldap2-dev \
    libonig-dev \
    libssl-dev \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -- Apache VirtualHost --------------------------------------------------------
COPY docker/apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# -- Application code ----------------------------------------------------------
COPY --chown=www-data:www-data html/    /var/www/html/
COPY --chown=www-data:www-data includes/ /var/www/includes/
COPY --chown=www-data:www-data lib/     /var/www/lib/

# -- Runtime directories (to be mounted as volumes) ----------------------------
RUN set -eux; \
    mkdir -p /var/www/config /var/www/data/annuaires /var/www/data/absences \
    /var/www/data/studentsPic /var/www/data/standalone_data \
    /var/www/data/analytics /var/www/data/messages; \
    chown -R www-data:www-data /var/www/config /var/www/data; \
    chmod -R 750 /var/www/config; \
    chmod -R 770 /var/www/data

VOLUME ["/var/www/config", "/var/www/data"]

# -- Environment variables (configuration) ------------------------------------
# Scodoc
ENV SCODOC_URL="https://scodoc.example.com/ScoDoc" \
    SCODOC_LOGIN="admin" \
    SCODOC_PASSWORD="changeme" \
    SCODOC_NOM_IUT="IUT" \
    SCODOC_MULTI="false"

# CAS
ENV CAS_HOST="cas.example.com" \
    CAS_CONTEXT="/cas/" \
    CAS_PORT="443" \
    CAS_CERT_PATH=""

# Modules & Display
ENV SCODOC_RELEVE_PDF="true" \
    SCODOC_ACCES_ENSEIGNANTS="false" \
    SCODOC_AFFICHER_ABSENCES="false" \
    SCODOC_MODULE_ABSENCES="false" \
    SCODOC_ANALYTICS_INTERNE="false" \
    SCODOC_CAS_RETURN_TYPE="nip"

# JWT
ENV SCODOC_JWT_KEY=""

# LDAP (optional)
ENV SCODOC_LDAP_URL="" \
    SCODOC_LDAP_USER="" \
    SCODOC_LDAP_PASSWORD="" \
    SCODOC_LDAP_VERIFY_TLS="true" \
    SCODOC_LDAP_PROTOCOL_3="false" \
    SCODOC_LDAP_DN="" \
    SCODOC_LDAP_UID="uid" \
    SCODOC_LDAP_IDCAS="mail" \
    SCODOC_LDAP_FILTRE_UFR="" \
    SCODOC_LDAP_FILTRE_ETUDIANT="edupersonaffiliation=student" \
    SCODOC_LDAP_FILTRE_ENSEIGNANT="" \
    SCODOC_LDAP_FILTRE_BIATSS=""

# Absences
ENV SCODOC_ABSENCE_HEURE_DEBUT="8" \
    SCODOC_ABSENCE_HEURE_FIN="20" \
    SCODOC_ABSENCE_PAS="0.5" \
    SCODOC_ABSENCE_DUREE_SEANCE="2"

# -- Entrypoint ----------------------------------------------------------------
COPY --chmod=755 docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
