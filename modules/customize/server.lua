function Customize_ValidateData(dataType, data)
    if dataType == "price" or dataType == "rent" then 
        if not data or not tonumber(data) or tonumber(data) < 0 then return false, _L("customize_sale_none") end
    elseif dataType == "zone" then 
        if not data then return false, _L("customize_zone_none") end
        local zoneIndex = GetBusinessZoneIndexByName(data)
        if not zoneIndex then return false, _L("customize_zone_none") end
    elseif dataType == "bounds" then 
        if not data or not type(data) == "table" then return false, _L("customize_bounds_none") end   
        for i=1, #data do
            if not data[i] or not type(data[i]) == "vector3" then return false, _L("customize_bounds_none") end
        end
    elseif dataType == "locations" then
        if not data or not type(data) == "table" or #data < 1 then return false, _L("customize_locations_none_set") end
        for i=1, #data do
            local location = data[i]
            if not location.id or not location.type or not location.coords then return false, _L("customize_location_unset") end
            if location.type == "crafting" then
                if not location.craftingType then return false, _L("customize_location_crafting_unset") end
            elseif location.type == "storage" then
                if not location.rank then return false, _L("customize_location_storage_unset") end
            end
        end
    end
    return true
end

function Customize_CreateBusiness(source, data)
    if not CanAdministrateBusinesses(source) then 
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not data or data.price == nil or data.rent == nil or data.zone == nil or data.bounds == nil or data.locations == nil then 
        print("^1ERROR: CUSTOMIZE CREATE BUSINESS^0", json.encode(data))
        return ShowNotification(source, "ERROR: NO DATA FIELDS FOR CERTAIN VALUES.")
    end
    local data = {
        price = data.price,
        rent = data.rent,
        zone = data.zone,
        bounds = data.bounds,
        locations = data.locations
    }
    for k,v in pairs(data) do 
        local success, reason = Customize_ValidateData(k, v)
        if not success then 
            ShowNotification(source, reason)
            return
        end
    end

    local businessData = {
        price = data.price or 0,
        rent = data.rent or 0,
        zone = data.zone,
        game_info = {
            placed = false,
            bounds = data.bounds,
            locations = data.locations
        },
    } 
    ShowNotification(source, _L("customize_business_created"))
    CreateBusiness(businessData)
end

function GetBusinessNextLocationId(businessId)
    local business = Businesses[businessId]
    if not business then return end
    local locations = business.game_info.locations
    if not locations then return 1 end
    local highestIndex = 0
    for i=1, #locations do
        if locations[i].id > highestIndex then
            highestIndex = locations[i].id
        end
    end
    return highestIndex + 1
end

function UpdateBusinessCustomizeSQL(businessId)
    local business = Businesses[businessId]
    if not business then return end
    MySQL.Async.execute("UPDATE pickle_businesses_locations SET zone = @zone, game_info = @game_info WHERE id = @id", {
        ["@zone"] = business.zone,
        ["@game_info"] = json.encode(business.game_info),
        ["@id"] = business.id
    }, function(rowsChanged)
    end)
end

lib.callback.register("pickle_businesses:customize:createBusiness", function(source, data)
    local source = source
    local businessId = Customize_CreateBusiness(source, data)
end)

lib.callback.register("pickle_businesses:customize:updateBusiness", function(source, businessId, data)
    local business = Businesses[businessId]
    if not business then return ShowNotification(source, _L("business_not_found")) end
    if not CanAdministrateBusinesses(source) and not IsPlayerBusinessOwner(source, businessId) then return ShowNotification(source, _L("no_permission")) end
    local zoneName = data.zone or business.zone
    local bounds = (#data.bounds >= 3 and data.bounds or business.game_info.bounds)
    if Businesses[businessId].zone ~= zoneName and Businesses[businessId].game_info.locations then
        local newLocations = {}
        for i=1, #Businesses[businessId].game_info.locations do
            local location = Businesses[businessId].game_info.locations[i]
            if location.type ~= "crafting" then
                newLocations[#newLocations + 1] = location
            elseif location.craftingType then
                local craftingData = GetCraftingData(zoneName, location.craftingType)
                if craftingData then
                    newLocations[#newLocations + 1] = location
                end
            end
        end
        Businesses[businessId].game_info.locations = newLocations
    end
    Businesses[businessId].zone = zoneName
    Businesses[businessId].game_info.bounds = bounds
    UpdateBusinessCustomizeSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateBusinessCustomize", -1, businessId, {zone = zoneName, bounds = bounds, locations = Businesses[businessId].game_info.locations})
end)

lib.callback.register("pickle_businesses:customize:updateLocation", function(source, businessId, locationData)
    local business = Businesses[businessId]
    if not business then return ShowNotification(source, _L("business_not_found")) end
    if not CanAdministrateBusinesses(source) and not IsPlayerBusinessOwner(source, businessId) then return ShowNotification(source, _L("no_permission")) end
    local index = (locationData.id and GetBusinessLocation(businessId, locationData.id) or nil)
    local id = locationData.id or GetBusinessNextLocationId(businessId)
    local updatedLocation
    if not index then -- New
        local location = {
            id = id,
            type = locationData.type,
            coords = locationData.coords,
            rotation = locationData.rotation,
            model = locationData.model,
        }
        if location.type == "crafting" then
            location.craftingType = locationData.craftingType
        elseif location.type == "storage" then 
            location.rank = locationData.rank
            location.storageId = GenerateBusinessStorageId(businessId, business.game_info.locations)
            Inventory.RegisterStash(location.storageId, _L("storage"), location.coords)
        end
        table.insert(Businesses[businessId].game_info.locations, location)
        updatedLocation = location
    else -- Update
        local location = business.game_info.locations[index]
        location.type = locationData.type
        location.coords = locationData.coords
        location.rotation = locationData.rotation
        location.model = locationData.model
        if location.type == "crafting" then
            location.craftingType = locationData.craftingType
        elseif location.type == "storage" then
            location.rank = locationData.rank
            location.storageId=location.storageId or GenerateBusinessStorageId(businessId,business.game_info.locations)
            Inventory.RegisterStash(location.storageId,_L("storage"),location.coords)
        end
        Businesses[businessId].game_info.locations[index] = location
        updatedLocation = location
    end
    UpdateGameInfoSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateLocation", -1, businessId, id, updatedLocation)
    return {locations = Businesses[businessId].game_info.locations}
end)

lib.callback.register("pickle_businesses:customize:deleteLocation", function(source, businessId, locationId)
    local business = Businesses[businessId]
    if not business then return ShowNotification(source, _L("business_not_found")) end
    if not CanAdministrateBusinesses(source) and not IsPlayerBusinessOwner(source, businessId) then return ShowNotification(source, _L("no_permission")) end
    local index = (locationId and GetBusinessLocation(businessId, locationId) or nil)
    if not index then return ShowNotification(source, _L("business_location_not_found")) end
    local managementCount = 0
    for i=1, #business.game_info.locations do
        if business.game_info.locations[i].type == "management" then
            managementCount = managementCount + 1
        end
    end
    if business.game_info.locations[index].type == "management" and managementCount <= 1 then
        return ShowNotification(source, _L("customize_locations_none_set"))
    end
    table.remove(Businesses[businessId].game_info.locations, index)
    UpdateGameInfoSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateLocation", -1, businessId, locationId)
    return {locations = Businesses[businessId].game_info.locations}
end)

RegisterCommand("createbusiness", function(source, args, raw)
    if not CanAdministrateBusinesses(source) then return ShowNotification(source, _L("no_permission")) end
    TriggerClientEvent("pickle_businesses:customize:createBusiness", source)
end)