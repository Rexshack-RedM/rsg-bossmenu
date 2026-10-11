local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerJob = RSGCore.Functions.GetPlayerData().job
local bossMenusBlips = {}
lib.locale()

local function RefreshPrompts()
    for _, v in pairs(Config.BossLocations) do
        exports['rsg-core']:deletePrompt(v.id)
    end
    for _, blip in pairs(bossMenusBlips) do
        RemoveBlip(blip)
    end
    bossMenusBlips = {}

    if not PlayerJob or not PlayerJob.isboss then return end

    for _, v in pairs(Config.BossLocations) do
        if not v.job or v.job == PlayerJob.name then
            exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open') .. ' ' .. v.name, {
                type = 'client',
                event = 'rsg-bossmenu:client:mainmenu',
                args = {},
            })
            if v.showblip == true then
                local BossMenuBlip = BlipAddForCoords(1664425300, v.coords)
                SetBlipSprite(BossMenuBlip, joaat(Config.Blip.blipSprite), true)
                SetBlipScale(BossMenuBlip, Config.Blip.blipScale)
                SetBlipName(BossMenuBlip, Config.Blip.blipName)
                bossMenusBlips[#bossMenusBlips + 1] = BossMenuBlip
            end
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerJob = RSGCore.Functions.GetPlayerData().job
        RefreshPrompts()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PlayerJob = nil
    RefreshPrompts()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerJob = RSGCore.Functions.GetPlayerData().job
    RefreshPrompts()
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    RefreshPrompts()
end)

local function comma_value(amount)
    local formatted = tostring(amount)
    local k
    repeat
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until k == 0
    return formatted
end

local function IsBoss()
    return PlayerJob and PlayerJob.name and PlayerJob.isboss
end

-------------------------------------------------------------------------------------------
-- main menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:mainmenu', function()
    if not IsBoss() then return end
    lib.registerContext({
        id = 'boss_mainmenu',
        title = locale('cl_1'),
        options = {
            { title = locale('cl_2'), description = locale('cl_3'), icon = 'fa-solid fa-list', event = 'rsg-bossmenu:client:employeelist', arrow = true },
            { title = locale('cl_4'), description = locale('cl_5'), icon = 'fa-solid fa-hand-holding', event = 'rsg-bossmenu:client:HireMenu', arrow = true },
            { title = locale('cl_6'), description = locale('cl_7'), icon = 'fa-solid fa-box-open', serverEvent = 'rsg-bossmenu:server:openinventory' },
            { title = locale('cl_8'), description = locale('cl_9'), icon = 'fa-solid fa-sack-dollar', event = 'rsg-bossmenu:client:SocietyMenu', arrow = true },
        }
    })
    lib.showContext('boss_mainmenu')
end)

-------------------------------------------------------------------------------------------
-- employee list
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:employeelist', function()
    if not IsBoss() then return end
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetEmployees', function(result)
        local options = {}
        for _, v in ipairs(result) do
            options[#options + 1] = {
                title = v.name,
                description = v.grade.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-bossmenu:client:ManageEmployee',
                args = v,
                arrow = true,
            }
        end
        if #options == 0 then
            options[1] = { title = locale('cl_no_employees'), icon = 'fa-solid fa-circle-info', disabled = true }
        end
        lib.registerContext({ id = 'employeelist_menu', title = locale('cl_10'), menu = 'boss_mainmenu', position = 'top-right', options = options })
        lib.showContext('employeelist_menu')
    end)
end)

-------------------------------------------------------------------------------------------
-- manage employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:ManageEmployee', function(employee)
    if not IsBoss() then return end
    local grades = {}
    for k, v in pairs(RSGCore.Shared.Jobs[PlayerJob.name].grades) do
        local level = tonumber(k)
        if level and level <= PlayerJob.grade.level then
            grades[#grades + 1] = { level = level, name = v.name }
        end
    end
    table.sort(grades, function(a, b) return a.level < b.level end)

    local options = {}
    for _, g in ipairs(grades) do
        local current = tonumber(employee.grade.level) == g.level
        options[#options + 1] = {
            title = locale('cl_11') .. ' ' .. g.name,
            description = locale('cl_12') .. ': ' .. g.level,
            icon = current and 'fa-solid fa-check' or 'fa-solid fa-file-pen',
            disabled = current,
            serverEvent = 'rsg-bossmenu:server:GradeUpdate',
            args = { cid = employee.citizenid, grade = g.level },
        }
    end
    options[#options + 1] = {
        title = locale('cl_13'),
        icon = 'fa-solid fa-user-large-slash',
        iconColor = 'red',
        onSelect = function()
            local ok = lib.alertDialog({ header = locale('cl_13'), content = locale('cl_fire_confirm', employee.name), centered = true, cancel = true })
            if ok == 'confirm' then TriggerServerEvent('rsg-bossmenu:server:FireEmployee', employee.citizenid) end
        end,
    }
    lib.registerContext({ id = 'manageemployee_menu', title = employee.name, menu = 'employeelist_menu', position = 'top-right', options = options })
    lib.showContext('manageemployee_menu')
end)

-------------------------------------------------------------------------------------------
-- hire
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:HireMenu', function()
    if not IsBoss() then return end
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:getplayers', function(players)
        local options = {}
        for _, v in ipairs(players) do
            options[#options + 1] = {
                title = v.name,
                description = locale('cl_15') .. ': ' .. v.citizenid .. ' - ' .. locale('cl_16') .. ': ' .. v.sourceplayer,
                icon = 'fa-solid fa-user-check',
                serverEvent = 'rsg-bossmenu:server:HireEmployee',
                args = v.sourceplayer,
            }
        end
        if #options == 0 then
            options[1] = { title = locale('cl_no_nearby'), icon = 'fa-solid fa-circle-info', disabled = true }
        end
        lib.registerContext({ id = 'hireemployees_menu', title = locale('cl_4'), menu = 'boss_mainmenu', position = 'top-right', options = options })
        lib.showContext('hireemployees_menu')
    end)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
local function AmountDialog(header)
    local input = lib.inputDialog(header, {
        { label = locale('cl_23'), type = 'number', required = true, min = 1, icon = 'fa-solid fa-dollar-sign' },
    })
    return input and tonumber(input[1])
end

RegisterNetEvent('rsg-bossmenu:client:SocietyMenu', function()
    if not IsBoss() then return end
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetAccount', function(balance)
        local cash = RSGCore.Functions.GetPlayerData().money['cash'] or 0
        lib.registerContext({
            id = 'society_menu',
            menu = 'boss_mainmenu',
            title = locale('cl_17') .. ': $' .. comma_value(balance),
            options = {
                {
                    title = locale('cl_18'), description = locale('cl_19'),
                    icon = 'fa-solid fa-money-bill-transfer', iconColor = 'green',
                    onSelect = function()
                        local amount = AmountDialog(locale('cl_cash') .. ': $' .. comma_value(cash))
                        if amount then TriggerServerEvent('rsg-bossmenu:server:depositMoney', amount) end
                    end,
                },
                {
                    title = locale('cl_20'), description = locale('cl_21'),
                    icon = 'fa-solid fa-money-bill-transfer', iconColor = 'red',
                    onSelect = function()
                        local amount = AmountDialog(locale('cl_22') .. ': $' .. comma_value(balance))
                        if amount then TriggerServerEvent('rsg-bossmenu:server:withdrawMoney', amount) end
                    end,
                },
            }
        })
        lib.showContext('society_menu')
    end)
end)
