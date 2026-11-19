# rsg-bossmenu – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `oxmysql`, `rsg-inventory`; exports `AddMoney`, `RemoveMoney`, `GetAccount` |
| `config.lua` | Boss locations, keybind, limits |
| `client/client.lua` | Prompts, blips, NUI bridge |
| `server/server.lua` | Employees, hire/fire/grade, stash, society account |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (`index.html`, `style.css`, `script.js`) |
| `locales/*.json` | en, cs, de, el, es, fr, hu, it, pl, pt-br |

## 2. How it works
- A boss stands at one of the `Config.BossLocations` and presses `Config.Keybind` (default `J`) to open the menu.
- Employee list (online and offline), promote/demote, fire (online or offline), hire nearby players.
- Shared boss stash through rsg-inventory, named `boss_<job>`.
- Society bank in the `management_funds` table (type `boss`), shared with rsg-gangmenu's table.
- The player's job grade must have `isboss = true`.

## 3. Configuration
`config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Blip` | table | Blip name, sprite, scale |
| `Keybind` | `'J'` | Open key |
| `StorageMaxWeight` | `4000000` | Stash weight |
| `StorageMaxSlots` | `50` | Stash slots |
| `InteractDistance` | `5.0` | Server-side max distance from a boss location |
| `HireDistance` | `10.0` | Max distance to a player you can hire |
| `MaxTransaction` | `1000000` | Max single deposit/withdraw |
| `BossLocations` | list | `{ id, name, coords, showblip, job }`; `job` must match the job name |

```lua
{ id = 'sheriff_boss', name = 'Law Boss Menu', coords = vector3(0, 0, 0), showblip = false, job = 'vallaw' },
```

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `GetAccount(account)` | server export | Balance of a job account |
| `AddMoney(account, amount)` | server export | Returns true/false; amount is floored and must be > 0 |
| `RemoveMoney(account, amount)` | server export | False if the balance is too low |
| `rsg-bossmenu:client:mainmenu` | client event | Open the menu |
| `rsg-bossmenu:server:openinventory` | server event | Open the boss stash |
| `rsg-bossmenu:server:withdrawMoney` / `depositMoney` | server events | `(amount)` |
| `rsg-bossmenu:server:GetAccount` | callback | Balance for the player's job |
| `rsg-bossmenu:server:GetEmployees` | callback | Employee list |
| `rsg-bossmenu:server:GradeUpdate` | server event | `(data)` promote/demote |
| `rsg-bossmenu:server:FireEmployee` | server event | `(target)` |
| `rsg-bossmenu:server:HireEmployee` | server event | `(recruit)` |
| `rsg-bossmenu:server:GetNearbyPlayers` | callback | Hire candidates |

```lua
exports['rsg-bossmenu']:AddMoney('vallaw', 500)
```

## 5. Database
Uses the `management_funds` table (`job_name`, `amount`, `type`), created by the rsg-core SQL. This resource only writes rows with `type = 'boss'`.

## 6. Security
Every action re-checks the real job and boss status on the server. The stash name and job are never taken from the client. Stash and money need proximity to a configured boss location. Amounts are sanitised and capped, and actions have cooldowns. Hiring re-checks distance. Actions are logged through rsg-log.

## 7. How-tos
- New job menu: add a `BossLocations` entry; the job must exist in your jobs data and its boss grade needs `isboss = true`.
- Pay a society from another script: `exports['rsg-bossmenu']:AddMoney(job, amount)`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| No prompt at the location | Player's job must match `job`, and the grade must be boss |
| Money won't load | Check the `management_funds` table exists |
| Can't hire | Target must be within `HireDistance` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-bossmenu 3.0.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Blip` | `table` | blip settings |
| `Config.Keybind` | `'J'` | settings |
| `Config.StorageMaxWeight` | `4000000` |  |
| `Config.StorageMaxSlots` | `50` |  |
| `Config.InteractDistance` | `5.0` | max distance from a boss location for server actions |
| `Config.HireDistance` | `10.0` | max distance to a player you can hire |
| `Config.MaxTransaction` | `1000000` | max single deposit/withdraw |
| `Config.BossLocations` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-bossmenu:server:GetAccount` | server | `source, cb` | `server/server.lua` |
| `rsg-bossmenu:server:GetEmployees` | server | `source, cb` | `server/server.lua` |
| `rsg-bossmenu:server:GetNearbyPlayers` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetAccount', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnJobUpdate` | client | `JobInfo` | `client/client.lua` |
| `rsg-bossmenu:client:mainmenu` | client | `` | `client/client.lua` |
| `rsg-bossmenu:server:openinventory` | server | `` | `server/server.lua` |
| `rsg-bossmenu:server:withdrawMoney` | server | `amount` | `server/server.lua` |
| `rsg-bossmenu:server:depositMoney` | server | `amount` | `server/server.lua` |
| `rsg-bossmenu:server:GradeUpdate` | server | `data` | `server/server.lua` |
| `rsg-bossmenu:server:FireEmployee` | server | `target` | `server/server.lua` |
| `rsg-bossmenu:server:HireEmployee` | server | `recruit` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-bossmenu:server:openinventory')
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Locales

Language files in `locales/`: `cs`, `de`, `el`, `en`, `es`, `fr`, `hu`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
