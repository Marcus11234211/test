# Trennianalüüsi selgitus

**Andmeallikas:** Loogiliselt välja mõeldud testandmed Sportbase ERD põhjal (september 2025, 4 nädalat).

## Mida graafik näitab?

Tulpdiagramm kuvab kolme spordiala — Võrkpall, Korvpall ja Jõusaal — osalejate arvu nelja nädala jooksul. Joondiagramm näitab keskmist hõivatuse protsenti kõigi alade peale kokku nädalate kaupa.

## Mustrid andmetes

**Hea muster** on see, kui hõivatus püsib üle 80% — trenn on peaaegu täis, mis tähendab, et teenust kasutatakse hästi ja ressurss (ruum, treeneri aeg) ei lähe raisku. Korvpall näitab head kasvutrendi: 53% → 73% → 87% → **100%** neljandal nädalal — see on selge positiivne trend.

**Halb muster** on langus mitme nädala jooksul järjest. Võrkpall langeb: 80% → 93% → 67% → **60%** — neli nädalat järjest allapoole. Ühekordne langus võib olla juhuslik (haigus, ilm, üritus koolis), aga **kolm-neli järjestikust langust** näitab süsteemset probleemi.

## Matemaatika — mis eristab päris langust juhusest?

Kasulik meetod on **liikuv keskmine** (moving average): kui iga nädala väärtus on madalam kui eelmise nädala liikuv keskmine, on tegemist tõenäoliselt päris trendiga, mitte mürana. Võrkpalli puhul on iga nädal madalam eelmisest — see pole juhuslik kõikumine.

Teine lihtsam kontroll: kui **hõivatus langeb rohkem kui 15–20 protsendipunkti** kahe järjestikuse nädala vahel, tasub uurida põhjust. Võrkpall kukkus nädalate 2 ja 3 vahel 93%-lt 67%-le — see on 26pp langus, mis vajab tähelepanu.

Kui hõivatus langeb **alla 50%** kolmel järjestikusel nädalal, tuleks kaaluda treeninguaja muutmist või reklaami.
