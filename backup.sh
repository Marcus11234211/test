#!/bin/bash

# Sportbase andmebaasi backup-skript
# Fail: /opt/backup.sh
# Cron: 0 2 * * * root /opt/backup.sh >> /var/log/backup.log 2>&1

# --- Seadistus ---
DB_NAME="sportbase"
DB_USER="root"
DB_PASS="SinuParool123!"          # NB: toodangus kasuta ~/.my.cnf faili
BACKUP_DIR="/var/backups/sportbase"
REMOTE_USER="mkrutto"
REMOTE_HOST="10.0.201.150"        # veebiserver (sekundaarne koopia)
REMOTE_DIR="/var/backups/sportbase_remote"
KEEP_DAYS=7                       # säilita 7 päeva backupe

# --- Funktsioonid ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_space() {
    FREE_KB=$(df /var/backups --output=avail | tail -1)
    if [ "$FREE_KB" -lt 512000 ]; then   # alla 500 MB
        log "HOIATUS: Vaba ruumi on alla 500 MB ($((FREE_KB / 1024)) MB). Backup võib ebaõnnestuda."
    fi
}

# --- Peaprotsess ---
log "=== Backup alustatakse ==="

# 1. Loo backup-kaust kui puudub
mkdir -p "$BACKUP_DIR"

# 2. Kontrolli vaba ruumi
check_space

# 3. Failinimi koos kuupäeva ja kellaajaga
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')
FILENAME="sportbase_${TIMESTAMP}.sql.gz"
FILEPATH="${BACKUP_DIR}/${FILENAME}"

# 4. Tee backup ja paki kokku
log "Alustan mysqldump: $DB_NAME -> $FILEPATH"
mysqldump \
    --user="$DB_USER" \
    --password="$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-table \
    "$DB_NAME" | gzip > "$FILEPATH"

# 5. Kontrolli kas backup õnnestus
if [ $? -eq 0 ] && [ -s "$FILEPATH" ]; then
    SIZE=$(du -sh "$FILEPATH" | cut -f1)
    log "Backup õnnestus: $FILEPATH ($SIZE)"
else
    log "VIGA: Backup ebaõnnestus! Faili ei loodud või on tühi."
    exit 1
fi

# 6. Loo sümboolne link "viimane backup"
ln -sf "$FILEPATH" "${BACKUP_DIR}/sportbase_latest.sql.gz"
log "Uuendatud: sportbase_latest.sql.gz -> $FILENAME"

# 7. Kopeeri veebiserveri sekundaarkoopiasse (SSH võtmega)
log "Kopeerin sekundaarvarukoopiana -> ${REMOTE_HOST}:${REMOTE_DIR}/"
scp -q -i /root/.ssh/backup_key "$FILEPATH" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/${FILENAME}"

if [ $? -eq 0 ]; then
    log "Sekundaarkoopia edastatud edukalt."
else
    log "HOIATUS: Sekundaarkoopia edastamine ebaõnnestus. Primaarne backup on olemas."
fi

# 8. Kustuta vanad backupid (vanemad kui KEEP_DAYS päeva)
log "Kustutan backupe, mis vanemad kui ${KEEP_DAYS} päeva..."
DELETED=$(find "$BACKUP_DIR" -name "sportbase_*.sql.gz" \
    ! -name "sportbase_latest.sql.gz" \
    -mtime +${KEEP_DAYS} -print -delete | wc -l)
log "Kustutatud: ${DELETED} vana backup-faili."

# 9. Logi backup-kataloogi seis
log "Backup-kataloogis on praegu:"
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | awk '{print "  " $5 "  " $9}' | \
    while read line; do log "$line"; done

log "=== Backup lõpetatud ==="

# =============================================================
# TAASTAMINE (käsitsi käivitamine):
#
#   # Viimase backup-iga taastamine:
#   gunzip -c /var/backups/sportbase/sportbase_latest.sql.gz \
#       | mysql -u root -p sportbase
#
#   # Kindla kuupäeva backup-iga taastamine:
#   gunzip -c /var/backups/sportbase/sportbase_2025-09-01_02-00.sql.gz \
#       | mysql -u root -p sportbase
#
#   # Taastamine testkeskkonda (originaal puutumata):
#   mysql -u root -p -e "CREATE DATABASE sportbase_test;"
#   gunzip -c /var/backups/sportbase/sportbase_latest.sql.gz \
#       | mysql -u root -p sportbase_test
# =============================================================
