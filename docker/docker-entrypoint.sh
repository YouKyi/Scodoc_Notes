#!/bin/bash
set -e

# =============================================================================
# Scodoc_Notes - Docker Entrypoint
# Generates config.php and cas_config.php from environment variables
# if they don't already exist (volume-mounted configs take priority).
# =============================================================================

CONFIG_DIR="/var/www/config"

# =============================================================================
# Generate config/config.php from environment variables
# =============================================================================
generate_config_php() {
    cat > "${CONFIG_DIR}/config.php" <<'PHPEOF'
<?php
/************************************************/
/* Config auto-generated from Docker env vars   */
/************************************************/
	class Config {
		public static $config_version = '1.0.0';

/***********************/
/* Options d'affichage */
/***********************/
PHPEOF

    # --- Helper: write a PHP static property from env var ---
    write_string_prop() {
        local prop="$1" env_val="$2"
        echo "		public static \$$prop = '$env_val';" >> "${CONFIG_DIR}/config.php"
    }
    write_bool_prop() {
        local prop="$1" env_val="$2"
        echo "		public static \$$prop = $env_val;" >> "${CONFIG_DIR}/config.php"
    }
    write_num_prop() {
        local prop="$1" env_val="$2"
        echo "		public static \$$prop = $env_val;" >> "${CONFIG_DIR}/config.php"
    }

    # Display options
    write_bool_prop "releve_PDF" "${SCODOC_RELEVE_PDF:-true}"
    write_string_prop "nom_IUT" "${SCODOC_NOM_IUT:-IUT}"
    write_string_prop "message_non_publication_releve" "${SCODOC_MESSAGE_NON_PUBLICATION:-Le responsable de votre formation a décidé de ne pas publier le relevé de notes de ce semestre.}"

    # Modules
    write_bool_prop "acces_enseignants" "${SCODOC_ACCES_ENSEIGNANTS:-false}"
    write_bool_prop "afficher_absences" "${SCODOC_AFFICHER_ABSENCES:-false}"
    write_bool_prop "module_absences" "${SCODOC_MODULE_ABSENCES:-false}"

    # Analytics
    write_bool_prop "analystics_interne" "${SCODOC_ANALYTICS_INTERNE:-false}"

    # CAS return type
    write_string_prop "CAS_return_type" "${SCODOC_CAS_RETURN_TYPE:-nip}"

    # CAS nip key (optional)
    if [ -n "${SCODOC_CAS_NIP_KEY:-}" ]; then
        write_string_prop "CAS_nip_key" "${SCODOC_CAS_NIP_KEY}"
    fi

    # nipModifier & nameFromIdCAS (default pass-through)
    cat >> "${CONFIG_DIR}/config.php" <<'PHPEOF'

		public static function nipModifier($nip){
			return $nip;
		}

		public static function nameFromIdCAS($idCAS){
			return;
		}

PHPEOF

    # Scodoc connection
    write_string_prop "scodoc_url" "${SCODOC_URL:-https://scodoc.example.com/ScoDoc}"
    write_string_prop "scodoc_login" "${SCODOC_LOGIN:-admin}"
    write_string_prop "scodoc_psw" "${SCODOC_PASSWORD:-changeme}"
    write_bool_prop "multi_scodoc" "${SCODOC_MULTI:-false}"

    # ID/Name format
    write_string_prop "idReg" "${SCODOC_ID_REG:-^.+\$}"
    write_string_prop "idPlaceHolder" "${SCODOC_ID_PLACEHOLDER:-Identifiant CAS}"
    write_string_prop "idInfo" "${SCODOC_ID_INFO:-Ajoutez l\\x27identifiant CAS}"
    write_string_prop "namePlaceHolder" "${SCODOC_NAME_PLACEHOLDER:-Nom Prénom}"
    write_string_prop "nameInfo" "${SCODOC_NAME_INFO:-Nom et prénom de l\\x27utilisateur}"

    # JWT
    write_string_prop "JWT_key" "${SCODOC_JWT_KEY:-}"

    # LDAP
    write_string_prop "LDAP_url" "${SCODOC_LDAP_URL:-}"
    write_string_prop "LDAP_user" "${SCODOC_LDAP_USER:-}"
    write_string_prop "LDAP_password" "${SCODOC_LDAP_PASSWORD:-}"
    write_bool_prop  "LDAP_verify_TLS" "${SCODOC_LDAP_VERIFY_TLS:-true}"
    write_bool_prop  "LDAP_protocol_3" "${SCODOC_LDAP_PROTOCOL_3:-false}"
    write_string_prop "LDAP_dn" "${SCODOC_LDAP_DN:-}"
    write_string_prop "LDAP_uid" "${SCODOC_LDAP_UID:-uid}"
    write_string_prop "LDAP_idCAS" "${SCODOC_LDAP_IDCAS:-mail}"
    write_string_prop "LDAP_filtre_ufr" "${SCODOC_LDAP_FILTRE_UFR:-}"
    write_string_prop "LDAP_filtre_statut_etudiant" "${SCODOC_LDAP_FILTRE_ETUDIANT:-edupersonaffiliation=student}"
    write_string_prop "LDAP_filtre_enseignant" "${SCODOC_LDAP_FILTRE_ENSEIGNANT:-}"
    write_string_prop "LDAP_filtre_biatss" "${SCODOC_LDAP_FILTRE_BIATSS:-}"

    # Absences
    write_num_prop "absence_heureDebut" "${SCODOC_ABSENCE_HEURE_DEBUT:-8}"
    write_num_prop "absence_heureFin" "${SCODOC_ABSENCE_HEURE_FIN:-20}"
    write_num_prop "absence_pas" "${SCODOC_ABSENCE_PAS:-0.5}"
    write_num_prop "absence_dureeSeance" "${SCODOC_ABSENCE_DUREE_SEANCE:-2}"

    # Close class
    cat >> "${CONFIG_DIR}/config.php" <<'PHPEOF'
	}
?>
PHPEOF

    echo "==> Generated config.php from environment variables"
}

# =============================================================================
# Generate config/cas_config.php from environment variables
# =============================================================================
generate_cas_config_php() {
    local cas_cert_line
    if [ -n "${CAS_CERT_PATH:-}" ]; then
        cas_cert_line="\$cas_server_ca_cert_path = '${CAS_CERT_PATH}';"
    else
        cas_cert_line="\$cas_server_ca_cert_path = '';"
    fi

    cat > "${CONFIG_DIR}/cas_config.php" <<PHPEOF
<?php
	///////////////////////////////////////
	// CAS Config - auto-generated       //
	///////////////////////////////////////
	\$cas_host = '${CAS_HOST:-cas.example.com}';
	\$cas_context = '${CAS_CONTEXT:-/cas/}';
	\$cas_port = ${CAS_PORT:-443};
	\$path = realpath(\$_SERVER['DOCUMENT_ROOT'] . '/..');

	${cas_cert_line}
?>
PHPEOF

    echo "==> Generated cas_config.php from environment variables"
}

# =============================================================================
# Generate config/analytics.php (empty by default)
# =============================================================================
generate_analytics_php() {
    if [ ! -f "${CONFIG_DIR}/analytics.php" ]; then
        cat > "${CONFIG_DIR}/analytics.php" <<'PHPEOF'
<!-- Analytics placeholder - configure as needed -->
PHPEOF
        echo "==> Generated empty analytics.php"
    fi
}

# =============================================================================
# Main logic
# =============================================================================

echo "==> Scodoc_Notes - Starting container..."

# Generate config files ONLY if they don't already exist (volume-mount takes priority)
if [ ! -f "${CONFIG_DIR}/config.php" ]; then
    echo "==> No config.php found, generating from environment variables..."
    generate_config_php
else
    echo "==> Using existing config.php (volume-mounted)"
fi

if [ ! -f "${CONFIG_DIR}/cas_config.php" ]; then
    echo "==> No cas_config.php found, generating from environment variables..."
    generate_cas_config_php
else
    echo "==> Using existing cas_config.php (volume-mounted)"
fi

generate_analytics_php

# Ensure correct ownership and permissions
chown -R www-data:www-data /var/www/config /var/www/data 2>/dev/null || true
chmod -R 750 /var/www/config 2>/dev/null || true
chmod -R 770 /var/www/data 2>/dev/null || true

echo "==> Configuration complete. Starting Apache..."

# Pass execution to the CMD
exec "$@"
