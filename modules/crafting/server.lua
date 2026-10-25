local CraftingPlayers = {}

function CheckRequired(source, required)
    if not required or #required < 1 then return true end
    local success = true
    local missingItems = {}
    for i=1, #required do 
        local part = required[i]
        if (not part.type or part.type == "item") then
            local remaining = Inventory.GetItemCount(source, part.name) - (part.count)
            if remaining < 0 then 
                success = false
                missingItems[#missingItems + 1] = {index = i, name = part.name, count = remaining * -1}
            end
        elseif (part.type == "cash") then
            local remaining = GetMoney(source) - part.count
            if remaining < 0 then 
                success = false
                missingItems[#missingItems + 1] = {index = i, name = "cash", count = remaining * -1}
            end
        elseif (part.type == "weapon" and not Inventory.HasWeapon(source, part.name)) then
            success = false
            missingItems[#missingItems + 1] = {index = i, name = part.name, count = 1}
        end
    end
    return success, missingItems
end

function TakeRequired(src,required)
    local taken={}
    for _,p in ipairs(required or {}) do
        local take=p.type=='weapon' and Inventory.RemoveWeapon or p.type=='cash' and function(src,_,n) return ChargePaymentMethod(src,'cash',n) end or Inventory.RemoveItem
        local give=p.type=='weapon' and Inventory.AddWeapon or p.type=='cash' and function(src,_,n) return AddPaymentMethodAmount(src,'cash',n) end or Inventory.AddItem
        local count=p.type=='weapon' and 1 or p.count
        if take(src,p.name,count)~=true then for _,r in ipairs(taken) do r.give(src,r.name,r.count) end; return false end
        taken[#taken+1]={give=give,name=p.name,count=count}
    end
    return true
end
function GiveRewards(src,rewards,craftingData)
    for _,r in ipairs(rewards) do
        local give=r.type=='weapon' and Inventory.AddWeapon or r.type=='cash' and function(src,_,n) return AddPaymentMethodAmount(src,'cash',n) end or Inventory.AddItem
        if give(src,r.name,r.count,r.createItem and r.createItem(craftingData) or nil)~=true then return false end
    end
    return true
end

function IsCraftingInProgress(businessId, locationId)
    for k,v in pairs(CraftingPlayers) do 
        if v.businessId == businessId and v.locationId == locationId then 
            return true
        end
    end
    return false
end

lib.callback.register("pickle_businesses:isCraftingActive", function(source, businessId, locationId)
    return IsCraftingInProgress(businessId, locationId)
end)

lib.callback.register("pickle_businesses:startCrafting", function(source, businessId, locationId, craftableId)
    local source = source
    local craftingPlayer = CraftingPlayers[source]
    if craftingPlayer then 
        return ShowNotification(source, _L("business_crafting_already"))
    end
    if IsCraftingInProgress(businessId, locationId) then 
        return ShowNotification(source, _L("business_crafting_occupied"))
    end
    local business = Businesses[businessId]
    local _, location = GetBusinessLocation(businessId, locationId)
    if not business or not location then return ShowNotification(source, _L("business_not_found")) end
    local employee = GetBusinessEmployee(source, businessId)
    if not employee then return false end
    local craftingData = GetCraftingData(business.zone, location.craftingType)
    if not craftingData then return ShowNotification(source, _L("business_crafting_not_found")) end
    local craftableItem = craftingData.craftableItems[craftableId]
    if not craftableItem then return ShowNotification(source, _L("business_crafting_item_not_found")) end
    local success, missingItems = CheckRequired(source, craftableItem.required)
    if not success then 
        for i=1, #missingItems do 
            local item = missingItems[i]
            ShowNotification(source, _L("business_crafting_missing_item", GetItemLabel(item.name), item.count))
        end
        return
    end
    if not BusinessNear(source,businessId,20) then return false end
    local startTime = os.time()
    CraftingPlayers[source] = {
        startTime = startTime,
        owner=GetIdentifier(source),
        businessId = businessId,
        locationId = locationId,
        craftableId = craftableId
    }
    SetTimeout(1000 * Config.Crafting.timeoutTime, function()
        local craftingPlayer = CraftingPlayers[source]
        if not craftingPlayer then return end
        if startTime == craftingPlayer.startTime then 
            CraftingPlayers[source] = nil
        end
    end)
    return true
end)

RegisterNetEvent("pickle_businesses:finishCrafting", function(success)
    local source = source
    local craftingPlayer = CraftingPlayers[source]
    if not craftingPlayer or not success then 
        CraftingPlayers[source] = nil
        return ShowNotification(source, _L("business_crafting_failed"))
    end
    local businessId = craftingPlayer.businessId
    local locationId = craftingPlayer.locationId
    local craftableId = craftingPlayer.craftableId
    local business = Businesses[businessId]
    local _, location = GetBusinessLocation(businessId, locationId)
    if not business or not location then return ShowNotification(source, _L("business_not_found")) end
    local employee = GetBusinessEmployee(source, businessId)
    if not employee then return false end
    local craftingData = GetCraftingData(business.zone, location.craftingType)
    if not craftingData then return ShowNotification(source, _L("business_crafting_not_found")) end
    local craftableItem = craftingData.craftableItems[craftableId]
    if not craftableItem then return ShowNotification(source, _L("business_crafting_item_not_found")) end
    if craftingPlayer.owner~=GetIdentifier(source) or os.time()-craftingPlayer.startTime<(Config.Crafting.minimumDuration or 5)
        or not BusinessNear(source,businessId,20) or not CheckRequired(source,craftableItem.required) then return end
    CraftingPlayers[source]=nil
    if not TakeRequired(source,craftableItem.required) then return end
    if not GiveRewards(source, {
        {type = "item", name = craftableItem.name, count = craftableItem.count},
    },craftingPlayer) then
        for _,part in ipairs(craftableItem.required or {}) do
            if part.type=='cash' then AddPaymentMethodAmount(source,'cash',part.count)
            elseif part.type=='weapon' then Inventory.AddWeapon(source,part.name,1)
            else Inventory.AddItem(source,part.name,part.count) end
        end
        return
    end
    CraftingPlayers[source] = nil
    ShowNotification(source, _L("business_crafting_success"))
end)
AddEventHandler("playerDropped",function() CraftingPlayers[source]=nil end)
