local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerJob = RSGCore.Functions.GetPlayerData().job
local bossMenusBlips = {}
lib.locale()

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerJob = RSGCore.Functions.GetPlayerData().job
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, v in pairs(Config.BossLocations) do
            exports['rsg-core']:deletePrompt(v.id)
        end
        for _, blip in pairs(bossMenusBlips) do
            RemoveBlip(blip)
        end
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerJob = RSGCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

local function comma_value(amount)
    local formatted = amount
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-------------------------------------------------------------------------------------------
-- prompts and blips if needed
-------------------------------------------------------------------------------------------
CreateThread(function()
    for _, v in pairs(Config.BossLocations) do
        exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open').. ' ' .. v.name, {
            type = 'client',
            event = 'rsg-bossmenu:client:mainmenu',
            args = {},
        })
        if v.showblip == true then
            local BossMenuBlip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(BossMenuBlip,  joaat(Config.Blip.blipSprite), true)
            SetBlipScale(BossMenuBlip, Config.Blip.blipScale)
            SetBlipName(BossMenuBlip, Config.Blip.blipName)
            bossMenusBlips[#bossMenusBlips + 1] = BossMenuBlip
        end
    end
end)

-------------------------------------------------------------------------------------------
-- main menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:mainmenu', function()
    if not PlayerJob.name or not PlayerJob.isboss then return end
    lib.registerContext({
        id = 'boss_mainmenu',
        title = locale('cl_1'),
        options = {
            {
                title = locale('cl_2'),
                description = locale('cl_3'),
                icon = 'fa-solid fa-list',
                event = 'rsg-bossmenu:client:employeelist',
                arrow = true
            },
            {
                title = locale('cl_4'),
                description = locale('cl_5'),
                icon = 'fa-solid fa-hand-holding',
                event = 'rsg-bossmenu:client:HireMenu',
                arrow = true
            },
            {
                title = locale('cl_6'),
                description = locale('cl_7'),
                icon = "fa-solid fa-box-open",
                event = 'rsg-bossmenu:client:Stash',
                arrow = true
            },
            {
                title = locale('cl_8'),
                description = locale('cl_9'),
                icon = "fa-solid fa-sack-dollar",
                event = 'rsg-bossmenu:client:SocietyMenu',
                arrow = true
            },
        }
    })
    lib.showContext('boss_mainmenu')
end)

-------------------------------------------------------------------------------------------
-- employee menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:employeelist', function()
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetEmployees', function(result)
        local options = {}
        for _, v in pairs(result) do
            options[#options + 1] = {
                title = v.name,
                description = v.grade.name,
                icon = 'fa-solid fa-circle-user',
                event = 'rsg-bossmenu:client:ManageEmployee',
                args = { player = v, work = PlayerJob },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'employeelist_menu',
            title = locale('cl_10'),
            menu = 'boss_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('employeelist_menu')
    end, PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- manage employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:ManageEmployee', function(data)
    local options = {}
    for k, v in pairs(RSGCore.Shared.Jobs[data.work.name].grades) do
        options[#options + 1] = {
            title = locale('cl_11').. ' ' .. v.name,
            description = locale('cl_12').. ': ' .. k,
            icon = 'fa-solid fa-file-pen',
            serverEvent = 'rsg-bossmenu:server:GradeUpdate',
            args = { cid = data.player.empSource, grade = tonumber(k), gradename = v.name }
        }
    end
    options[#options + 1] = {
        title = locale('cl_13'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = 'rsg-bossmenu:server:FireEmployee',
        args = data.player.empSource,
        iconColor = 'red'
    }
    lib.registerContext({
        id = 'manageemployee_menu',
        title = locale('cl_14'),
        menu = 'employeelist_menu',
        onBack = function() end,
        position = 'top-right',
        options = options
    })
    lib.showContext('manageemployee_menu')
end)

-------------------------------------------------------------------------------------------
-- hire employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:HireMenu', function()
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:getplayers', function(players)
        local options = {}
        for _, v in pairs(players) do
            if v and v ~= PlayerId() then
                options[#options + 1] = {
                    title = v.name,
                    description = locale('cl_15') .. ': ' .. v.citizenid .. ' - ' .. locale('cl_16').. ': '  .. v.sourceplayer,
                    icon = 'fa-solid fa-user-check',
                    serverEvent = 'rsg-bossmenu:server:HireEmployee',
                    args = v.sourceplayer,
                    arrow = true
                }
            end
        end
        lib.registerContext({
            id = 'hireemployees_menu',
            title = locale('cl_4'),
            menu = 'boss_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('hireemployees_menu')
    end)
end)

-------------------------------------------------------------------------------------------
-- boss stash
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:Stash', function()
    local stashName = 'boss_'..PlayerJob.name
    TriggerServerEvent('rsg-bossmenu:server:openinventory', stashName)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:SocietyMenu', function()
    local currentmoney = RSGCore.Functions.GetPlayerData().money['cash']
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetAccount', function(cb)
        lib.registerContext({
            id = 'society_menu',
            menu = 'boss_mainmenu',
            title = locale('cl_17')  .. ' $: ' .. comma_value(cb),
            options = {
                {
                    title = locale('cl_18'),
                    description = locale('cl_19'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-bossmenu:client:SocetyDeposit',
                    args = currentmoney,
                    iconColor = 'green',
                    arrow = true
                },
                {
                    title = locale('cl_20'),
                    description = locale('cl_21'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-bossmenu:client:SocetyWithDraw',
                    args = comma_value(cb),
                    iconColor = 'red',
                    arrow = true
                },
            }
        })
        lib.showContext('society_menu')
    end, PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- society deposit
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:SocetyDeposit', function(money)
    local input = lib.inputDialog(locale('cl_22') .. ': $ '  .. money, {
        {
            label = locale('cl_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-bossmenu:server:depositMoney", tonumber(input[1]))
end)

-------------------------------------------------------------------------------------------
-- society withdraw
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:SocetyWithDraw', function(money)
    local input = lib.inputDialog(locale('cl_22') .. ': $ '  .. money, {
        {
            label = locale('cl_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-bossmenu:server:withdrawMoney", tonumber(input[1]))
end)
