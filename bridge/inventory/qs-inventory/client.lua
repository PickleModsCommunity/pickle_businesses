if GetResourceState('qs-inventory') ~= 'started' then return end

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

function InitializeInventory()
end