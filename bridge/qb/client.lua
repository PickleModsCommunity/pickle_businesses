if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function ServerCallback(name, cb, ...)
    QBCore.Functions.TriggerCallback(name, cb,  ...)
end

function ShowNotification(text)
	QBCore.Functions.Notify(text)
end

function CanAccessGroup(data)
    if not data then return true end
    local pdata = QBCore.Functions.GetPlayerData()
    for k,v in pairs(data) do 
        if (pdata.job.name == k and pdata.job.grade.level >= v) then return true end
    end
    return false
end 

RegisterNetEvent(GetCurrentResourceName()..":showNotification", function(text)
    ShowNotification(text)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent("pickle_businesses:initializePlayer")
end)

-- Inventory Fallback

CreateThread(function()
    Wait(100)
    
    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.

    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false
    
    -- STASHES
    
    Inventory.OpenStash = function(id,label)
        ShowNotification('Business storage requires ox_inventory for server-enforced role permissions.')
    end
    
    RegisterNetEvent("pickle_businesses:setupInventory", function(data)
        Inventory.Items = data.items
        Inventory.Ready = true
    end)
    
    RegisterNetEvent("pickle_businesses:updateInventory", function(inventory) 
        RefreshInventory(inventory)
    end)
end)