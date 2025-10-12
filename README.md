<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 👑 rsg-bossmenu
**Boss management menu for RedM servers using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> ox_lib–based menu system allowing **job bosses** to manage employees, funds, and storage. Works seamlessly with RSG Core job data and optional map blips.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(required for job funds)*
- [**rsg-inventory**](https://github.com/Rexshack-RedM/rsg-inventory) 🎒 *(for the boss stash)*

**Interaction:** Each entry in `Config.BossLocations` defines a prompt and optional blip.  
**Locales:** `locales/en.json, fr.json, es.json, it.json, de.json, el.json, pt-br.json` (loaded via `lib.locale()`).

---

## ✨ Features (detailed)

### 🧭 Main Boss Menu *(isboss only)*
- **Manage Employees**
  - View job employees and their grades.
  - **Promote / Demote** employees.
  - **Hire / Fire** nearby players.
- **Storage Access**
  - Open a shared **boss stash** via `rsg-inventory`, customizable capacity.
- **Company Funds**
  - View, deposit, or withdraw company funds from SQL (`management_funds` type = 'boss').
  - All actions are logged and synchronized via oxmysql.
- **Localization and Notifications**
  - Full multilingual support and ox_lib notifications.

### 🗺️ Prompts & Blips
- For every entry in `Config.BossLocations`, the script:
  - Creates a **prompt** using `exports['rsg-core']:createPrompt`.
  - Optionally spawns a **blip** if `showblip = true`.
  - Customizable blip icon and scale.

---

## 📸 Preview
*(add your image here)*

---

## 📜 Example Config

```lua
Config = {}

-- blip settings
Config.Blip = {
    blipName = 'Boss Menu',
    blipSprite = 'blip_honor_good',
    blipScale = 0.2
}

-- settings
Config.Keybind = 'J'
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 50

Config.BossLocations = {
    {   -- example
        id = 'boss1',
        name = 'Boss Menu',
        coords = vector3(0, 0, 0),
        showblip = false
    },
}
```

---

## 📂 Installation
1. Place `rsg-bossmenu` inside your `resources` (or `resources/[rsg]`) folder.
2. Ensure **rsg-core**, **ox_lib**, **rsg-inventory**, and **oxmysql** are installed and started.
3. **Database:** import `rsg-bossmenu.sql` (creates `management_funds` with `type='boss'`).
4. Edit `config.lua` to adjust blips, locations, and stash limits.
5. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-bossmenu
   ```

---

## 🔐 Permissions
- Accessible only for **players with `PlayerData.job.isboss = true`**.
- Grade & access checks are handled server-side for security.
- All financial actions and member updates require boss rank.

---

## 🗄️ SQL
`rsg-bossmenu.sql` creates and seeds the `management_funds` table with default jobs:

```sql
CREATE TABLE IF NOT EXISTS `management_funds` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `amount`  INT(100) NOT NULL,
  `type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_name` (`job_name`),
  KEY `type` (`type`)
);

INSERT INTO `management_funds` (`job_name`, `amount`, `type`) VALUES
('vallaw', 0, 'boss'),
('rholaw', 0, 'boss'),
('blklaw', 0, 'boss'),
('strlaw', 0, 'boss'),
('stdenlaw', 0, 'boss'),
('medic', 0, 'boss'),
('valsaloontender', 0, 'boss'),
('blasaloontender', 0, 'boss'),
('rhosaloontender', 0, 'boss');
```

---

## 🌍 Locales
Includes 7 languages: `en`, `fr`, `es`, `it`, `de`, `el`, `pt-br`.  
Loaded via `lib.locale()` on both client and server.

---

## 💎 Credits
- RSG / Rexshack-RedM and contributors  
- Community testers and translators  
