Businesses = {}
LocalBusinessLocations = {}
LocalBusinessStatus = {}
identifier = ""
isAdmin = false

function GetBusinessEmployee(businessId)
    local business = Businesses[businessId]
    if not business then return end
    if isAdmin then return true end
    if business.owner and identifier == business.owner then return business.employees[identifier] end
    return business.employees[identifier]
end

function CheckPermissionLevel(businessId, rankIndex)
    local business = Businesses[businessId]
    if not business then return false end
    if isAdmin then return true end
    local employee = GetBusinessEmployee(businessId)
    if not employee then return false end
    local roleId = employee.roleId
    rankIndex=tonumber(rankIndex) or #business.roles
    if rankIndex > #business.roles then 
        rankIndex = #business.roles
    end
    for i=1, #business.roles do
        if business.roles[i].id == roleId then
            return true
        elseif rankIndex == i then
            return false
        end
    end
end

function RefreshInventory(data)
end

function ClearBusinessLocations(businessId)
    if not LocalBusinessLocations[businessId] then 
        LocalBusinessLocations[businessId] = {}
        return
    end
    for i=1, #LocalBusinessLocations[businessId] do
        if LocalBusinessLocations[businessId][i].interact then
            DeleteInteraction(LocalBusinessLocations[businessId][i].interact)
        elseif LocalBusinessLocations[businessId][i].object then
            DeleteEntity(LocalBusinessLocations[businessId][i].object)
        end
    end
    LocalBusinessLocations[businessId] = {}
end

function DisplayBusinessLocations(businessId)
    local business = Businesses[businessId]
    if not business then return end
    local locations = business.game_info.locations
    if not locations or #locations == 0 then return print("^1LOCATIONS UNSET FOR BUSINESS ID:^0 ", businessId) end
    ClearBusinessLocations(businessId)
    if not CanDisplayBusinessLocations(businessId) then return end
    if business.game_info.placed then return DisplayMarketLocations(businessId) end
    local canInteract = {
        management = true,
        crafting = false,
        storage = false,
        billing = false,
        market = false,
    }
    local employee = GetBusinessEmployee(businessId)
    if business.owner then
        if employee then
            canInteract.crafting = true
            canInteract.storage = true
            canInteract.billing = true
        else
            canInteract.management = false
        end
        canInteract.market = true
    end
    for i=1, #locations do
        local location = locations[i]
        LocalBusinessLocations[businessId][i] = {
            id = location.id,
            coords = location.coords,
            rotation = location.rotation,
            model = location.model,
            type = location.type,
        }
        if canInteract[location.type] then
            local label
            if location.type == "crafting" then
                local craftingData = GetCraftingData(business.zone, location.craftingType)
                if not craftingData then return print("^1CRAFTING DATA UNSET FOR BUSINESS ID:^0 ", businessId, "^1CRAFTING TYPE:^0 ", craftingType) end
                label = craftingData.label or _L("business_interact_crafting") 
            else
                label = _L("business_interact_" .. location.type)
            end            
            if not business.owner then
                label = _L("business_interact_purchase")
            end
            LocalBusinessLocations[businessId][i].interact = CreateInteraction({
                coords = vector3(location.coords.x, location.coords.y, location.coords.z),
                heading = location.rotation.z,
                label = label,
                model = location.model and {hash = location.model, modelType = "prop"} or nil,
            }, function()
                if business.owner then
                    if location.type == "management" then
                        CustomizeBusinessMenu(businessId)
                    elseif location.type == "crafting" then
                        lib.callback("pickle_businesses:isCraftingActive", "", function(result) 
                            if result then
                                return ShowNotification(_L("business_crafting_occupied"))
                            end
                            OpenCraftingMenu(businessId, location.id)
                        end, businessId, location.id)
                    elseif location.type == "storage" then
                        if not CheckPermissionLevel(businessId, location.rank) then
                            return ShowNotification(_L("business_storage_no_permission"))
                        end
                        Inventory.OpenStash(location.storageId)
                    elseif location.type == "billing" then
                        OpenBillingMenu(businessId, location.id)
                    elseif location.type == "market" then
                        OpenBusinessStore(businessId)
                    end
                else
                    if location.type == "management" then
                        BusinessPurchaseMenu(businessId)
                    end
                end
            end)
        elseif location.model then
            LocalBusinessLocations[businessId][i].interact = CreateInteraction({
                noInteract = true,
                coords = vector3(location.coords.x, location.coords.y, location.coords.z),
                heading = location.rotation.z,
                label = label,
                model = location.model and {hash = location.model, modelType = "prop"} or nil,
            })
        end
    end
end

function ToggleBusinessLocations(businessId, toggle)
    if not Businesses[businessId] then return end
    if not LocalBusinessStatus[businessId] then LocalBusinessStatus[businessId] = {} end
    LocalBusinessStatus[businessId].showLocations = toggle
    if toggle then
        DisplayBusinessLocations(businessId)
    else
        ClearBusinessLocations(businessId)
    end
end

function CanDisplayBusinessLocations(businessId)
    return (not LocalBusinessStatus[businessId] or LocalBusinessStatus[businessId].showLocations)
end

function BusinessPurchaseConfirmMenu(businessId, optionType)
    local business = Businesses[businessId]
    if business.owner then return ShowNotification(_L("business_already_owned")) end
    local result = lib.alertDialog({
        header = _L("business_owner_confirm_"..optionType, NumberWithCommas(business[optionType == "purchase" and "price" or "rent"])),
        centered = true,
        cancel = true
    })
    if result == "confirm" then
        TriggerServerEvent("pickle_businesses:purchaseBusiness", businessId, optionType)
    else
        ShowNotification(_L("business_purchase_cancelled"))
    end
end

function BusinessPurchaseMenu(businessId)
    local business = Businesses[businessId]
    if business.owner then return ShowNotification(_L("business_already_owned")) end
    local price = business.price > 0 and business.price or nil 
    local rent = business.rent > 0 and business.rent or nil 
    local zoneName = business.zone
    local zoneIndex, zone = GetBusinessZoneIndexByName(zoneName)
    local options = {}
    options[#options + 1] = {pbOptionType = "zone", label = _L("customize_zone"), icon = "dollar", values = { _L("customize_zone_value", zone.label) }, close = false }
    options[#options + 1] = {pbOptionType = "purchase", label = _L("customize_purchase"), icon = "dollar", values = { (price and _L("money_number", price) or _L("not_available")) }, close = (price ~= nil and true or false) }
    options[#options + 1] = {pbOptionType = "rent", label = _L("customize_rent"), icon = "dollar", values = { (rent and _L("money_number", rent) or _L("not_available")) }, close = (rent ~= nil and true or false) }
    lib.registerMenu({
        id = 'pb_purchase_menu',
        title = _L("business_interact_purchase"),
        position = Config.MenuPosition,
        options = options
    }, function(selected, scrollIndex, args)
        if options[selected].pbOptionType == "purchase" or options[selected].pbOptionType == "rent" then
            if options[selected].pbOptionType == "purchase" then
                if not price then return end
            else
                if not rent then return end
            end
            BusinessPurchaseConfirmMenu(businessId, options[selected].pbOptionType)
        end
    end)
    lib.showMenu('pb_purchase_menu')
end

function CustomizeBusinessMenu(businessId)
    local business = Businesses[businessId]
    ToggleBusinessLocations(businessId, false)
    ClearBusinessLocations(businessId)
    Customize_OpenBusinessMenu({
        admin = isAdmin,
        -- price = business.price,
        -- rent = business.rent,
        businessId = businessId,
        owner = business.owner,
        label = business.label,
        zone = business.zone,
        bounds = business.game_info.bounds,
        locations = business.game_info.locations
    }, function()
        ToggleBusinessLocations(businessId, true)
    end)
end

RegisterNetEvent("pickle_businesses:setIdentifier", function(_identifier, _isAdmin) 
    identifier = _identifier
    isAdmin = _isAdmin
    for k,v in pairs(Businesses) do
        DisplayBusinessLocations(k)
    end
end)

RegisterNetEvent("pickle_businesses:updateBusiness", function(index, data) 
    if index then
        Businesses[index] = data
        if not data then 
            return ClearBusinessLocations(index)
        end
        DisplayBusinessLocations(index)
    else
        Businesses = data
        for k,v in pairs(Businesses) do
            DisplayBusinessLocations(k)
        end
    end
end)

RegisterNetEvent("pickle_businesses:updateBusinessOwner", function(businessId, data)
    if not Businesses[businessId] then return end
    Businesses[businessId].owner = data.owner
    Businesses[businessId].roles = data.roles
    Businesses[businessId].employees = data.employees
    Businesses[businessId].renting = data.renting
    DisplayBusinessLocations(businessId)
end)

RegisterNetEvent("pickle_businesses:updateBusinessCustomize", function(businessId, data)
    if not Businesses[businessId] then return end
    Businesses[businessId].zone = data.zone
    Businesses[businessId].game_info.bounds = data.bounds
    Businesses[businessId].game_info.locations = data.locations
    DisplayBusinessLocations(businessId)
end)

RegisterNetEvent("pickle_businesses:updateLocation", function(businessId, locationId, data)
    if not Businesses[businessId] or not Businesses[businessId].game_info?.locations then return end
    local added = false
    for i=1, #Businesses[businessId].game_info.locations do
        if Businesses[businessId].game_info.locations[i].id == locationId then
            if data then
                added = true
                Businesses[businessId].game_info.locations[i] = data
            else
                table.remove(Businesses[businessId].game_info.locations, i)
            end
            break
        end
    end
    if data and not added then
        table.insert(Businesses[businessId].game_info.locations, data)
    end
    DisplayBusinessLocations(businessId)
end)
lib.callback.register('pickle_businesses:acceptOwnership',function(label)
    return lib.alertDialog({header='Business transfer',content='Accept ownership of '..tostring(label)..'?',cancel=true})=='confirm'
end)
