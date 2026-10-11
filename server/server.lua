local RSGCore = exports['rsg-core']:GetCoreObject()
local Accounts = {}
lib.locale()

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function Notify(src, title, description, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = description, type = nType or 'inform', duration = 5000 })
end

local function FullName(charinfo)
    return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
end

-- returns the Player if they are a boss standing at one of their job's boss locations
local function GetBossAtLocation(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.job.isboss then return end
    local job = Player.PlayerData.job.name
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(Config.BossLocations) do
        if (not v.job or v.job == job) and #(pCoords - v.coords) <= Config.InteractDistance then
            return Player
        end
    end
end

local function SanitizeAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount <= 0 or amount > Config.MaxTransaction then return end
    return math.floor(amount * 100 + 0.5) / 100
end

---------------------------------------------------------------------------
-- society account (also exported)
---------------------------------------------------------------------------
function GetAccount(account)
    return Accounts[account] or 0
end

function AddMoney(account, amount)
    amount = tonumber(amount)
    if not account or not amount or amount <= 0 then return false end
    Accounts[account] = (Accounts[account] or 0) + amount
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (?, ?, "boss") ON DUPLICATE KEY UPDATE amount = VALUES(amount)', { account, Accounts[account] })
    return true
end

function RemoveMoney(account, amount)
    amount = tonumber(amount)
    if not account or not amount or amount <= 0 then return false end
    if (Accounts[account] or 0) < amount then return false end
    Accounts[account] = Accounts[account] - amount
    MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? AND type = "boss"', { Accounts[account], account })
    return true
end

MySQL.ready(function()
    local rows = MySQL.query.await('SELECT job_name, amount FROM management_funds WHERE type = "boss"')
    if not rows then return end
    for _, v in ipairs(rows) do
        Accounts[v.job_name] = v.amount
    end
end)

---------------------------------------------------------------------------
-- stash (name derived server-side from the boss's job)
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
    if not Player then return end
    amount = SanitizeAmount(amount)
    if not amount then return Notify(src, locale('cl_8'), locale('sv_invalid_amount'), 'error') end

    local job = Player.PlayerData.job.name
    if RemoveMoney(job, amount) then
        Player.Functions.AddMoney('cash', amount, 'bossmenu-withdraw')
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_25'), 'blue', ('%s %s $%s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_26'), amount, job), false)
        Notify(src, locale('cl_8'), locale('sv_27') .. ': $' .. amount, 'success')
    else
        Notify(src, locale('cl_8'), locale('sv_28'), 'error')
    end
    TriggerClientEvent('rsg-bossmenu:client:SocietyMenu', src)
end)

RegisterNetEvent('rsg-bossmenu:server:depositMoney', function(amount)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player then return end
    amount = SanitizeAmount(amount)
    if not amount then return Notify(src, locale('cl_8'), locale('sv_invalid_amount'), 'error') end

    local job = Player.PlayerData.job.name
    if Player.Functions.RemoveMoney('cash', amount, 'bossmenu-deposit') then
        AddMoney(job, amount)
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_29'), 'blue', ('%s %s $%s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_30'), amount, job), false)
        Notify(src, locale('cl_8'), locale('sv_31') .. ': $' .. amount, 'success')
    else
        Notify(src, locale('cl_8'), locale('sv_32'), 'error')
    end
    TriggerClientEvent('rsg-bossmenu:client:SocietyMenu', src)
end)

RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetAccount', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job.isboss then return cb(0) end
    cb(GetAccount(Player.PlayerData.job.name))
end)

---------------------------------------------------------------------------
-- employees
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetEmployees', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job.isboss then return cb({}) end

    local jobname = Player.PlayerData.job.name
    local employees = {}
    local rows = MySQL.query.await("SELECT citizenid, job, charinfo FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?", { jobname }) or {}
    for _, row in ipairs(rows) do
        local online = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
        local job = online and online.PlayerData.job or json.decode(row.job)
        local charinfo = online and online.PlayerData.charinfo or json.decode(row.charinfo)
        employees[#employees + 1] = {
            citizenid = row.citizenid,
            grade = job.grade,
            name = (online and locale('sv_online') or locale('sv_offline')) .. ' ' .. FullName(charinfo),
        }
    end
    table.sort(employees, function(a, b) return (tonumber(a.grade.level) or 0) > (tonumber(b.grade.level) or 0) end)
    cb(employees)
end)

RegisterNetEvent('rsg-bossmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = GetBossAtLocation(src)
    if not Player or type(data) ~= 'table' then return end

    local job = Player.PlayerData.job
    local grade = tonumber(data.grade)
    local gradeData = grade and RSGCore.Shared.Jobs[job.name].grades[tostring(grade)]
    if not gradeData then return Notify(src, locale('cl_14'), locale('sv_36'), 'error') end
    if grade > job.grade.level then return Notify(src, locale('cl_14'), locale('sv_33'), 'error') end
    if data.cid == Player.PlayerData.citizenid then return Notify(src, locale('cl_14'), locale('sv_self'), 'error') end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(data.cid)
    if not Employee then return Notify(src, locale('cl_14'), locale('sv_37'), 'error') end
    if Employee.PlayerData.job.name ~= job.name then return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error') end
    if Employee.PlayerData.job.grade.level > job.grade.level then return Notify(src, locale('cl_14'), locale('sv_33'), 'error') end

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
    if not Player or type(target) ~= 'string' then return end

    local job = Player.PlayerData.job
    local bossName = FullName(Player.PlayerData.charinfo)
    if target == Player.PlayerData.citizenid then return Notify(src, locale('cl_14'), locale('sv_44'), 'error') end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        if Employee.PlayerData.job.name ~= job.name then return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error') end
        if Employee.PlayerData.job.grade.level > job.grade.level then return Notify(src, locale('cl_14'), locale('sv_38'), 'error') end
        if not Employee.Functions.SetJob('unemployed', 0) then return Notify(src, locale('cl_14'), locale('sv_43'), 'error') end
        Notify(Employee.PlayerData.source, job.label, locale('sv_42'), 'error')
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_39'), 'red', ('%s %s %s (%s)'):format(bossName, locale('sv_40'), FullName(Employee.PlayerData.charinfo), job.name), false)
        return Notify(src, locale('cl_14'), locale('sv_41'), 'success')
    end

    local row = MySQL.single.await('SELECT job, charinfo FROM players WHERE citizenid = ? LIMIT 1', { target })
    if not row then return Notify(src, locale('cl_14'), locale('sv_37'), 'error') end
    local pJob = json.decode(row.job)
    if pJob.name ~= job.name then return Notify(src, locale('cl_14'), locale('sv_not_employee'), 'error') end
    if (tonumber(pJob.grade.level) or 0) > job.grade.level then return Notify(src, locale('cl_14'), locale('sv_38'), 'error') end

    local unemployed = RSGCore.Shared.Jobs['unemployed']
    local g0 = unemployed.grades['0']
    MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode({
        name = 'unemployed', label = unemployed.label, payment = g0.payment or 0,
        onduty = true, isboss = false, grade = { name = g0.name, level = 0 },
    }), target })
    TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_39'), 'red', ('%s %s %s (%s)'):format(bossName, locale('sv_40'), FullName(json.decode(row.charinfo)), job.name), false)
    Notify(src, locale('cl_14'), locale('sv_41'), 'success')
end)

---------------------------------------------------------------------------
-- hire
---------------------------------------------------------------------------
local function IsNearby(src, target)
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) <= Config.HireDistance
end

RegisterNetEvent('rsg-bossmenu:server:HireEmployee', function(recruit)
    local src = source
    local Player = GetBossAtLocation(src)
    recruit = tonumber(recruit)
    if not Player or not recruit or recruit == src then return end

    local Target = RSGCore.Functions.GetPlayer(recruit)
    if not Target or not IsNearby(src, recruit) then return Notify(src, locale('cl_4'), locale('sv_37'), 'error') end

    local job = Player.PlayerData.job
    if Target.PlayerData.job.name == job.name then return Notify(src, locale('cl_4'), locale('sv_already_employed'), 'error') end

    if Target.Functions.SetJob(job.name, 0) then
        local targetName = FullName(Target.PlayerData.charinfo)
        Notify(src, locale('cl_4'), ('%s %s %s'):format(locale('sv_46'), targetName, job.label), 'success')
        Notify(recruit, job.label, locale('sv_48') .. ' ' .. job.label, 'success')
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_49'), 'lightgreen', ('%s %s %s (%s)'):format(FullName(Player.PlayerData.charinfo), locale('sv_50'), targetName, job.name), false)
    end
end)

RSGCore.Functions.CreateCallback('rsg-bossmenu:getplayers', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.job.isboss then return cb({}) end

    local players = {}
    for _, v in pairs(RSGCore.Functions.GetPlayers()) do
        v = tonumber(v)
        if v ~= src and IsNearby(src, v) then
            local Target = RSGCore.Functions.GetPlayer(v)
            if Target and Target.PlayerData.job.name ~= Player.PlayerData.job.name then
                players[#players + 1] = {
                    name = FullName(Target.PlayerData.charinfo),
                    citizenid = Target.PlayerData.citizenid,
                    sourceplayer = v,
                }
            end
        end
    end
    table.sort(players, function(a, b) return a.name < b.name end)
    cb(players)
end)
