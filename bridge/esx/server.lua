if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

function RegisterCallback(name, cb)
    ESX.RegisterServerCallback(name, cb)
end

function RegisterUsableItem(...)
    ESX.RegisterUsableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier
end

function GetSourceFromIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source or nil
end

function GetPaymentMethodAmount(src,method)
    local p=ESX.GetPlayerFromId(src); if not p then return 0 end
    if method=='cash' then return p.getMoney() end
    local account=p.getAccount(method=='card' and 'bank' or 'black_money')
    return account and account.money or 0
end
function ChargePaymentMethod(src,method,amount)
    local p=ESX.GetPlayerFromId(src)
    if not p or not BusinessInt(amount,0,2147483647) then return false end
    local before=GetPaymentMethodAmount(src,method); if before<amount then return false end
    if method=='cash' then p.removeMoney(amount) else p.removeAccountMoney(method=='card' and 'bank' or 'black_money',amount) end
    return GetPaymentMethodAmount(src,method)==before-amount
end
function AddPaymentMethodAmount(src,method,amount)
    local p=ESX.GetPlayerFromId(src)
    if not p or not BusinessInt(amount,0,2147483647) then return false end
    local before=GetPaymentMethodAmount(src,method)
    if method=='cash' then p.addMoney(amount) else p.addAccountMoney(method=='card' and 'bank' or 'black_money',amount) end
    return GetPaymentMethodAmount(src,method)==before+amount
end

function GetPlayerCharacterName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer.getName()
end

function CanAdministrateBusinesses(source)
    return CheckPermission(source, Config.BusinessAdministration)
end

function CheckPermission(source, permission)
    local xPlayer = ESX.GetPlayerFromId(source)
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade
    local group = xPlayer.getGroup()
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if group == permission.groups[i] then 
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
        local xPlayer = ESX.GetPlayerFromId(source)
        if Config.InventoryLimit then 
            local item = xPlayer.getInventoryItem(name)
            return (item.limit >= item.count + count)
        else 
            return xPlayer.canCarryItem(name, count)
        end
    end

    Inventory.GetInventory = function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        local items = {}
        local data = xPlayer.getInventory()
        for i=1, #data do 
            local item = data[i]
            local durability = 100
            items[#items + 1] = {
                slot = nil,
                name = item.name,
                label = item.label,
                count = item.count,
                durability = durability,
                metadata = nil,
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
        local xPlayer = ESX.GetPlayerFromId(source)
        local before=Inventory.GetItemCount(source,name)
        xPlayer.addInventoryItem(name, count)
        Inventory.UpdateInventory(source)
        return Inventory.GetItemCount(source,name)==before + count
    end

    Inventory.RemoveItem = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        local before=Inventory.GetItemCount(source,name)
        xPlayer.removeInventoryItem(name, count)
        Inventory.UpdateInventory(source)
        return Inventory.GetItemCount(source,name)==before - count
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.addWeapon(name, 0)
        Inventory.UpdateInventory(source)
        return xPlayer.hasWeapon(name)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.removeWeapon(name, 0)
        Inventory.UpdateInventory(source)
        return not xPlayer.hasWeapon(name)
    end

    Inventory.GetItemCount = function(source, name)
        local xPlayer = ESX.GetPlayerFromId(source)
        local item = xPlayer.getInventoryItem(name)
        return item and item.count or 0
    end

    Inventory.HasWeapon = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer.hasWeapon(name)
    end

    -- STASH FALLBACK

    Inventory.RegisterStash = function(id, label, coords)
    end

    MySQL.ready(function() 
        MySQL.Async.fetchAll("SELECT * FROM items;", {}, function(results) 
            for i=1, #results do 
                Inventory.Items[results[i].name] = {label = results[i].label}
            end
            Inventory.Ready = true
        end)
    end)
end)