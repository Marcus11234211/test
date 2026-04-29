# Tulemüüri analüüs — Sportbase

**Autor:** Marcus Krutto

---

## 1. Avatud pordid serveritel

### Käsk portide kontrollimiseks

```bash
ss -plunt
```

`ss` = socket statistics | `-p` = protsess | `-l` = kuulav | `-u` = UDP | `-n` = numbrilised pordid | `-t` = TCP

### Veebiserver (10.0.201.150) — oodatav väljund

```
Netid  State   Local Address:Port   Process
tcp    LISTEN  0.0.0.0:22           sshd
tcp    LISTEN  0.0.0.0:80           apache2
tcp    LISTEN  0.0.0.0:443          apache2
```

### Andmebaasiserver (10.0.201.151) — oodatav väljund

```
Netid  State   Local Address:Port   Process
tcp    LISTEN  0.0.0.0:22           sshd
tcp    LISTEN  127.0.0.1:3306       mysqld
```

**Tähtis:** MariaDB kuulab `127.0.0.1:3306`, mitte `0.0.0.0:3306`. See tähendab, et otse väljastpoolt ei pääse andmebaasile ligi — ainult veebiserver saab ühenduda ufw reegliga `from 10.0.201.150`.

---

## 2. Portide analüüs

| Port | Protokoll | Server | Staatus | Hinnang |
|------|-----------|--------|---------|---------|
| 22 | TCP (SSH) | Mõlemad | Avatud | ✅ Vajalik — administreerimiseks |
| 80 | TCP (HTTP) | Veebiserver | Avatud | ✅ Vajalik — suunab HTTPS-i peale |
| 443 | TCP (HTTPS) | Veebiserver | Avatud | ✅ Vajalik — krüpteeritud liiklus |
| 3306 | TCP (MySQL) | Andmebaas | LAN-only | ✅ Õige — ainult sisevõrgust |
| 3306 | TCP (MySQL) | Andmebaas | Internet | ❌ Peab olema suletud |

### Mis peaks olema suletud ja miks?

**Port 3306 avalikult internetist** — kõige olulisem risk. Kui MariaDB oleks avatud `0.0.0.0:3306`, saaksid ründajad üle interneti proovida:
- Brute-force rünnakuid root paroolile
- CVE-põhiseid ekspluaate MariaDB vastu
- Andmete otse lugemist/kustutamist ilma veebiserverita

**Port 22 (SSH)** — on avatud, aga kaitstud Fail2Ban-iga (5 ebaõnnestunud katset → IP blokeeritakse 10 minutiks). Tugevamas seadistuses lubataks SSH ainult konkreetsest IP-st.

---

## 3. Mis on tulemüüri eesmärk?

Tulemüür on **väravavaht**: ta otsustab, milline võrguliiklus tohib serverisse sisse ja välja minna. Ilma tulemüürita on kõik pordid avalikud — iga internetikasutaja saab proovida ühendust iga teenusega.

**Sportbase'i tulemüür (ufw) teeb kolme asja:**
1. **Piirab ligipääsu andmebaasile** — port 3306 on avatud ainult veebiserveri IP-lt, mitte kõigile
2. **Kaitseb SSH-d** koos Fail2Ban-iga automaatse blokeerimisega
3. **Lubab ainult vajaliku** — vaikimisi `deny incoming`, ehk kõik mis pole lubatud, on keelatud

---

## 4. Mis juhtub, kui kõik pordid on avatud?

Kui käivitada `ufw disable` või `iptables -F`:

- **Andmebaas** muutub internetist ligipääsetavaks — ründajad saavad proovida otse MariaDB-sse sisse logida
- **Siseteenused** (nt. administreerimisteenused, debug-liidesed) paljastuvad
- **Suureneb ründepind** — iga avatud port on potentsiaalne sisenemiskoht
- **Botid** skannivad internetti pidevalt portide 22, 3306, 8080 jm järele — avatud server leitakse minutitega

Praktiline näide: Shodan.io indekseerib avalikke MySQL-servereid. 2024. aastal oli seal üle 3 miljoni avaliku MySQL pordi — paljud neist said andmelekke ohvriks.

---

## 5. Staatiline vs dünaamiline IP — miks server vajab staatilist?

| | Staatiline IP | Dünaamiline IP |
|---|---|---|
| **Mis see on?** | IP-aadress ei muutu kunagi | IP-aadress võib muutuda (iga reboot, iga päev) |
| **Kasutatakse** | Serverid, tulemüüri reeglid, DNS | Kodukasutajad, sülearvutid |
| **Hind** | Kallim (internetiteenuse pakkuja küsib lisa) | Odavam / tasuta |

**Miks server vajab staatilist IP-d?**

1. **Tulemüüri reeglid** — meie reegel `ufw allow from 10.0.201.150 to any port 3306` töötab ainult kui veebiserveri IP on alati `10.0.201.150`. Kui IP muutub, ei pääse veebiserver enam andmebaasile ligi.

2. **DNS kirjed** — domeen `sportbase.kool.ee` peab osutama kindlale IP-le. Dünaamilise IP puhul peaks DNS-i pidevalt uuendama.

3. **SSH ligipääs** — administraator teab täpselt, millisele aadressile ühenduda.

4. **Logide analüüs** — kui IP muutub, on raske tuvastada, milline ühendus kust tuli.

**Meie laboris:** VM-id saavad staatilise IP-aadressi hüpervisorilt (NAT-võrk `10.0.201.0/24` on laboris fikseeritud), seega ei pea seda eraldi seadistama — aga toodangukeskkonnas tuleb see internetiteenuse pakkujalt tellida või serverile käsitsi seadistada (`/etc/network/interfaces`).
