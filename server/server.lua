local RSGCore = exports['rsg-core']:GetCoreObject()
local Accounts = {}

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-bossmenu/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------
-- functions
-------------------------------------------------------------------------------------------

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
        Player.Functions.AddMoney('cash', amount, Lang:t('lang_24'))
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', Lang:t('lang_25'), 'blue', Player.PlayerData.name.. Lang:t('lang_26') .. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_27') ..amount, 'success')
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_28'), 'error')
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
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', Lang:t('lang_29'), 'blue', Player.PlayerData.name.. Lang:t('lang_30') .. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_31') ..amount, 'success')
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_32'), 'error')
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
    if data.grade > Player.PlayerData.job.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_33'), "error") return end
    
    if Employee then
        if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_34'), 'success')
            TriggerClientEvent('RSGCore:Notify', Employee.PlayerData.source, Lang:t('lang_35') ..data.gradename..'.', 'success')
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_36'), 'error')
        end
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_37'), 'error')
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
            if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_38'), 'error') return end
            if Employee.Functions.SetJob('unemployed', '0') then
                TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', Lang:t('lang_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_41'), 'success')
                TriggerClientEvent('RSGCore:Notify', Employee.PlayerData.source , Lang:t('lang_42'), 'error')
            else
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_43'), 'error')
            end
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_44'), 'error')
        end
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] ~= nil then
            Employee = player[1]
            Employee.job = json.decode(Employee.job)
            if Employee.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_45'), 'error') return end
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
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_41'), 'success')
            TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', Lang:t('lang_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_37'), 'error')
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
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_46') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. Lang:t('lang_47') .. Player.PlayerData.job.label .. '', 'success')
        TriggerClientEvent('RSGCore:Notify', Target.PlayerData.source , Lang:t('lang_48') .. Player.PlayerData.job.label .. '', 'success')
        TriggerEvent('rsg-log:server:CreateLog', 'bossmenu', Lang:t('lang_49'), 'lightgreen', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. Lang:t('lang_50') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', false)
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

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
