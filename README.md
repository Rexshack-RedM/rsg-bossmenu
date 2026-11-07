# rsg-bossmenu

Boss management menu for **RSG Framework** (RedM). Job bosses can manage employees, hire nearby players, open job storage, and manage the company bank.

## Features
- Employee list (online/offline), promote/demote, fire (online or offline)
- Hire nearby civilians (server distance check)
- Shared boss stash via rsg-inventory (`boss_<job>`)
- Society bank (`management_funds` type `boss`)
- Optional map blips
- Custom NUI (RSG brain design standard)

## Dependencies
- rsg-core
- oxmysql
- rsg-inventory

## Installation
1. Place in resources and ensure after dependencies.
2. Confirm `management_funds` table exists (shared with rsg-gangmenu).
3. Configure `config.lua` locations — `job` must match `rsg-core/shared/jobs.lua`.
4. Boss grade must have `isboss = true`.

```cfg
ensure oxmysql
ensure rsg-core
ensure rsg-inventory
ensure rsg-bossmenu
```

Language: `setr rsg:locale "en"`

## Security
- Boss + location checks on stash, money, hire, grade, fire
- Amounts sanitised and rate-limited
- Stash name derived on the server

## Exports (server)
```lua
exports['rsg-bossmenu']:GetAccount(jobName)
exports['rsg-bossmenu']:AddMoney(jobName, amount)
exports['rsg-bossmenu']:RemoveMoney(jobName, amount)
```
