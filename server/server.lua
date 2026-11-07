local RSGCore = exports['rsg-core']:GetCoreObject()

local Accounts = {}
local Cooldowns = {}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function Notify(src, title, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 5000,
    })
end

local function FullName(charinfo)
    if type(charinfo) ~= 'table' then return '?' end
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

local function Log(title, colour, message)
    TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', title, colour, message, false)
end

--- Boss of a real job standing at one of their boss locations
local function GetBossAtLocation(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local job = Player.PlayerData.job
    if not job or not job.isboss or not RSGCore.Shared.Jobs[job.name] then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pCoords = GetEntityCoords(ped)
    for _, v in ipairs(Config.BossLocations) do
        if (not v.job or v.job == job.name) and #(pCoords - v.coords) <= Config.InteractDistance then
            return Player
        end
    end
end

local function OnCooldown(src)
    local now = GetGameTimer()
    if Cooldowns[src] and (now - Cooldowns[src]) < 1000 then
        return true
    end
    Cooldowns[src] = now
    return false
end

local function SanitizeAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > Config.MaxTransaction then return end
    return amount
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
end)

---------------------------------------------------------------------------
-- society account (exported)
---------------------------------------------------------------------------
function GetAccount(account)
    if type(account) ~= 'string' or account == '' then return 0 end
    return Accounts[account] or 0
end

function AddMoney(account, amount)
    if type(account) ~= 'string' or account == '' then return false end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    amount = math.floor(amount)
    Accounts[account] = (Accounts[account] or 0) + amount
    MySQL.insert(
        'INSERT INTO management_funds (job_name, amount, type) VALUES (?, ?, "boss") ON DUPLICATE KEY UPDATE amount = VALUES(amount)',
        { account, Accounts[account] }
    )
    return true
end

function RemoveMoney(account, amount)
    if type(account) ~= 'string' or account == '' then return false end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    amount = math.floor(amount)
    local balance = Accounts[account] or 0
    if balance < amount then return false end
    Accounts[account] = balance - amount
    MySQL.update(
        'UPDATE management_funds SET amount = ? WHERE job_name = ? AND type = "boss"',
        { Accounts[account], account }
    )
    return true
end

MySQL.ready(function()
    local rows = MySQL.query.await('SELECT job_name, amount FROM management_funds WHERE type = "boss"')
    for _, v in ipairs(rows or {}) do
        Accounts[v.job_name] = tonumber(v.amount) or 0
    end
end)

---------------------------------------------------------------------------
-- stash (name derived server-side)
---------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:openinventory', function()
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player then return end
    exports['rsg-inventory']:OpenInventory(src, 'boss_' .. Player.PlayerData.job.name, {
        label = locale('sv_storage'),
        maxweight = Config.StorageMaxWeight,
        slots = Config.StorageMaxSlots,
    })
end)

---------------------------------------------------------------------------
-- withdraw / deposit
---------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:withdrawMoney', function(amount)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player or OnCooldown(src) then return end
    amount = SanitizeAmount(amount)
    if not amount then
        return Notify(src, locale('cl_8'), locale('sv_invalid_amount'), 'error')
    end

    local job = Player.PlayerData.job.name
    if RemoveMoney(job, amount) then
        Player.Functions.AddMoney('cash', amount, 'bossmenu-withdraw')
        Log(locale('sv_25'), 'blue', ('%s %s $%s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_26'), amount, job))
        Notify(src, locale('cl_8'), locale('sv_27') .. ': $' .. amount, 'success')
    else
        Notify(src, locale('cl_8'), locale('sv_28'), 'error')
    end
end)

RegisterNetEvent('rsg-bossmenu:server:depositMoney', function(amount)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player or OnCooldown(src) then return end
    amount = SanitizeAmount(amount)
    if not amount then
        return Notify(src, locale('cl_8'), locale('sv_invalid_amount'), 'error')
    end

    local job = Player.PlayerData.job.name
    if (Player.PlayerData.money.cash or 0) >= amount and Player.Functions.RemoveMoney('cash', amount, 'bossmenu-deposit') then
        AddMoney(job, amount)
        Log(locale('sv_29'), 'blue', ('%s %s $%s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_30'), amount, job))
        Notify(src, locale('cl_8'), locale('sv_31') .. ': $' .. amount, 'success')
    else
        Notify(src, locale('cl_8'), locale('sv_32'), 'error')
    end
end)

RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetAccount', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job.isboss then
        return cb(nil)
    end
    cb(GetAccount(Player.PlayerData.job.name))
end)

---------------------------------------------------------------------------
-- employees
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetEmployees', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job.isboss then
        return cb(nil)
    end

    local jobname = Player.PlayerData.job.name
    local employees = {}
    local rows = MySQL.query.await(
        "SELECT citizenid, job, charinfo FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?",
        { jobname }
    ) or {}

    for _, row in ipairs(rows) do
        local online = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
        local job = online and online.PlayerData.job or json.decode(row.job) or {}
        local charinfo = online and online.PlayerData.charinfo or json.decode(row.charinfo) or {}
        local grade = job.grade or {}
        employees[#employees + 1] = {
            citizenid = row.citizenid,
            name = FullName(charinfo),
            gradeName = grade.name or '?',
            gradeLevel = tonumber(grade.level) or 0,
            online = online ~= nil,
            isSelf = row.citizenid == Player.PlayerData.citizenid,
        }
    end

    table.sort(employees, function(a, b)
        if a.gradeLevel ~= b.gradeLevel then return a.gradeLevel > b.gradeLevel end
        return a.name < b.name
    end)
    cb(employees)
end)

RegisterNetEvent('rsg-bossmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player or OnCooldown(src) or type(data) ~= 'table' then return end
    if type(data.cid) ~= 'string' or data.cid == '' then return end

    local job = Player.PlayerData.job
    local shared = RSGCore.Shared.Jobs[job.name]
    if not shared then return end
    local grade = tonumber(data.grade)
    local gradeData = grade and (shared.grades[tostring(grade)] or shared.grades[grade])
    if not gradeData then
        return Notify(src, locale('cl_14'), locale('sv_36'), 'error')
    end
    if grade > (tonumber(job.grade.level) or 0) then
        return Notify(src, locale('cl_14'), locale('sv_33'), 'error')
    end
    if data.cid == Player.PlayerData.citizenid then
        return Notify(src, locale('cl_14'), locale('sv_self'), 'error')
    end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(data.cid)
    if not Employee then
        return Notify(src, locale('cl_14'), locale('sv_37'), 'error')
    end
    if Employee.PlayerData.job.name ~= job.name then
        return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error')
    end
    if (tonumber(Employee.PlayerData.job.grade.level) or 0) > (tonumber(job.grade.level) or 0) then
        return Notify(src, locale('cl_14'), locale('sv_33'), 'error')
    end

    if Employee.Functions.SetJob(job.name, grade) then
        Notify(src, locale('cl_14'), locale('sv_34'), 'success')
        Notify(Employee.PlayerData.source, job.label, locale('sv_35') .. ' ' .. gradeData.name .. '.', 'success')
    else
        Notify(src, locale('cl_14'), locale('sv_36'), 'error')
    end
end)

RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(target)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player or OnCooldown(src) then return end
    if type(target) ~= 'string' or target == '' then return end

    local job = Player.PlayerData.job
    local bossName = FullName(Player.PlayerData.charinfo)
    if target == Player.PlayerData.citizenid then
        return Notify(src, locale('cl_14'), locale('sv_44'), 'error')
    end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        if Employee.PlayerData.job.name ~= job.name then
            return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error')
        end
        if (tonumber(Employee.PlayerData.job.grade.level) or 0) > (tonumber(job.grade.level) or 0) then
            return Notify(src, locale('cl_14'), locale('sv_38'), 'error')
        end
        if not Employee.Functions.SetJob('unemployed', 0) then
            return Notify(src, locale('cl_14'), locale('sv_43'), 'error')
        end
        Notify(Employee.PlayerData.source, job.label, locale('sv_42'), 'error')
        Log(locale('sv_39'), 'red', ('%s %s %s (%s)'):format(bossName, locale('sv_40'), FullName(Employee.PlayerData.charinfo), job.name))
        return Notify(src, locale('cl_14'), locale('sv_41'), 'success')
    end

    local row = MySQL.single.await('SELECT job, charinfo FROM players WHERE citizenid = ? LIMIT 1', { target })
    if not row then
        return Notify(src, locale('cl_14'), locale('sv_37'), 'error')
    end
    local pJob = json.decode(row.job) or {}
    if pJob.name ~= job.name then
        return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error')
    end
    if (tonumber(pJob.grade and pJob.grade.level) or 0) > (tonumber(job.grade.level) or 0) then
        return Notify(src, locale('cl_14'), locale('sv_38'), 'error')
    end

    local unemployed = RSGCore.Shared.Jobs['unemployed']
    if not unemployed then
        return Notify(src, locale('cl_14'), locale('sv_43'), 'error')
    end
    local g0 = unemployed.grades['0'] or unemployed.grades[0] or { name = 'Unemployed', payment = 0 }
    MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', {
        json.encode({
            name = 'unemployed',
            label = unemployed.label,
            payment = g0.payment or 0,
            onduty = true,
            isboss = false,
            grade = { name = g0.name or 'Unemployed', level = 0 },
        }),
        target,
    })
    Log(locale('sv_39'), 'red', ('%s %s %s (%s)'):format(bossName, locale('sv_40'), FullName(json.decode(row.charinfo)), job.name))
    Notify(src, locale('cl_14'), locale('sv_41'), 'success')
end)

---------------------------------------------------------------------------
-- hire
---------------------------------------------------------------------------
local function IsNearby(src, target)
    local a = GetPlayerPed(src)
    local b = GetPlayerPed(target)
    if not a or a == 0 or not b or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= Config.HireDistance
end

RegisterNetEvent('rsg-bossmenu:server:HireEmployee', function(recruit)
    local src = source
    local Player = GetBossAtLocation(src)
    recruit = tonumber(recruit)
    if not Player or not recruit or recruit == src or OnCooldown(src) then return end

    local Target = RSGCore.Functions.GetPlayer(recruit)
    if not Target or not IsNearby(src, recruit) then
        return Notify(src, locale('cl_4'), locale('sv_37'), 'error')
    end

    local job = Player.PlayerData.job
    if Target.PlayerData.job.name == job.name then
        return Notify(src, locale('cl_4'), locale('sv_already_employed'), 'error')
    end

    if Target.Functions.SetJob(job.name, 0) then
        local targetName = FullName(Target.PlayerData.charinfo)
        Notify(src, locale('cl_4'), ('%s %s %s'):format(locale('sv_46'), targetName, job.label), 'success')
        Notify(recruit, job.label, locale('sv_48') .. ' ' .. job.label, 'success')
        Log(locale('sv_49'), 'green', ('%s %s %s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_50'), targetName, job.name))
    end
end)

RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetNearbyPlayers', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job.isboss then
        return cb(nil)
    end

    local players = {}
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        id = tonumber(id)
        if id and id ~= source and IsNearby(source, id) then
            local Target = RSGCore.Functions.GetPlayer(id)
            if Target and Target.PlayerData.job.name ~= Player.PlayerData.job.name then
                players[#players + 1] = {
                    name = FullName(Target.PlayerData.charinfo),
                    citizenid = Target.PlayerData.citizenid,
                    source = id,
                }
            end
        end
    end
    table.sort(players, function(a, b) return a.name < b.name end)
    cb(players)
end)
