if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function RegisterCallback(name, cb)
    QBCore.Functions.CreateCallback(name, cb)
end

function RegisterUsableItem(...)
    QBCore.Functions.CreateUseableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local player=QBCore.Functions.GetPlayer(source)
    local xPlayer=player and player.PlayerData
    return xPlayer and xPlayer.citizenid
end

function GetSourceFromIdentifier(identifier)
    local xPlayer = QBCore.Functions.GetPlayerByCitizenId(identifier)
    return xPlayer and xPlayer.PlayerData.source or nil
end

function GetPaymentMethodAmount(src,method)
    local p=QBCore.Functions.GetPlayer(src)
    if not p then return 0 end
    if method=='dirtycash' then return Inventory.GetItemCount(src,Config.DirtyMoneyItem or 'markedbills') end
    return p.PlayerData.money[method=='card' and 'bank' or 'cash'] or 0
end
function ChargePaymentMethod(src,method,amount)
    if not BusinessInt(amount,0,2147483647) then return false end
    local p=QBCore.Functions.GetPlayer(src); if not p then return false end
    if amount==0 then return true end
    if method=='dirtycash' then return Inventory.RemoveItem(src,Config.DirtyMoneyItem or 'markedbills',amount)==true end
    return p.Functions.RemoveMoney(method=='card' and 'bank' or 'cash',amount)==true
end
function AddPaymentMethodAmount(src,method,amount)
    if not BusinessInt(amount,0,2147483647) then return false end
    local p=QBCore.Functions.GetPlayer(src); if not p then return false end
    if amount==0 then return true end
    if method=='dirtycash' then return Inventory.AddItem(src,Config.DirtyMoneyItem or 'markedbills',amount)==true end
    return p.Functions.AddMoney(method=='card' and 'bank' or 'cash',amount)==true
end

function GetPlayerCharacterName(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    return xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname
end

function CanAdministrateBusinesses(source)
    return CheckPermission(source, Config.BusinessAdministration)
end

function CheckPermission(source, permission)
    local source = tonumber(source)
    local player=QBCore.Functions.GetPlayer(source)
    local xPlayer=player and player.PlayerData
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade.level
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if QBCore.Functions.HasPermission(source, permission.groups[i]) then 
            return true 
        end
    end
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)
    
    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.
    
    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false

    Inventory.CanCarryItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local weight = QBCore.Player.GetTotalWeight(xPlayer.PlayerData.items)
        local item = QBCore.Shared.Items[name:lower()]
        return ((weight + (item.weight * count)) <= QBCore.Config.Player.MaxWeight)
    end

    Inventory.GetInventory = function(source)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local items = {}
        local data = xPlayer.PlayerData.items
        for slot, item in pairs(data) do 
            local durability = item.info and item.info.quality or nil
            if durability == nil then
                durability = 100
            end
            items[#items + 1] = {
                slot = slot,
                name = item.name,
                label = item.label,
                count = item.amount,
                durability = durability,
                metadata = item.info or {},
                weight = item.weight
            }
        end
        return items
    end

    Inventory.UpdateInventory = function(source)
        SetTimeout(1000, function()
            TriggerClientEvent("pickle_businesses:updateInventory", source, Inventory.GetInventory(source))
        end)
    end

    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local ok=xPlayer.Functions.AddItem(name, count, nil, metadata)
        Inventory.UpdateInventory(source)
        return ok==true
    end

    Inventory.RemoveItem = function(source, name, count, slot)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local ok=xPlayer.Functions.RemoveItem(name, count, slot)
        Inventory.UpdateInventory(source)
        return ok==true
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        return Inventory.AddItem(source, name, count, metadata)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        return Inventory.RemoveItem(source, name, count, metadata)
    end

    Inventory.GetItemCount = function(source, name)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local item = xPlayer.Functions.GetItemByName(name)
        return item and item.amount or 0
    end

    Inventory.HasWeapon = function(source, name, count)
        return (Inventory.GetItemCount(source, name) > 0)
    end

    -- STASH FALLBACK
    
    Inventory.RegisterStash = function(id, label, coords)
    end

    RegisterCallback("pickle_businesses:getInventory", function(source, cb)
        cb(Inventory.GetInventory(source))
    end)

    for item, data in pairs(QBCore.Shared.Items) do
        Inventory.Items[item] = {label = data.label}
    end
    Inventory.Ready = true
end)