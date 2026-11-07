local RSGCore = exports['rsg-core']:GetCoreObject()

local PlayerJob = {}
local bossMenusBlips = {}
local promptIds = {}
local uiOpen = false

local function IsBoss()
    return PlayerJob and PlayerJob.name and PlayerJob.isboss
end

local function notify(msg, nType)
    RSGCore.Functions.Notify({
        title = locale('cl_1'),
        description = msg,
        type = nType or 'inform',
        duration = 5000,
    })
end

local function nuiLocales()
    return {
        menu = locale('cl_1'),
        members = locale('cl_2'),
        members_desc = locale('cl_3'),
        hire = locale('cl_4'),
        hire_desc = locale('cl_5'),
        storage = locale('cl_6'),
        storage_desc = locale('cl_7'),
        money = locale('cl_8'),
        money_desc = locale('cl_9'),
        grade = locale('cl_12'),
        set_grade = locale('cl_11') .. ' %s',
        fire = locale('cl_13'),
        fire_confirm = locale('cl_fire_confirm'),
        citizenid = locale('cl_15'),
        id = locale('cl_16'),
        balance = locale('cl_17'),
        deposit = locale('cl_18'),
        deposit_desc = locale('cl_19'),
        withdraw = locale('cl_20'),
        withdraw_desc = locale('cl_21'),
        available = locale('cl_22'),
        no_members = locale('cl_no_employees'),
        no_nearby = locale('cl_no_nearby'),
        current = locale('cl_current'),
        confirm = locale('cl_confirm'),
        cancel = locale('cl_cancel'),
        accept = locale('cl_accept'),
    }
end

-------------------------------------------------------------------------------------------
-- NUI
-------------------------------------------------------------------------------------------
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMain()
    if not IsBoss() then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        locales = nuiLocales(),
        data = {
            title = PlayerJob.label or locale('cl_1'),
            subtitle = '',
            showLocation = true,
        },
    })
end

local function showEmployees()
    local result = RSGCore.Functions.AwaitCallback('rsg-bossmenu:server:GetEmployees')
    if not result then return end
    SendNUIMessage({
        action = 'members',
        locales = nuiLocales(),
        data = {
            gangLabel = PlayerJob.label or '',
            members = result,
        },
    })
end

local function showManage(citizenid)
    local result = RSGCore.Functions.AwaitCallback('rsg-bossmenu:server:GetEmployees')
    if not result then return end
    local emp
    for _, v in ipairs(result) do
        if v.citizenid == citizenid then
            emp = v
            break
        end
    end
    if not emp then return end

    local jobShared = RSGCore.Shared.Jobs[PlayerJob.name]
    if not jobShared then return end
    local myLevel = tonumber(PlayerJob.grade and PlayerJob.grade.level) or 0
    local levels = {}
    for k in pairs(jobShared.grades) do
        levels[#levels + 1] = tonumber(k)
    end
    table.sort(levels)

    local grades = {}
    for _, lvl in ipairs(levels) do
        if lvl <= myLevel then
            local g = jobShared.grades[tostring(lvl)] or jobShared.grades[lvl]
            if g then
                grades[#grades + 1] = {
                    level = lvl,
                    name = g.name,
                    current = lvl == emp.gradeLevel,
                    disabled = lvl == emp.gradeLevel,
                }
            end
        end
    end

    SendNUIMessage({
        action = 'manage',
        locales = nuiLocales(),
        data = { employee = emp, grades = grades },
    })
end

local function showHire()
    local players = RSGCore.Functions.AwaitCallback('rsg-bossmenu:server:GetNearbyPlayers') or {}
    SendNUIMessage({
        action = 'hire',
        locales = nuiLocales(),
        data = { players = players },
    })
end

local function showSociety()
    local balance = RSGCore.Functions.AwaitCallback('rsg-bossmenu:server:GetAccount')
    if balance == nil then return end
    local pdata = RSGCore.Functions.GetPlayerData()
    local cash = (pdata.money and pdata.money.cash) or 0
    SendNUIMessage({
        action = 'society',
        locales = nuiLocales(),
        data = {
            balance = balance,
            cash = cash,
            maxTransaction = Config.MaxTransaction,
        },
    })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.type) ~= 'string' then return end

    if data.type == 'back' then
        openMain()
        return
    end
    if data.type == 'members' then
        showEmployees()
        return
    end
    if data.type == 'hire' then
        showHire()
        return
    end
    if data.type == 'hirePlayer' then
        local sid = tonumber(data.source)
        if sid then
            TriggerServerEvent('rsg-bossmenu:server:HireEmployee', sid)
        end
        return
    end
    if data.type == 'storage' then
        closeUI()
        TriggerServerEvent('rsg-bossmenu:server:openinventory')
        return
    end
    if data.type == 'money' then
        showSociety()
        return
    end
    if data.type == 'manage' and type(data.citizenid) == 'string' then
        showManage(data.citizenid)
        return
    end
    if data.type == 'setGrade' and type(data.citizenid) == 'string' then
        TriggerServerEvent('rsg-bossmenu:server:GradeUpdate', {
            cid = data.citizenid,
            grade = tonumber(data.grade),
        })
        showEmployees()
        return
    end
    if data.type == 'fire' and type(data.citizenid) == 'string' then
        TriggerServerEvent('rsg-bossmenu:server:FireEmployee', data.citizenid)
        showEmployees()
        return
    end
    if data.type == 'deposit' then
        local amount = tonumber(data.amount)
        if amount and amount >= 1 then
            TriggerServerEvent('rsg-bossmenu:server:depositMoney', math.floor(amount))
            SetTimeout(400, showSociety)
        end
        return
    end
    if data.type == 'withdraw' then
        local amount = tonumber(data.amount)
        if amount and amount >= 1 then
            TriggerServerEvent('rsg-bossmenu:server:withdrawMoney', math.floor(amount))
            SetTimeout(400, showSociety)
        end
        return
    end
end)

-------------------------------------------------------------------------------------------
-- prompts / blips
-------------------------------------------------------------------------------------------
local function ClearBlips()
    for _, blip in pairs(bossMenusBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    bossMenusBlips = {}
end

local function ClearPrompts()
    for _, id in ipairs(promptIds) do
        pcall(function()
            exports['rsg-core']:deletePrompt(id)
        end)
    end
    -- also clear by config id in case of stale state
    for _, v in pairs(Config.BossLocations) do
        pcall(function()
            exports['rsg-core']:deletePrompt(v.id)
        end)
    end
    promptIds = {}
end

local function RefreshPrompts()
    ClearPrompts()
    ClearBlips()

    if not PlayerJob or not PlayerJob.isboss then return end

    for _, v in pairs(Config.BossLocations) do
        if not v.job or v.job == PlayerJob.name then
            exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open') .. ' ' .. v.name, {
                type = 'client',
                event = 'rsg-bossmenu:client:mainmenu',
                args = {},
            })
            promptIds[#promptIds + 1] = v.id

            if v.showblip then
                local blip = BlipAddForCoords(1664425300, v.coords)
                SetBlipSprite(blip, joaat(Config.Blip.blipSprite), true)
                SetBlipScale(blip, Config.Blip.blipScale)
                SetBlipName(blip, Config.Blip.blipName)
                bossMenusBlips[#bossMenusBlips + 1] = blip
            end
        end
    end
end

local function RefreshJob()
    local data = RSGCore.Functions.GetPlayerData()
    PlayerJob = (data and data.job) or {}
    RefreshPrompts()
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        RefreshJob()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUI()
    ClearPrompts()
    ClearBlips()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', RefreshJob)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerJob = {}
    closeUI()
    ClearPrompts()
    ClearBlips()
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo or {}
    RefreshPrompts()
end)

-------------------------------------------------------------------------------------------
-- open
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:mainmenu', function()
    if not IsBoss() then return end
    openMain()
end)
