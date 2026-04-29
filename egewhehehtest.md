# Backup plaan — Sportbase

**Autor:** Marcus Krutto | **Kuupäev:** 2025-09-01

---

## 1. Backup tüüp ja sagedus

| Parameeter | Väärtus |
|---|---|
| Tüüp | Full backup (mysqldump — kogu andmebaas korraga) |
| Sagedus | Iga öö kell 02:00 (cron) |
| Säilitusaeg | 7 päeva (vanemad kustutatakse automaatselt) |
| Hoiustuskoht (primaarne) | `/var/backups/sportbase/` andmebaasiserveril |
| Hoiustuskoht (sekundaarne) | Veebiserver `/var/backups/sportbase_remote/` (scp kaudu) |
| Failinimi formaat | `sportbase_YYYY-MM-DD_HH-MM.sql.gz` |

**Miks full backup?** Andmebaas on väike (alla 100 MB) — täisbackup on lihtsam taastada kui inkrementaalne. Inkrementaalset backup-i tasub kaaluda alles siis, kui andmebaas kasvab üle 1 GB.

---

## 2. RTO ja RPO

| Mõõdik | Väärtus | Selgitus |
|---|---|---|
| **RPO** (Recovery Point Objective) | **24 tundi** | Backup tehakse kord ööpäevas — maksimaalselt võib kaduda ühe päeva andmed |
| **RTO** (Recovery Time Objective) | **30 minutit** | Uue VM-i seadistus + MariaDB paigaldus + backup taastamine mahub poolde tundi |

---

## 3. Riskid ja taastamisplaanid

### Risk 1: Andmebaasiserver kukub täielikult maha (riistvararikke / VM-i kustutamine)

**Taastamisplaan:**
1. Käivita uus VM (`projekt-andmebaas-IT24-mkrutto-uus`)
2. Paigalda MariaDB: `apt install mariadb-server`
3. Kopeeri viimane backup veebiserveri sekundaarkoopiast:
   `scp veeb:/var/backups/sportbase_remote/sportbase_latest.sql.gz .`
4. Taasta: `gunzip -c sportbase_latest.sql.gz | mysql -u root -p sportbase`
5. Uuenda veebiserveri konfiguratsioon uue IP-ga

**Ajakulu:** ~25 minutit

---

### Risk 2: Andmebaas rikutud (valed DELETE/UPDATE laused, tarkvara viga)

**Taastamisplaan:**
1. Tuvasta, mis kuupäeva backup on korrektne:
   `ls -lh /var/backups/sportbase/`
2. Loo uus tühi andmebaas:
   `mysql -u root -p -e "DROP DATABASE sportbase; CREATE DATABASE sportbase;"`
3. Taasta õige backup:
   `gunzip -c sportbase_2025-09-01_02-00.sql.gz | mysql -u root -p sportbase`
4. Kontrolli andmeid: `mysql -u root -p -e "SELECT COUNT(*) FROM sportbase.kasutajad;"`

**Ajakulu:** ~10 minutit

---

### Risk 3: Backup-ketas täis / backup-skript ebaõnnestub

**Taastamisplaan:**
1. Kontrolli vaba ruumi: `df -h /var/backups/`
2. Kustuta käsitsi vanad backupid: `find /var/backups/sportbase/ -mtime +7 -delete`
3. Kontrolli cron-logi: `grep backup /var/log/syslog | tail -20`
4. Käivita backup käsitsi: `bash /opt/backup.sh`
5. Seadista monitooring: `du -sh /var/backups/sportbase/` cron-ülesandena

**Ennetus:** Backup-skript saadab e-kirja kui vaba ruumi jääb alla 500 MB (mailutils).

---

## 4. Taastamise test

Test tehakse kord kuus:

```bash
# 1. Taasta backup testkeskkonda
gunzip -c /var/backups/sportbase/sportbase_latest.sql.gz | \
  mysql -u root -p sportbase_test

# 2. Kontrolli tabelite olemasolu
mysql -u root -p -e "SHOW TABLES FROM sportbase_test;"

# 3. Kontrolli kirjete arvu
mysql -u root -p -e "
  SELECT 'kasutajad' AS tabel, COUNT(*) AS kirjeid FROM sportbase_test.kasutajad
  UNION ALL
  SELECT 'spordiala', COUNT(*) FROM sportbase_test.spordiala
  UNION ALL
  SELECT 'broneeringud', COUNT(*) FROM sportbase_test.broneeringud;"

# 4. Kustuta testkeskkond
mysql -u root -p -e "DROP DATABASE sportbase_test;"
```

Testi tulemus dokumenteeritakse faili `/var/log/backup_test.log`.

---

## 5. Cron seadistus

```
0 2 * * * root /opt/backup.sh >> /var/log/backup.log 2>&1
```

Tõlge: kell **02:00**, **iga päev**, **iga kuu**, **iga nädalapäev** — käivita `/opt/backup.sh`.
