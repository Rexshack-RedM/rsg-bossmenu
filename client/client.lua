local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerJob = RSGCore.Functions.GetPlayerData().job

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerJob = RSGCore.Functions.GetPlayerData().job
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
-- main menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:mainmenu', function()
    if not PlayerJob.name or not PlayerJob.isboss then return end
    lib.registerContext({
        id = 'boss_mainmenu',
        title = 'Boss Menu',
        options = {
            {
                title = 'Manage Employees',
                description = 'Check your Employees List',
                icon = 'fa-solid fa-list',
                event = 'rsg-bossmenu:client:employeelist',
                arrow = true
            },
            {
                title = 'Hire Employees',
                description = 'Hire Nearby Civilians',
                icon = 'fa-solid fa-hand-holding',
                event = 'rsg-bossmenu:client:HireMenu',
                arrow = true
            },
            {
                title = "Storage Access",
                description = "Open Storage",
                icon = "fa-solid fa-box-open",
                event = 'rsg-bossmenu:client:Stash',
                arrow = true
            },
            {
                title = "Money Management",
                description = "Check your Company Balance",
                icon = "fa-solid fa-sack-dollar",
                event = 'rsg-bossmenu:client:SocietyMenu',
                arrow = true
            },
        }
    })
    lib.showContext("boss_mainmenu")
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
            title = 'Employee List',
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
            title = 'set grade as '..v.name,
            description = "Grade: " .. k,
            icon = 'fa-solid fa-file-pen',
            serverEvent = 'rsg-bossmenu:server:GradeUpdate',
            args = { cid = data.player.empSource, grade = tonumber(k), gradename = v.name }
        }
    end
    options[#options + 1] = {
        title = "Fire Employee",
        icon = "fa-solid fa-user-large-slash",
        serverEvent = 'rsg-bossmenu:server:FireEmployee',
        args = data.player.empSource,
        iconColor = 'red'
    }
    lib.registerContext({
        id = 'manageemployee_menu',
        title = 'Manage Employee',
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
                    description = 'Citizen ID: ' .. v.citizenid .. ' - ID: ' .. v.sourceplayer,
                    icon = 'fa-solid fa-user-check',
                    event = 'rsg-bossmenu:server:HireEmployee',
                    args = v.sourceplayer,
                    arrow = true
                }
            end
        end
        lib.registerContext({
            id = 'hireemployees_menu',
            title = 'Hire Employees',
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
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "boss_" .. PlayerJob.name, {
        maxweight = 4000000,
        slots = 25,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "boss_" .. PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:SocietyMenu', function()
    local currentmoney = RSGCore.Functions.GetPlayerData().money['cash']
    RSGCore.Functions.TriggerCallback('rsg-bossmenu:server:GetAccount', function(cb)
        print(cb)
        lib.registerContext({
            id = 'society_menu',
            title = "Balance: $" .. comma_value(cb),
            options = {
                {
                    title = 'Deposit',
                    description = 'deposit money into your account',
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-bossmenu:client:SocetyDeposit',
                    args = currentmoney,
                    iconColor = 'green',
                    arrow = true
                },
                {
                    title = 'Withdraw',
                    description = 'withdraw money from your account',
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'rsg-bossmenu:client:SocetyWithDraw',
                    args = comma_value(cb),
                    iconColor = 'red',
                    arrow = true
                },
            }
        })
        lib.showContext("society_menu")
    end, PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- society deposit
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-bossmenu:client:SocetyDeposit', function(money)
    local input = lib.inputDialog('Available Balance: $' .. money, {
        { 
            label = 'Amount',
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
    local input = lib.inputDialog('Available Balance: $' .. money, {
        { 
            label = 'Amount',
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("rsg-bossmenu:server:withdrawMoney", tonumber(input[1]))
end)
