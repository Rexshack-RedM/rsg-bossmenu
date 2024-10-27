local RSGCore = exports['rsg-core']:GetCoreObject()
local Accounts = {}
lib.locale()

---------------
-- stash
----------------
RegisterNetEvent('rsg-bossmenu:server:openinventory', function(stashName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = locale('sv_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots }
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

---------------------
-- functions
---------------------
function GetAccount(account)
    return Accounts[account] or 0
end

function AddMoney(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end

    Accounts[account] = Accounts[account] + amount
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount', { ['job_name'] = account, ['amount'] = Accounts[account], ['type'] = 'boss' })
end

function RemoveMoney(account, amount)
    local isRemoved = false
    if amount > 0 then
        if not Accounts[account] then
            Accounts[account] = 0
        end

        if Accounts[account] >= amount then
            Accounts[account] = Accounts[account] - amount
            isRemoved = true
        end

        MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "boss"', { Accounts[account], account })
    end
    return isRemoved
end

MySQL.ready(function ()
    local bossmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "boss"', {})
    if not bossmenu then return end

    for _,v in ipairs(bossmenu) do
        Accounts[v.job_name] = v.amount
    end
end)

-------------------------------------------------------------------------------------------
-- withdraw money
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:withdrawMoney', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    local job = Player.PlayerData.job.name
    if RemoveMoney(job, amount) then
        Player.Functions.AddMoney('cash', amount, locale('sv_24'))
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_25'), 'blue', Player.PlayerData.name.. locale('sv_26') .. ' $'.. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_27').. ': $ ' ..amount, type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_28'), type = 'error', duration = 5000 })
    end
end)

-------------------------------------------------------------------------------------------
-- deposit money
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:depositMoney', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    if Player.Functions.RemoveMoney('cash', amount) then
        local job = Player.PlayerData.job.name
        AddMoney(job, amount)
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_29'), 'blue', Player.PlayerData.name.. locale('sv_30') .. ' $'.. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_31') .. ': $ '..amount, type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_32'), type = 'error', duration = 5000 })
    end

    TriggerClientEvent('rsg-bossmenu:client:OpenMenu', src)
end)

RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetAccount', function(_, cb, jobname)
    local result = GetAccount(jobname)
    cb(result)
end)

-------------------------------------------------------------------------------------------
-- get employees
-------------------------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetEmployees', function(source, cb, jobname)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    local employees = {}
    local players = MySQL.query.await("SELECT * FROM `players` WHERE `job` LIKE '%".. jobname .."%'", {})
    if players[1] ~= nil then
        for _, value in pairs(players) do
            local isOnline = RSGCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                employees[#employees+1] = {
                empSource = isOnline.PlayerData.citizenid,
                grade = isOnline.PlayerData.job.grade,
                isboss = isOnline.PlayerData.job.isboss,
                name = '🟢 ' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                }
            else
                employees[#employees+1] = {
                empSource = value.citizenid,
                grade =  json.decode(value.job).grade,
                isboss = json.decode(value.job).isboss,
                name = '❌ ' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                }
            end
        end
        table.sort(employees, function(a, b)
            return a.grade.level > b.grade.level
        end)
    end
    cb(employees)
end)

-------------------------------------------------------------------------------------------
-- grade update
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(data.cid)

    if not Player.PlayerData.job.isboss then return end
    if data.grade > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_33'), type = 'error', duration = 5000 }) return end
    
    if Employee then
        if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_34'), type = 'success', duration = 5000 })
            TriggerClientEvent('ox_lib:notify', src, {title = Employee.PlayerData.source, locale('sv_35') ..data.gradename..'.', type = 'success', duration = 5000 })
        else
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_36'), type = 'error', duration = 5000 })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_37'), type = 'error', duration = 5000 })
    end
end)

-------------------------------------------------------------------------------------------
-- fire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(target)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)

    if not Player.PlayerData.job.isboss then return end

    if Employee then
        if target ~= Player.PlayerData.citizenid then
            if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_38'), type = 'error', duration = 5000 }) return end
            if Employee.Functions.SetJob('unemployed', '0') then
                TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' '.. locale('sv_40') .. ' '.. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
                TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_41'), type = 'success', duration = 5000 })
                TriggerClientEvent('ox_lib:notify', src, {title = Employee.PlayerData.source , locale('sv_42'), type = 'error', duration = 5000 })
            else
                TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_43'), type = 'error', duration = 5000 })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_44'), type = 'error', duration = 5000 })
        end
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] ~= nil then
            Employee = player[1]
            Employee.job = json.decode(Employee.job)
            if Employee.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_45'), type = 'error', duration = 5000 }) return end
            local job = {}
            job.name = 'unemployed'
            job.label = 'Unemployed'
            job.payment = RSGCore.Shared.Jobs[job.name].grades['0'].payment or 500
            job.onduty = true
            job.isboss = false
            job.grade = {}
            job.grade.name = nil
            job.grade.level = 0
            MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), target })
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_41'), type = 'success', duration = 5000 })
            TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' '.. locale('sv_40').. ' ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
        else
            TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_37'), type = 'error', duration = 5000 })
        end
    end
end)

-------------------------------------------------------------------------------------------
-- hire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:server:HireEmployee', function(recruit)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(recruit)

    if not Player.PlayerData.job.isboss then return end

    if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_46') .. ' ' .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' '.. locale('sv_47') .. ' '.. Player.PlayerData.job.label .. '', type = 'success', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', src, {title = Target.PlayerData.source , locale('sv_48') .. ' '.. Player.PlayerData.job.label .. '', type = 'success', duration = 5000 })
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', locale('sv_49'), 'lightgreen', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. ' '.. locale('sv_50') .. ' '.. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', false)
    end
end)

-------------------------------------------------------------------------------------------
-- get closest player
-------------------------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-bossmenu:getplayers', function(source, cb)
    local src = source
    local players = {}
    local PlayerPed = GetPlayerPed(src)
    local pCoords = GetEntityCoords(PlayerPed)
    for _, v in pairs(RSGCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local tCoords = GetEntityCoords(targetped)
        local dist = #(pCoords - tCoords)
        if PlayerPed ~= targetped and dist < 10 then
            local ped = RSGCore.Functions.GetPlayer(v)
            players[#players+1] = {
            id = v,
            coords = GetEntityCoords(targetped),
            name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer = ped.PlayerData.source
            }
        end
    end
        table.sort(players, function(a, b)
            return a.name < b.name
        end)
    cb(players)
end)