function GetHeadingFromCoords(coords, coords2)
    return GetHeadingFromVector_2d(coords.x - coords2.x, coords.y - coords2.y)
end

function OpenCraftingSubmenu(businessId, locationId, craftableId)
    local business = Businesses[businessId]
    local _, location = GetBusinessLocation(businessId, locationId)
    if not business or not location then return end
    local craftingData = GetCraftingData(business.zone, location.craftingType)
    if not craftingData then return end
    local craftableItem = craftingData.craftableItems[craftableId]
    if not craftableItem then return OpenCraftingMenu(businessId, locationId) end
    local options = {}
    options[#options + 1] = {
        title = _L("business_crafting_required") .. ":",
        description = _L("business_crafting_required_desc"),
    }
    for i=1, #craftableItem.required do
        local requiredItem = craftableItem.required[i]
        options[#options + 1] = {
            title = _L("business_crafting_required_item", GetItemLabel(requiredItem.name), requiredItem.count),
            description = requiredItem.description,
            icon = requiredItem.icon,
        }
    end
    options[#options + 1] = {
        title = _L("business_crafting_submit", GetItemLabel(craftableItem.name)),
        onSelect = function()
            lib.callback("pickle_businesses:startCrafting", "", function(result)
                if not result then return end
                CreateThread(function()
                    local craftStarted=GetGameTimer()
                    local action = craftableItem.action
                    local success = true
                    if action then
                        success = Config.Actions[action]({
                            businessId = businessId,
                            craftingItem = craftableItem,
                            coords = location.coords,
                            rotation = location.rotation
                        })
                    end
                    local remaining=(Config.Crafting.minimumDuration or 5)*1000-(GetGameTimer()-craftStarted)
                    if success and remaining>0 then Wait(remaining) end
                    TriggerServerEvent("pickle_businesses:finishCrafting", success)
                end)
            end, businessId, locationId, craftableId)
        end
    }
    lib.registerContext({
        id = 'pb_crafting_sub',
        title = GetItemLabel(craftableItem.name),
        onExit = function()
            lib.hideContext()
            SetTimeout(100, function()
                OpenCraftingMenu(businessId, locationId)
            end)
        end,
        -- canClose = false,
        options = options
    })
    lib.showContext('pb_crafting_sub')
end


function OpenCraftingMenu(businessId, locationId)
    local business = Businesses[businessId]
    local _, location = GetBusinessLocation(businessId, locationId)
    if not business or not location then return end
    local craftingData = GetCraftingData(business.zone, location.craftingType)
    if not craftingData then return end
    local options = {}
    for i=1, #craftingData.craftableItems do
        local item = craftingData.craftableItems[i]
        options[#options + 1] = {
            title = GetItemLabel(item.name),
            description = item.description,
            icon = item.icon,
            onSelect = function()
                lib.hideContext()
                SetTimeout(100, function()
                    OpenCraftingSubmenu(businessId, locationId, i)
                end)
            end
        }
    end
    lib.registerContext({
        id = 'pb_crafting_main',
        title = craftingData.label or _L("business_interact_crafting"),
        options = options
    })
    lib.showContext('pb_crafting_main')
end