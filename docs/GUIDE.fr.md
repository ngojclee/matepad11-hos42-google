# MatePad 11 (DBY-W09) → HarmonyOS 4.2 C00 + microG — Guide en français

> Procédure testée sur une **Huawei MatePad 11 (2021) DBY-W09S**, Snapdragon 865/870 (`kona`).
> État initial : `2.0.0.278 (C432E2R2P1)`, Android 10, bootloader verrouillé.
> État final : `4.2.0.208 (C00E100)`, Android 12, bootloader **déverrouillé**, microG avec
> usurpation de signature **active**.

Légende : 🖥 = sur le PC, 📱 = sur la tablette.

---

## 0. Ce que fait réellement la procédure

| Étape | Objectif | Outil |
|---|---|---|
| A | Sauvegarde EDL complète | `edl.py` |
| B | Effacer l'identité régionale (`oeminfo`) | `edl.py` |
| C | Installer **HarmonyOS 2 chinois** (rebrand → C00) | Recovery + clé USB |
| D | Réécrire l'**ABL déverrouillé** | `edl.py` |
| E | Flasher **HarmonyOS 4.2 C00** | `fastboot` |
| F | Installer **microG `-hw`** + Aurora Store | `adb` |

L'étape C est **obligatoire** : un appareil C432 refuse de démarrer sur un système CN, et la table
de partitions de 4.2 diffère de celle de HOS 2. C'est le programme officiel de mise à jour (`dload`)
qui repartitionne — d'où l'intérêt de passer par lui plutôt que par un flash manuel.

---

## 1. Prérequis

🖥 Windows 10/11, Python 3.10+, [platform-tools](https://developer.android.com/tools/releases/platform-tools),
[bkerler/edl](https://github.com/bkerler/edl) puis `pip install -r requirements.txt`.

🖥 Clé USB ≥ 8 Go formatée en **NTFS**, avec un dossier `dload\` à la racine.
Il faut aussi un **adaptateur ou hub USB-C OTG** pour que la tablette lise la clé :

![Hub USB-C OTG](images/otg-hub.jpg)

📦 À télécharger et vérifier (tableau des empreintes dans le README) :

```
update_full_base.zip                      base HOS 4.2 CN
update_full_cust_DBY-W09_all_cn.zip       cust HOS 4.2 CN
update_full_preload_DBY-W09_all_cn_R1.zip preload HOS 4.2 CN
update_sd_base.zip                        dload HOS 2 CN (rebrand)
update_sd_cust_DBY-W09_all_cn.zip
update_sd_preload_DBY-W09_all_cn_R5.zip
blank_oeminfo.img                         efface l'identité régionale
abl_hw865870unlock.elf                    ABL déverrouillé
dbyprog_emmc_firehose                     loader EDL
```

Copiez les trois `update_sd_*.zip` **tels quels** (sans les décompresser) dans `dload\`.

📱 Activez **Options pour les développeurs → Débogage USB**, puis acceptez la demande RSA sur le PC.

---

## 2. Étape A — sauvegarde EDL

🖥 Passer en EDL et installer le pilote WinUSB (**une fois par PC**) :

```powershell
adb reboot edl      # écran noir ; Windows voit « QUSB_BULK_CID:… »
# Zadig → Options → List All Devices → QUSB_BULK_CID… → WinUSB → Replace Driver
```

🖥 Ensuite :

```powershell
.\scripts\edl-env.ps1
python $Edl edl.py printgpt --memory=ufs --lun=0 --loader=$Loader   # doit lister 40 partitions
.\scripts\backup.ps1                                                # ~12,9 Go, sans userdata
```

**À vérifier avant de continuer :** ~90 fichiers ; `lun4\abl.bin` fait exactement 4 194 304 octets
et commence par `7F 45 4C 46` (ELF) ; `lun4\boot.bin` commence par `ANDROID!` ; `lun0\oeminfo.bin`
fait 100 663 296 octets. Copiez `oeminfo.bin` et `abl.bin` sur un **second disque**.

> ⚠️ Si `edl.py` meurt en cours de route, la tablette tombe en **Sahara error state**
> (`Mode detected: error`). Seul remède : maintenir **Power 20–30 s**.
> Toujours définir `PYTHONIOENCODING=utf-8` (les scripts le font) : la barre de progression d'edl
> fait planter Python en cp1252.

---

## 3. Étape B — effacer `oeminfo`

Toujours en EDL :

```powershell
.\scripts\blank-oeminfo.ps1     # écrit blank_oeminfo.img sur le LUN 0 puis relit pour vérifier
```

La tablette s'éteint à la fin : c'est normal.

---

## 4. Étape C — installer HarmonyOS 2 chinois (`dload`)

1. Éjectez proprement la clé du PC, branchez-la sur le **hub OTG**, puis le hub sur la tablette.
   (Le branchement peut rallumer la tablette, sans conséquence.)
2. 📱 Maintenez **Power 15 s** pour l'éteindre. Puis **maintenez Vol+ et appuyez sur Power** ;
   relâchez Power au logo Huawei, gardez Vol+ ~5 s → **Recovery**.
3. Dans le Recovery (souvent en chinois) :
   * `升级模式` / **Update mode**
   * `存储卡/OTG升级` / **Memory card/OTG update**
4. La tablette vérifie le paquet, **repartitionne** et écrit. 10 à 20 minutes.
   **Ne débranchez rien, ne l'éteignez pas.**
5. Au message de succès : **factory reset**, puis redémarrage.

Vérification : **Paramètres → À propos → Numéro de build** doit afficher
`DBY-W09 2.0.0.273 (C00E210)` (ou un autre `C00…`). Si c'est encore `C432`, la mise à jour n'a pas eu lieu.

```powershell
adb shell getprop ro.build.display.id     # DBY-W09 2.0.0.273(C00E210)
```

---

## 5. Étape D — restaurer l'ABL déverrouillé

Le `dload` a réécrit un ABL d'origine : le bootloader est **de nouveau verrouillé**
(`verifiedbootstate=green`, `flash.locked=1`).

```powershell
adb reboot edl
.\scripts\unlock-abl.ps1        # écrit abl_hw865870unlock.elf sur le LUN 4 + relecture de contrôle
adb reboot bootloader
fastboot getvar unlocked        # doit afficher : unlocked: yes
fastboot getvar is-userspace    # doit afficher : is-userspace: no
```

---

## 6. Étape E — flasher HarmonyOS 4.2

Le paquet 4.2 CN est composé de trois zips HOTA contenant chacun `UPDATE.APP` + `PTABLE.APP`.
Extrayez les images et laissez le script les valider contre la **table de partitions réelle** :

```powershell
python .\scripts\extract_updateapp.py  update_full_base.zip      -o work\base
python .\scripts\extract_updateapp.py  update_full_cust_*.zip    -o work\cust
python .\scripts\extract_updateapp.py  update_full_preload_*.zip -o work\preload
python .\scripts\sparse.py             work\base\super_part0.img work\base\super_part1.img -o work\super.img
python .\scripts\stage-flash.py        -i work -o stage           # tableau de compatibilité, doit finir par "ALL GOOD"
```

`stage-flash.py` s'arrête si une image dépasse sa partition, et il ne prépare **jamais** `abl`
(pour garder le déverrouillage) ni les fichiers `gpt`.

Puis :

```powershell
adb reboot bootloader
fastboot getvar is-userspace     # "no" — arrêtez si "yes"
.\scripts\flash-hos42.ps1        # 41 partitions, ~9 Go, ~5 min en USB 3
```

Le script s'arrête à la première erreur et **ne redémarre pas** la tablette.

```powershell
fastboot reboot
adb wait-for-device
adb shell getprop ro.build.display.id      # DBY-W09 4.2.0.208(C00E100)
adb shell getprop ro.build.version.release # 12
adb shell getprop ro.boot.flash.locked     # 0 → toujours déverrouillé
```

> ⚠️ Si le système ne démarre pas : **ne redémarrez pas au hasard**. Maintenez Power 20 s,
> retournez en fastboot (`Vol-` en branchant le câble) et relancez `flash-hos42.ps1`,
> ou restaurez la sauvegarde (§9).

---

## 7. Étape F — services Google (microG)

microG réimplémente Play Services. Les builds **`-hw`** sont ceux destinés aux appareils Huawei :
sous HOS 4.2 le système affiche `System spoofs signature: ✓`, ce qui est impossible sous HOS 2.

```powershell
curl.exe -L -o gms-hw.apk     https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.google.android.gms-252432034-hw.apk
curl.exe -L -o vending-hw.apk https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.android.vending-84022634-hw.apk
adb install -r -g gms-hw.apk
adb install -r -g vending-hw.apk

adb shell pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.google.android.gms android.permission.ACCESS_BACKGROUND_LOCATION

curl.exe -L -o aurora.apk https://f-droid.org/repo/com.aurora.store_76.apk
adb install -r -g aurora.apk

adb shell settings put global ota_disable_automatic_update 1
adb shell settings put global auto_update_apps 0
```

📱 Ouvrez **microG Settings → Self-Check** :

![Self-check microG](images/microg-selfcheck.png)

* `System spoofs signature` ✓
* `microG Services installed` ✓ / `has correct signature` ✓
* `microG Companion / Play Store installed` ✓ — sa vérification de signature reste rouge ;
  cela n'affecte que le vrai Play Store, pas Aurora.
* `microG Services Framework` ✗ — normal, microG ne fournit pas GSF.

Ensuite **Google Accounts → Add account** et connectez-vous. Si Google affiche
*« This browser or app may not be secure »*, réessayez ou utilisez un mot de passe d'application.

Enfin ouvrez **Aurora Store** et choisissez *Google* (compte microG) ou *Anonymous* :

![Aurora Store](images/aurora-store.png)

---

## 8. Option — root (APatch)

Utile seulement pour les modifications système (hosts/AdAway, débloat, build.prop).
Sous HOS 4.2 la partition `boot` **contient** un ramdisk, donc APatch fonctionne — contrairement
à HOS 2, où Huawei sépare kernel et ramdisk sur deux partitions.

1. Installez `APatch_*.apk`, poussez un `boot.img` d'origine (ou `bootHMOS4.2.img`).
2. APatch → *Patch image* → récupérez le fichier patché.
3. `adb reboot bootloader` → `fastboot flash boot patched_boot.img` → `fastboot reboot`.
4. Ouvrez APatch et définissez la superkey.

---

## 9. Dépannage

| Symptôme | Cause | Solution |
|---|---|---|
| `Mode detected: error` dans `edl.py` | session précédente interrompue (Sahara error) | maintenir **Power 20–30 s**, revenir en EDL |
| Bloqué sur le logo, **aucun USB** | panic kernel après un flash partiel | Power 20 s → `Vol-` + câble → fastboot → reflasher |
| Boucle de démarrage **avec** fastboot | images incomplètes | vérifier `is-userspace` = no, relancer `flash-hos42.ps1` |
| `dload` : *version check failed* | `oeminfo` contient encore C432 | refaire l'étape B puis C |
| Recovery inaccessible | Vol+ relâché trop tôt | Vol+ d'abord, puis Power, relâcher Power au logo |
| `fastboot flash super` se bloque | port USB 2 / hub | brancher sur un port USB 3, réessayer |
| Self-check : usurpation en rouge | installé sous HOS 2 ou build non `-hw` | HOS 4.2 + APK `-hw` obligatoires |

### Retour arrière complet

```powershell
adb reboot bootloader
.\scripts\restore-backup.ps1 -Backup "D:\edl-backup"   # réécrit toutes les partitions, garde l'ABL
fastboot reboot
```

---

## 10. Ce que l'on gagne, ce que l'on perd

**Fonctionne :** applications du Play Store via Aurora, compte Google, notifications push
(microG Cloud Messaging), localisation, la plupart des applications dépendantes de Google,
stylet et appareil photo (pile vendor intacte), OTA désactivé définitivement.

**Ne fonctionne pas :** Play Integrity / SafetyNet (banques, Netflix HD), le vrai Play Store,
Google Cast nécessitant GMS, les services Huawei internationaux (ROM chinoise).

**Sécurité :** le bootloader reste déverrouillé (`verifiedbootstate=orange`) : toute personne ayant
l'appareil en main peut le flasher. Conservez la sauvegarde EDL hors ligne.
