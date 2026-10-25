Businesses = {}

function SafeCharacters(text, charLimit)
    if not text then return "INVALID STRING" end
    if type(text) ~= "string" then return "INVALID STRING" end
    if #text > charLimit - 1 then
        return text:sub(1, charLimit)
    end
    return text
end

function CreateBusiness(businessData, source)
    local businessData = {
        owner = businessData.owner or nil,
        label = businessData.label or "Untitled Business",
        price = businessData.price or 0,
        rent = businessData.rent or 0,
        money = businessData.money or 0,
        dirty_money = businessData.dirty_money or 0,
        zone = businessData.zone,
        game_info = {
            placed = businessData.game_info.placed,
            bounds = businessData.game_info.bounds,
            locations = businessData.game_info.locations
        },
        store_listings = businessData.store_listings or {},
        trade_listings = businessData.trade_listings or {},
        trade_inventory = businessData.trade_inventory or {},
        daily_sales = businessData.daily_sales or {},
        recent_sales = businessData.recent_sales or {},
        recent_trades = businessData.recent_trades or {},
        employees = businessData.employees or {},
        roles = businessData.roles or {},
    } 
    BusinessSQLInsert("INSERT INTO pickle_businesses_locations (owner, label, price, rent, money, dirty_money, zone, game_info, store_listings, trade_listings, trade_inventory, daily_sales, recent_sales, recent_trades, employees, roles) VALUES (@owner, @label, @price, @rent, @money, @dirty_money, @zone, @game_info, @store_listings, @trade_listings, @trade_inventory, @daily_sales, @recent_sales, @recent_trades, @employees, @roles);", {
        ["@owner"] = businessData.owner,
        ["@label"] = SafeCharacters(businessData.label, 255),
        ["@price"] = businessData.price,
        ["@rent"] = businessData.rent,
        ["@money"] = businessData.money,
        ["@dirty_money"] = businessData.dirty_money,
        ["@zone"] = businessData.zone,
        ["@game_info"] = json.encode(businessData.game_info),
        ["@store_listings"] = json.encode(businessData.store_listings),
        ["@trade_listings"] = json.encode(businessData.trade_listings),
        ["@trade_inventory"] = json.encode(businessData.trade_inventory),
        ["@daily_sales"] = json.encode(businessData.daily_sales),
        ["@recent_sales"] = json.encode(businessData.recent_sales),
        ["@recent_trades"] = json.encode(businessData.recent_trades),
        ["@employees"] = json.encode(businessData.employees),
        ["@roles"] = json.encode(businessData.roles)
    }, function(id)
        businessData.id = id
        local locations = businessData.game_info.locations
        if locations then
            for i=1, #locations do 
                if locations[i].type == "storage" then
                    locations[i].storageId = GenerateBusinessStorageId("business_"..id, locations)
                end
            end
            businessData.game_info.locations = locations
            BusinessSQLExecute("UPDATE pickle_businesses_locations SET game_info = @game_info WHERE id = @id;", {
                ["@game_info"] = json.encode(businessData.game_info),
                ["@id"] = id
            }, function(rowsChanged)
            end)
        end
        if source then
            InitializeBusiness(businessData, true)
            ResetBusinessOwner("business_"..businessData.id, source)
            UpdateStoreWipeSQL("business_"..businessData.id)
            TriggerClientEvent("pickle_businesses:updateBusiness", -1, "business_"..businessData.id, Businesses["business_"..businessData.id])
        else
            InitializeBusiness(businessData)
        end
    end)
end

function InitializeBusiness(data, dontSync)
    local index = "business_"..data.id
    Businesses[index] = {
        id = data.id,
        owner = data.owner or nil,
        label = data.label or "Untitled Business",
        renting = data.renting,
        zone = data.zone or nil,
        price = data.price or 0,
        rent = data.rent or 0,
        money = data.money or 0,
        dirty_money = data.dirty_money or 0,
        game_info = data.game_info or {},
        store_listings = data.store_listings or {},
        trade_listings = data.trade_listings or {},
        trade_inventory = data.trade_inventory or {},
        daily_sales = data.daily_sales or {},
        recent_sales = data.recent_sales or {},
        recent_trades = data.recent_trades or {},
        employees = data.employees or {},
        roles = data.roles or {},
    }
    local oIndex, oRole
    for i=1, #Businesses[index].roles do
        if Businesses[index].roles[i].owner then
            oIndex = i
            oRole = Businesses[index].roles[i]
            break
        end
    end
    if oIndex and data.owner then
        local ownerFound = false
        for k,v in pairs(Businesses[index].employees) do
            if v.roleId == oRole.id then
                ownerFound = true
                break
            end
        end
        if not ownerFound then
            Businesses[index].employees[data.owner] = {
                name = "Anonymous Owner",
                roleId = oRole.id,
                pendingMoney = 0
            }
            UpdateStoreEmployeesSQL(index)
        end
    end
    RegisterBusinessStashes(Businesses[index].game_info.locations or {})
    if dontSync then return end
    TriggerClientEvent("pickle_businesses:updateBusiness", -1, index, Businesses[index])
end

function RegisterBusinessStashes(locations)
    for _, location in ipairs(locations) do
        if location.storageId then
            print("Registering stash: ", location.storageId)
            Inventory.RegisterStash(location.storageId, _L("storage"), location.coords)
        end
    end
end

function GetBusinessEmployees(businessId)
    if not Businesses[businessId] then return end
    local employees = {}
    for identifier, employee in pairs(Businesses[businessId].employees) do
        local employee = {
            identifier = identifier,
            name = employee.name,
            roleId = employee.roleId,
            pendingMoney = employee.pendingMoney
        }
        local source = GetSourceFromIdentifier(employee.identifier)
        if source then
            employee.source = source
        end
        local _, role = GetStoreRoleById(businessId, employee.roleId)
        table.insert(employees, employee)
    end
    return employees
end

function GetBusinessEmployee(target, businessId)
    if not Businesses[businessId] then return end
    if not target then return end
    local employees = GetBusinessEmployees(businessId)
    local identifier = target
    if type(target) == "number" then
        identifier = GetIdentifier(target)
    end
    for _, employee in ipairs(employees) do
        if employee.identifier == identifier then
            return employee
        end
    end
end

function GenerateBusinessStorageId(businessId, locations)
    local id = "pb_" .. businessId .. "_storage_".. math.random(1, 999999)
    for i=1, #locations do
        if locations[i].storageId and locations[i].storageId == id then
            return GenerateBusinessStorageId(businessId, locations)
        end
    end
    return id
end

function GenerateStoreRoleId(businessId)
    local id = "role_" .. math.random(1, 999999)
    for _, role in ipairs(Businesses[businessId].roles) do
        if role.id == id then
            return GenerateStoreRoleId(businessId)
        end
    end
    return id
end

function GenerateRandomSku(businessId)
    local sku = "sku_" .. math.random(1, 999999)
    for _, listing in ipairs(Businesses[businessId].store_listings) do
        if listing.sku == sku then
            return GenerateRandomSku(businessId)
        end
    end
    return sku
end

function GenerateRandomTradeSku(businessId) 
    local sku = "sku_" .. math.random(1, 999999)
    for _, tradeListing in ipairs(Businesses[businessId].trade_listings) do
        if tradeListing.sku == sku then
            return GenerateRandomTradeSku(businessId)
        end
    end
    return sku
end

function GenerateStoreTradeInventorySku(businessId)
    local sku = "sku_" .. math.random(1, 999999)
    for _, tradeItem in ipairs(Businesses[businessId].trade_inventory) do
        if tradeItem.sku == sku then
            return GenerateStoreTradeInventorySku(businessId)
        end
    end
    return sku
end

function GetStoreListingBySku(businessId, sku)
    for index, listing in ipairs(Businesses[businessId].store_listings) do
        if listing.sku == sku then
            return index, listing
        end
    end
    return nil
end

function GetStoreTradeInventoryBySku(businessId, sku)
    for index, tradeItem in ipairs(Businesses[businessId].trade_inventory) do
        if tradeItem.sku == sku then
            return index, tradeItem
        end
    end
    return nil
end

function GetStoreTradeListingBySku(businessId, sku)
    for index, tradeItem in ipairs(Businesses[businessId].trade_listings) do
        if tradeItem.sku == sku then
            return index, tradeItem
        end
    end
    return nil
end

function GetStoreRoleById(businessId, roleId)
    for index, role in ipairs(Businesses[businessId].roles) do
        if role.id == roleId then
            return index, role
        end
    end
    return nil
end

function IsPlayerBusinessOwner(source, businessId)
    if not Businesses[businessId] then return false end
    if not Businesses[businessId].owner then return false end
    return Businesses[businessId].owner == GetIdentifier(source)
end

function DoesPlayerHaveStorePermission(source, businessId, permission)
    if CanAdministrateBusinesses(source) then return true end
    local employee = GetBusinessEmployee(source, businessId)
    if not employee then return false end
    local index, role = GetStoreRoleById(businessId, employee.roleId)
    if not role then return false end
    if role.owner then return true end
    if permission == "owner" then return false end
    return role.permissions and role.permissions[permission] or false
end

function SendCustomInformationPacket(source, data)
    TriggerClientEvent("pickle_businesses:customInformation", source, data)
end

function AddStoreListing(businessId, data) 
    Businesses[businessId].store_listings[#Businesses[businessId].store_listings + 1] = {
        name = data.name,
        metadata = data.metadata or {},
        price = data.price,
        quantity = data.quantity,
        sku = GenerateRandomSku(businessId)
    }
    -- Update the column in MySQL
    UpdateStoreListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateListings", -1, businessId, Businesses[businessId].store_listings)
end

function EditStoreListing(businessId, sku, price, quantity) 
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then return end
    if quantity <= 0 then
        return RemoveStoreListing(businessId, sku)
    end
    Businesses[businessId].store_listings[index].price = price
    Businesses[businessId].store_listings[index].quantity = quantity
    -- Update the column in MySQL
    UpdateStoreListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateListings", -1, businessId, Businesses[businessId].store_listings)
end

function RemoveStoreListing(businessId, sku, price, quantity) 
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then return end
    table.remove(Businesses[businessId].store_listings, index)
    -- Update the column in MySQL
    UpdateStoreListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateListings", -1, businessId, Businesses[businessId].store_listings)
end

function AddStoreTradeInventory(businessId, data) 
    local updated = false
    for i=1, #Businesses[businessId].trade_inventory do
        if Businesses[businessId].trade_inventory[i].name == data.name then
            Businesses[businessId].trade_inventory[i].quantity = Businesses[businessId].trade_inventory[i].quantity + data.quantity
            updated = true
            break
        end
    end
    if not updated then
        Businesses[businessId].trade_inventory[#Businesses[businessId].trade_inventory + 1] = {
            name = data.name,
            metadata = data.metadata or {},
            price = data.price,
            quantity = data.quantity,
            sku = GenerateStoreTradeInventorySku(businessId)
        }
    end
    -- Update the column in MySQL
    UpdateStoreTradeInventorySQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeInventory", -1, businessId, Businesses[businessId].trade_inventory)
end

function EditStoreTradeInventory(businessId, sku, quantity) 
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then return end
    if quantity <= 0 then
        return RemoveStoreTradeInventory(businessId, sku)
    end
    Businesses[businessId].trade_inventory[index].quantity = quantity
    -- Update the column in MySQL
    UpdateStoreTradeInventorySQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeInventory", -1, businessId, Businesses[businessId].trade_inventory)
end

function RemoveStoreTradeInventory(businessId, sku, quantity) 
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then return end
    table.remove(Businesses[businessId].trade_inventory, index)
    -- Update the column in MySQL
    UpdateStoreTradeInventorySQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeInventory", -1, businessId, Businesses[businessId].trade_inventory)
end

function RemoveStoreTradeInventoryQuantity(businessId, itemName, quantity)
    local quantityLeft = quantity
    for index, tradeItem in ipairs(Businesses[businessId].trade_inventory) do
        if tradeItem.name == itemName then
            if tradeItem.quantity >= quantityLeft then
                Businesses[businessId].trade_inventory[index].quantity = Businesses[businessId].trade_inventory[index].quantity - quantityLeft
                if Businesses[businessId].trade_inventory[index].quantity <= 0 then
                    table.remove(Businesses[businessId].trade_inventory, index)
                end
                quantityLeft = 0
                break
            else
                quantityLeft = quantityLeft - Businesses[businessId].trade_inventory[index].quantity
                table.remove(Businesses[businessId].trade_inventory, index)
            end
        end
    end
    -- Update the column in MySQL
    UpdateStoreTradeInventorySQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeInventory", -1, businessId, Businesses[businessId].trade_inventory)
end

function GetStoreTradeInventoryItemCount(businessId, itemName)
    local count = 0
    for _, tradeItem in ipairs(Businesses[businessId].trade_inventory) do
        if tradeItem.name == itemName then
            count = count + tradeItem.quantity
        end
    end
    return count
end

function UpdateStoreFunds(businessId, paymentMethod)
    if paymentMethod == "cash" or paymentMethod == "card" then
        -- Update the column in MySQL
        BusinessSQLExecute("UPDATE pickle_businesses_locations SET money = @amount WHERE id = @id;", {
            ["@amount"] = Businesses[businessId].money,
            ["@id"] = Businesses[businessId].id
        }, function(rowsChanged)
        end)
    elseif paymentMethod == "dirtycash" then
        -- Update the column in MySQL
        BusinessSQLExecute("UPDATE pickle_businesses_locations SET dirty_money = @amount WHERE id = @id;", {
            ["@amount"] = Businesses[businessId].dirty_money,
            ["@id"] = Businesses[businessId].id
        }, function(rowsChanged)
        end)
    else
        return
    end
end

function AddStoreFunds(businessId, paymentMethod, amount)
    if amount <= 0 then return end
    local balanceKey = nil
    local newBalance = 0
    if not BusinessInt(amount,1,2147483647) then return false end
    if paymentMethod == "cash" or paymentMethod == "card" then
        Businesses[businessId].money = Businesses[businessId].money + amount
        newBalance = Businesses[businessId].money
        balanceKey = "money"
    elseif paymentMethod == "dirtycash" then
        Businesses[businessId].dirty_money = Businesses[businessId].dirty_money + amount
        newBalance = Businesses[businessId].dirty_money
        balanceKey = "dirty_money"
    else
        return
    end
    UpdateStoreFunds(businessId, paymentMethod)
    TriggerClientEvent("pickle_businesses:updateBusinessBalance", -1, businessId, balanceKey, newBalance)
end

function RemoveStoreFunds(businessId, paymentMethod, amount)
    if amount <= 0 then return end
    local balanceKey = nil
    local newBalance = 0
    if not BusinessInt(amount,1,2147483647) then return false end
    if paymentMethod == "cash" or paymentMethod == "card" then
        Businesses[businessId].money = Businesses[businessId].money - amount
        newBalance = Businesses[businessId].money
        balanceKey = "money"
    elseif paymentMethod == "dirtycash" then
        Businesses[businessId].dirty_money = Businesses[businessId].dirty_money - amount
        newBalance = Businesses[businessId].dirty_money
        balanceKey = "dirty_money"
    else
        return
    end
    UpdateStoreFunds(businessId, paymentMethod)
    TriggerClientEvent("pickle_businesses:updateBusinessBalance", -1, businessId, balanceKey, newBalance)
end

function GetStoreFunds(businessId, paymentMethod)
    if paymentMethod == "cash" or paymentMethod == "card" then
        return Businesses[businessId].money
    elseif paymentMethod == "dirtycash" then
        return Businesses[businessId].dirty_money
    else
        return 0
    end
end

function UpdateDailySales(businessId, amount)
    local date = GetDate()
    local currentDayIndex = #Businesses[businessId].daily_sales
    -- table.remove(dailySales, 1)
	-- table.insert(dailySales, dailyQueue[i])
    if currentDayIndex >= 7 then
        table.remove(Businesses[businessId].daily_sales, 1)
        currentDayIndex = #Businesses[businessId].daily_sales
    end
    if currentDayIndex == 0 or Businesses[businessId].daily_sales[currentDayIndex].date ~= date then 
        table.insert(Businesses[businessId].daily_sales, {
            date = date,
            amount = amount
        })
        currentDayIndex = #Businesses[businessId].daily_sales
    else
        Businesses[businessId].daily_sales[currentDayIndex].amount = Businesses[businessId].daily_sales[currentDayIndex].amount + amount
    end
    -- Update the column in MySQL
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET daily_sales = @daily_sales WHERE id = @id;", {
        ["@daily_sales"] = json.encode(Businesses[businessId].daily_sales),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
    TriggerClientEvent("pickle_businesses:updateBusiness", -1, businessId, Businesses[businessId])
end

function SendBusinessWebhook(businessId, webhookType, data)
    local business = Businesses[businessId]
    if not business or not business.game_info.webhooks then return end
    if Config.WebhookEvents[webhookType] and business.game_info.webhooks and BusinessWebhookURL(business.game_info.webhooks[webhookType]) and business.game_info.webhooks[webhookType]~="" then
        Config.WebhookEvents[webhookType](businessId, Businesses[businessId], data, business.game_info.webhooks[webhookType])
    end
end

function StringifyListings(items, currency)
    local str = ""
    for i=1, #items do
        local newStr
        if not currency then
            newStr = GetItemLabel(items[i].name) .. " (x" .. items[i].quantity .. ")"
        else 
            newStr = _L("market_"..items[i].name) .. " (" .. NumberWithCommas(items[i].quantity) .. ")"
        end
        if i == 1 then
            str = newStr
        else
            str = str .. ", " .. newStr
        end
    end
    return str
end

function CreatePurchaseLog(source, businessId, listings, purchaseMethod)
    local cost = 0
    for _, listing in ipairs(listings) do
        cost = cost + (listing.price * listing.quantity)
    end
    local name = GetPlayerCharacterName(source)
    local log = {
        name = name,
        items = listings,
        method = purchaseMethod,
        price = cost,
        timestamp = GetDateTime()
    }
    if Config.BusinessSettings.recentSalesCapacity <= #Businesses[businessId].recent_sales then
        table.remove(Businesses[businessId].recent_sales, #Businesses[businessId].recent_sales)
    end
	table.insert(Businesses[businessId].recent_sales, 1, log)
    SendBusinessWebhook(businessId, "purchase", log)
    -- Update the column in MySQL
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET recent_sales = @recent_sales WHERE id = @id;", {
        ["@recent_sales"] = json.encode(Businesses[businessId].recent_sales),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
    UpdateDailySales(businessId, cost)
    SendCustomInformationPacket(source, {
        {
            type = "updateRecentSales",
            index = businessId,
            data = Businesses[businessId].recent_sales
        },
        {
            type = "updateDailySales",
            index = businessId,
            data = Businesses[businessId].daily_sales
        }
    })
end

function AddStoreRole(businessId, data)
    local roleIndex = #Businesses[businessId].roles + 1
    Businesses[businessId].roles[roleIndex] = {
        id = GenerateStoreRoleId(businessId),
        label = data.label or "Untitled Role",
        salary = (data.salary ~= nil and data.salary > 0) and data.salary or 0,
        commission = (data.commission ~= nil and data.commission >= 0 and data.commission <= 100) and data.commission or 0,
        permissions = {
            funds = data.permissions.funds,
            roles = data.permissions.roles,
            items = data.permissions.items,
            logs = data.permissions.logs
        }
    }
    SendBusinessWebhook(businessId, "business", {
        type = "add_role",
        role = Businesses[businessId].roles[roleIndex].label,
        salary = Businesses[businessId].roles[roleIndex].salary,
        commission = Businesses[businessId].roles[roleIndex].commission,
        timestamp = GetDateTime()
    })
    -- Update the column in MySQL
    UpdateStoreRolesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateRoles", -1, businessId, Businesses[businessId].roles)
end

function EditStoreRole(businessId, roleId, data)
    local index, role = GetStoreRoleById(businessId, roleId)
    if not role then return end
    Businesses[businessId].roles[index].label = data.label or role.label
    Businesses[businessId].roles[index].salary = (data.salary ~= nil and data.salary >= 0) and data.salary or role.salary
    Businesses[businessId].roles[index].commission = (data.commission ~= nil and data.commission >= 0 and data.commission <= 100) and data.commission or role.commission
    if not Businesses[businessId].roles[index].owner then
        Businesses[businessId].roles[index].permissions = {
            funds = data.permissions.funds,
            roles = data.permissions.roles,
            items = data.permissions.items,
            logs = data.permissions.logs
        }
    end
    SendBusinessWebhook(businessId, "business", {
        type = "edit_role",
        role = Businesses[businessId].roles[index].label,
        salary = Businesses[businessId].roles[index].salary,
        commission = Businesses[businessId].roles[index].commission,
        timestamp = GetDateTime()
    })
    -- Update the column in MySQL
    UpdateStoreRolesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateRoles", -1, businessId, Businesses[businessId].roles)
    SetTimeout(200, function()
        TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
    end)
end

function DeleteStoreRole(businessId, roleId)
    local index, role = GetStoreRoleById(businessId, roleId)
    if not role then return end
    if role.owner then return end
    if #Businesses[businessId].roles == 2 then return end
    local updateEmployees = false
    table.remove(Businesses[businessId].roles, index)
    for identifier, employee in pairs(Businesses[businessId].employees) do
        if employee.roleId == roleId then
            Businesses[businessId].employees[identifier].roleId = Businesses[businessId].roles[#Businesses[businessId].roles].id
            updateEmployees = true
        end
    end
    UpdateStoreEmployeesSQL(businessId)
    SendBusinessWebhook(businessId, "business", {
        type = "remove_role",
        role = role.label,
        timestamp = GetDateTime()
    })
    -- Update the column in MySQL
    UpdateStoreRolesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateRoles", -1, businessId, Businesses[businessId].roles)
    if updateEmployees then
        SetTimeout(200, function()
            TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
        end)
    end
end

function MoveStoreRole(businessId, roleId, promote)
    local index, role = GetStoreRoleById(businessId, roleId)
    if not role then return end
    if promote then
        if index == 1 then return end
        if Businesses[businessId].roles[index - 1].owner then return end
        table.remove(Businesses[businessId].roles, index)
        table.insert(Businesses[businessId].roles, index - 1, role)
    else
        if index == #Businesses[businessId].roles then return end
        if Businesses[businessId].roles[index].owner then return end

        table.remove(Businesses[businessId].roles, index)
        table.insert(Businesses[businessId].roles, index + 1, role)
    end
    -- Update the column in MySQL
    SendBusinessWebhook(businessId, "business", {
        type = "move_role",
        role = role.label,
        position = (promote and (index - 1) or (index + 1)),
        timestamp = GetDateTime()
    })
    UpdateStoreRolesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateRoles", -1, businessId, Businesses[businessId].roles)
    SetTimeout(200, function()
        TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
    end)
end

function UpdateStoreEmployeesSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET employees = @employees WHERE id = @id;", {
        ["@employees"] = json.encode(Businesses[businessId].employees),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function UpdateStoreRolesSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET roles = @roles WHERE id = @id;", {
        ["@roles"] = json.encode(Businesses[businessId].roles),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function UpdateStoreListingsSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET store_listings = @store_listings WHERE id = @id;", {
        ["@store_listings"] = json.encode(Businesses[businessId].store_listings),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function UpdateStoreTradeInventorySQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET trade_inventory = @trade_inventory WHERE id = @id;", {
        ["@trade_inventory"] = json.encode(Businesses[businessId].trade_inventory),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function UpdateStoreTradeListingsSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET trade_listings = @trade_listings WHERE id = @id;", {
        ["@trade_listings"] = json.encode(Businesses[businessId].trade_listings),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function AddStoreTradeListing(businessId, data) 
    if not IsStoreTradeListingValid(data) then return false end
    Businesses[businessId].trade_listings[#Businesses[businessId].trade_listings + 1] = {
        give = data.give,
        receive = data.receive,
        sku = GenerateRandomTradeSku(businessId)
    }
    SendBusinessWebhook(businessId, "business", {
        type = "add_trade_listing",
        offers = {
            items = data.give.items,
            currencies = data.give.currencies
        },
        demands = {
            items = data.receive.items,
            currencies = data.receive.currencies
        },
        timestamp = GetDateTime()
    })
    -- Update the column in MySQL
    UpdateStoreTradeListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeListings", -1, businessId, Businesses[businessId].trade_listings)
end

function EditStoreTradeListing(businessId, sku, data) 
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not IsStoreTradeListingValid(data) then return false end
    if not tradeListing then return end
    if not IsStoreTradeListingValid(data) then return end
    Businesses[businessId].trade_listings[index].give = data.give
    Businesses[businessId].trade_listings[index].receive = data.receive
    SendBusinessWebhook(businessId, "business", {
        type = "update_trade_listing",
        offers = {
            items = tradeListing.give.items,
            currencies = tradeListing.give.currencies
        },
        demands = {
            items = tradeListing.receive.items,
            currencies = tradeListing.receive.currencies
        },
        timestamp = GetDateTime()
    })
    -- Update the column in MySQL
    UpdateStoreTradeListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeListings", -1, businessId, Businesses[businessId].trade_listings)
end

function DeleteStoreTradeListing(businessId, sku) 
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    table.remove(Businesses[businessId].trade_listings, index)
    -- Update the column in MySQL
    SendBusinessWebhook(businessId, "business", {
        type = "remove_trade_listing",
        offers = {
            items = tradeListing.give.items,
            currencies = tradeListing.give.currencies
        },
        demands = {
            items = tradeListing.receive.items,
            currencies = tradeListing.receive.currencies
        },
        timestamp = GetDateTime()
    })
    UpdateStoreTradeListingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateTradeListings", -1, businessId, Businesses[businessId].trade_listings)
end

function IsStoreTradeListingValid(data)
    if type(data)~='table' then return false end
    for _,side in ipairs({'give','receive'}) do
        local d=data[side]
        if type(d)~='table' then return false end
        for _,kind in ipairs({'items','currencies'}) do
            if type(d[kind])~='table' or #d[kind]>50 then return false end
            local seen={}
            for _,row in ipairs(d[kind]) do
                if type(row)~='table' or type(row.name)~='string' or #row.name>80 or seen[row.name]
                    or not BusinessInt(row.quantity,1,1000000) then return false end
                seen[row.name]=true
                if kind=='items' and not Inventory.Items[row.name] then return false end
                if kind=='currencies' and row.name~='cash' and row.name~='card' and row.name~='dirtycash' then return false end
            end
        end
    end
    return true
end

function CanPlayerPerformTrade(source, businessId, sku)
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    local items = tradeListing.receive.items
    local currencies = tradeListing.receive.currencies
    for i=1, #items do
        if Inventory.GetItemCount(source, items[i].name) < items[i].quantity then
            return false
        end
    end
    for i=1, #currencies do
        if GetPaymentMethodAmount(source, currencies[i].name) < currencies[i].quantity then
            return false
        end
    end
    return true
end

function CanStorePerformTrade(businessId, sku)
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    local items = tradeListing.give.items
    local currencies = tradeListing.give.currencies
    for i=1, #items do
        local count = GetStoreTradeInventoryItemCount(businessId, items[i].name)
        if count < items[i].quantity then
            return false
        end
    end
    for i=1, #currencies do
        local amount = GetStoreFunds(businessId, currencies[i].name)
        if amount < currencies[i].quantity then
            return false
        end
    end
    return true
end

function StoreTradeTransactionPlayer(source, businessId, sku)
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    local items = tradeListing.receive.items
    local currencies = tradeListing.receive.currencies
    for i=1, #items do
        Inventory.RemoveItem(source, items[i].name, items[i].quantity)
    end
    for i=1, #currencies do
        ChargePaymentMethod(source, currencies[i].name, currencies[i].quantity)
    end
    local items = tradeListing.give.items
    local currencies = tradeListing.give.currencies
    for i=1, #items do
        Inventory.AddItem(source, items[i].name, items[i].quantity)
    end
    for i=1, #currencies do
        AddPaymentMethodAmount(source, currencies[i].name, currencies[i].quantity)
    end
end

function StoreTradeTransactionStore(businessId, sku)
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    local items = tradeListing.give.items
    local currencies = tradeListing.give.currencies
    for i=1, #items do
        RemoveStoreTradeInventoryQuantity(businessId, items[i].name, items[i].quantity)
    end
    for i=1, #currencies do
        RemoveStoreFunds(businessId, currencies[i].name, currencies[i].quantity)
    end
    local items = tradeListing.receive.items
    local currencies = tradeListing.receive.currencies
    for i=1, #items do
        AddStoreTradeInventory(businessId, {
            name = items[i].name,
            quantity = items[i].quantity,
        })
    end
    for i=1, #currencies do
        AddStoreFunds(businessId, currencies[i].name, currencies[i].quantity)
    end
end

function StartStoreTradeTransaction(source, businessId, sku)
    local index, tradeListing = GetStoreTradeListingBySku(businessId, sku)
    if not tradeListing then return end
    local giveItems = tradeListing.give.items
    local giveCurrencies = tradeListing.give.currencies
    local receiveItems = tradeListing.receive.items
    local receiveCurrencies = tradeListing.receive.currencies
    if not CanPlayerPerformTrade(source, businessId, sku) then
        ShowNotification(source, _L("market_trade_fail_player"))
        return
    end
    if not CanStorePerformTrade(businessId, sku) then
        ShowNotification(source, _L("market_trade_fail_business"))
        return
    end
    SendBusinessWebhook(businessId, "trade", {
        offers = {
            items = giveItems or {},
            currencies = giveCurrencies or {}
        },
        demands = {
            items = receiveItems or {},
            currencies = receiveCurrencies or {}
        },
        timestamp = GetDateTime(),
    })
    StoreTradeTransactionPlayer(source, businessId, sku)
    StoreTradeTransactionStore(businessId, sku)
    ShowNotification(source, _L("market_trade_success"))
end

function IsAmountOverflowing(amount)
    return not BusinessInt(amount,1,2147483647)
end

function UpdateGameInfoSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET game_info = @game_info WHERE id = @id;", {
        ["@game_info"] = json.encode(Businesses[businessId].game_info),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function UpdateSettingsSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET label = @label, game_info = @game_info WHERE id = @id;", {
        ["@label"] = SafeCharacters(Businesses[businessId].label, 255),
        ["@game_info"] = json.encode(Businesses[businessId].game_info),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function IsPlayerNearby(source, target)
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetPed = GetPlayerPed(target)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(sourceCoords - targetCoords)
    return distance < 5.0
end

function GetPlayerBusinesses(source)
    local identifier = GetIdentifier(source)
    local businesses = {}
    for index, business in pairs(Businesses) do
        if business.owner == identifier then
            table.insert(businesses, index)
        else
            for employeeIdentifier, employee in pairs(business.employees) do
                if identifier == employeeIdentifier then
                    table.insert(businesses, index)
                end
            end
        end
    end
    return businesses
end

function UpdateStoreOwnerSQL(businessId)
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET owner = @owner, renting = @renting, roles = @roles, employees = @employees WHERE id = @id;", {
        ["@owner"] = Businesses[businessId].owner,
        ["@renting"] = Businesses[businessId].renting and 1 or 0,
        ["@roles"] = json.encode(Businesses[businessId].roles),
        ["@employees"] = json.encode(Businesses[businessId].employees),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
end

function CanPlayerHireToRole(source, businessId, roleId)
    local index, role = GetStoreRoleById(businessId, roleId)
    if not role then return false end
    if role.owner then return false end
    if CanAdministrateBusinesses(source) then return true end
    if not DoesPlayerHaveStorePermission(source, businessId, "roles") then return false end
    local sIndex, sRole = GetStoreRoleById(businessId, Businesses[businessId].employees[GetIdentifier(source)].roleId)
    if sRole.id == roleId then return false end
    for i=1, #Businesses[businessId].roles do
        local checkRole = Businesses[businessId].roles[i]
        if checkRole.id == roleId then
            return false
        elseif checkRole.id == sRole.id then
            return true
        end
    end
end

function AddStoreEmployeePendingMoney(businessId, identifier, amount, dontUpdate)
    if not Businesses[businessId] then return end
    if not Businesses[businessId].employees[identifier] then return end
    SetStoreEmployeePendingMoney(businessId, identifier, Businesses[businessId].employees[identifier].pendingMoney + amount, dontUpdate)
end

function RemoveStoreEmployeePendingMoney(businessId, identifier, amount, dontUpdate)
    if not Businesses[businessId] then return end
    if not Businesses[businessId].employees[identifier] then return end
    SetStoreEmployeePendingMoney(businessId, identifier, Businesses[businessId].employees[identifier].pendingMoney - amount, dontUpdate)
end

function SetStoreEmployeePendingMoney(businessId,identifier,amount,dontUpdate)
    local b=Businesses[businessId]; local employee=b and b.employees[identifier]
    if not employee or not BusinessInt(amount,0,2147483647) then return false end
    employee.pendingMoney=amount
    UpdateStoreEmployeesSQL(businessId)
    local src=GetSourceFromIdentifier(identifier)
    if src and amount>0 then
        employee.pendingMoney=0 -- claim before the external credit can yield
        UpdateStoreEmployeesSQL(businessId)
        if AddPaymentMethodAmount(src,'cash',amount)~=true then employee.pendingMoney=amount; UpdateStoreEmployeesSQL(businessId) end
    end
    TriggerClientEvent('pickle_businesses:updateEmployees',-1,businessId,GetBusinessEmployees(businessId))
    return true
end

function GetStoreEmployeePendingMoney(businessId, identifier)
    if not Businesses[businessId] then return end
    if not Businesses[businessId].employees[identifier] then return 0 end
    return Businesses[businessId].employees[identifier].pendingMoney
end

function AddStoreEmployee(businessId, source, roleId)
    local identifier = GetIdentifier(source)
    local roleIndex, role = GetStoreRoleById(businessId, roleId)
    if not role then return end
    Businesses[businessId].employees[identifier] = {
        name = GetPlayerCharacterName(source),
        roleId = roleId,
        pendingMoney = 0
    }
    UpdateStoreEmployeesSQL(businessId)
    SendBusinessWebhook(businessId, "business", {
        type = "hire_employee",
        employee = Businesses[businessId].employees[identifier].name,
        role = role.label,
        timestamp = GetDateTime()
    })
    TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
end

function EditStoreEmployee(businessId, identifier, roleId)
    if not Businesses[businessId].employees[identifier] then return end
    Businesses[businessId].employees[identifier].roleId = roleId
    local roleIndex, role = GetStoreRoleById(businessId, roleId)
    SendBusinessWebhook(businessId, "business", {
        type = "fire_employee",
        employee = Businesses[businessId].employees[identifier].name,
        role = role.label,
        timestamp = GetDateTime()
    })
    UpdateStoreEmployeesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
end

function RemoveStoreEmployee(businessId, identifier)
    if not Businesses[businessId].employees[identifier] then return end
    if Businesses[businessId].owner == identifier then return end
    local name = Businesses[businessId].employees[identifier].name
    Businesses[businessId].employees[identifier] = nil
    SendBusinessWebhook(businessId, "business", {
        type = "fire_employee",
        employee = name,
        timestamp = GetDateTime()
    })
    UpdateStoreEmployeesSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateEmployees", -1, businessId, GetBusinessEmployees(businessId))
end

function BusinessCallback(callbackName, source, businessId, ...)
    local business = Businesses[businessId]
    if not business then return end
    local zoneIndex, zone = GetBusinessZoneIndexByName(business.zone)
    if not zone then return end
    if not zone.callbacks then return true end
    local callback = zone.callbacks[callbackName]
    if not callback then 
        callback = Config.DefaultCallbacks[callbackName]
    end
    if not callback then return true end
    return callback(source, businessId, ...)
end

function SaveStoreSettings(businessId, settings)
    if settings.label and type(settings.label) == "string" then
        Businesses[businessId].label = settings.label
    end
    if not Businesses[businessId].game_info.webhooks then Businesses[businessId].game_info.webhooks = {} end
    if settings.business and BusinessWebhookURL(settings.business) then
        Businesses[businessId].game_info.webhooks.business = settings.business
    end
    if settings.purchase and BusinessWebhookURL(settings.purchase) then
        Businesses[businessId].game_info.webhooks.purchase = settings.purchase
    end
    if settings.trade and BusinessWebhookURL(settings.trade) then
        Businesses[businessId].game_info.webhooks.trade = settings.trade
    end
    UpdateSettingsSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateBusinessSettings", -1, businessId, { label = Businesses[businessId].label, game_info = Businesses[businessId].game_info })
end

function UpdateStoreWipeSQL(businessId)
    local business = Businesses[businessId]
    if not business then return end
    BusinessSQLExecute("UPDATE pickle_businesses_locations SET owner = @owner, label = @label, roles = @roles, employees = @employees, trade_listings = @trade_listings, daily_sales = @daily_sales, recent_sales = @recent_sales, recent_trades = @recent_trades, game_info = @game_info WHERE id = @id;", {
        ["@owner"] = business.owner,
        ["@label"] = SafeCharacters(business.label, 255),
        ["@roles"] = json.encode(business.roles),
        ["@employees"] = json.encode(business.employees),
        ["@trade_listings"] = json.encode(business.trade_listings),
        ["@daily_sales"] = json.encode(business.daily_sales),
        ["@recent_sales"] = json.encode(business.recent_sales),
        ["@recent_trades"] = json.encode(business.recent_trades),
        ["@game_info"] = json.encode(business.game_info),
        ["@id"] = business.id
    }, function(rowsChanged)
    end)
end

function StoreWipe(businessId, source)
    local business = Businesses[businessId]
    if not business then return end
    -- Outstanding assets and payroll must be settled before changing ownership.
    if business.money>0 or business.dirty_money>0 or #business.store_listings>0 or #business.trade_inventory>0 then return false end
    for _,employee in pairs(business.employees) do if (employee.pendingMoney or 0)>0 then return false end end
    Businesses[businessId].label = "Untitled Business"
    if not BusinessEstateEmpty(businessId) then return false end
    if source then
        ResetBusinessOwner(businessId, source)
    else
        Businesses[businessId].owner = nil
        Businesses[businessId].roles = {}
        Businesses[businessId].employees = {}
    end
    Businesses[businessId].trade_listings = {}
    Businesses[businessId].daily_sales = {}
    Businesses[businessId].recent_sales = {}
    Businesses[businessId].recent_trades = {}
    if business.game_info.webhooks then
        business.game_info.webhooks.business = ""
        business.game_info.webhooks.purchase = ""
        business.game_info.webhooks.trade = ""
    end
    UpdateStoreWipeSQL(businessId)
    TriggerClientEvent("pickle_businesses:updateBusiness", -1, businessId, Businesses[businessId])
end

function ResetBusinessOwner(businessId, source)
    local identifier = GetIdentifier(source)
    Businesses[businessId].owner = identifier
    Businesses[businessId].roles = {}
    Businesses[businessId].roles[1] = {
        id = GenerateStoreRoleId(businessId),
        label = _L("owner_role"),
        salary = 0,
        commission = 0,
        owner = true,
        permissions = {
            funds = true,
            roles = true,
            items = true,
            logs = true
        }
    }
    Businesses[businessId].roles[2] = {
        id = GenerateStoreRoleId(businessId),
        label = _L("employee_role"),
        salary = 0,
        commission = 0,
        owner = false,
        permissions = {
            funds = false,
            roles = false,
            items = false,
            logs = false
        }
    }
    Businesses[businessId].employees = {
        [identifier] = {
            name = GetPlayerCharacterName(source),
            roleId = Businesses[businessId].roles[1].id,
            pendingMoney = 0
        }
    }
end

function DeleteBusiness(businessId)
    local business = Businesses[businessId]
    if not business then return end
    BusinessSQLExecute("DELETE FROM pickle_businesses_locations WHERE id = @id;", {
        ["@id"] = business.id
    }, function(rowsChanged)
    end)
    Businesses[businessId] = nil
    TriggerClientEvent("pickle_businesses:updateBusiness", -1, businessId, nil)
end

RegisterNetEvent("pickle_businesses:initializePlayer", function()
    local source = source
    while not Inventory or not Inventory.Ready do Wait(10) end
    TriggerClientEvent("pickle_businesses:setupInventory", source, {items = Inventory.Items})
    TriggerClientEvent("pickle_businesses:updateBusiness", source, nil, Businesses)
    TriggerClientEvent("pickle_businesses:setIdentifier", source, GetIdentifier(source), CanAdministrateBusinesses(source))
end)

RegisterNetEvent("pickle_businesses:purchaseBusiness", function(businessId, purchaseType)
    local source = source
    local identifier = GetIdentifier(source)
    local business = Businesses[businessId]
    local purchaseType = (purchaseType == "purchase" and "price" or "rent")
    if not business then return end
    if business.owner then return ShowNotification(source, _L("business_already_owned")) end
    local cost = business[purchaseType]  
    if cost > GetPaymentMethodAmount(source, "cash") then
        return ShowNotification(source, _L("insufficient_funds_" .. purchaseType, NumberWithCommas(cost)))
    end
    if not BusinessInt(cost,1,2147483647) or not BusinessCallback("ownerCheck", source, businessId, purchaseType, cost) then return end
    if ChargePaymentMethod(source,"cash",cost)~=true then return end
    ResetBusinessOwner(businessId, source)
    Businesses[businessId].renting = (purchaseType == "rent")
    UpdateStoreOwnerSQL(businessId)
    BusinessCallback("postOwner", source, businessId, purchaseType, cost)
    ShowNotification(source, _L("business_"..purchaseType.."_success", NumberWithCommas(cost)))
    TriggerClientEvent("pickle_businesses:updateBusinessOwner", -1, businessId, { owner = Businesses[businessId].owner, roles = Businesses[businessId].roles, employees = Businesses[businessId].employees, renting = Businesses[businessId].renting })
end)

RegisterNetEvent("pickle_businesses:endLease", function(businessId)
    local source = source
    local business = Businesses[businessId]
    if not business or (business.owner ~= GetIdentifier(source) and not CanAdministrateBusinesses(source)) or not business.renting then return ShowNotification(source, _L("business_end_lease_fail")) end
    ShowNotification(source, _L("business_end_lease_success"))
    StoreWipe(businessId)
end)

RegisterNetEvent("pickle_businesses:sellBusiness", function(businessId)
    local source = source
    local business = Businesses[businessId]
    if not business or (business.owner ~= GetIdentifier(source) and not CanAdministrateBusinesses(source)) or business.renting then return ShowNotification(source, _L("business_sell_fail")) end
    if not BusinessEstateEmpty(businessId) then return ShowNotification(source,"Empty business funds, stock and payroll before selling.") end
    local price = business.price or 0
    local refund = math.floor(price * Config.BusinessSettings.sellScale)
    if refund > 0 then
        AddPaymentMethodAmount(source, "cash", refund)
    end
    ShowNotification(source, _L("business_sell_success", NumberWithCommas(refund)))
    StoreWipe(businessId)
end)

RegisterNetEvent("pickle_businesses:transferBusiness", function(businessId, target)
    local source = source
    local business = Businesses[businessId]
    if not business or (business.owner ~= GetIdentifier(source) and not CanAdministrateBusinesses(source)) or business.renting then return ShowNotification(source, _L("business_transfer_fail")) end
    local targetIdentifier = GetIdentifier(target)
    if not targetIdentifier then return ShowNotification(source, _L("business_transfer_fail")) end
    ShowNotification(source, _L("business_transfer_success", GetPlayerCharacterName(target)))
    StoreWipe(businessId, target)
end)

RegisterNetEvent("pickle_businesses:removeBusiness", function(businessId, roleId, data)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not (business.game_info.placed and business.owner==GetIdentifier(source)) and not CanAdministrateBusinesses(source) then
        return ShowNotification(source, _L("no_permission"))
    end
    ShowNotification(source, _L("business_removed", business.label))
    DeleteBusiness(businessId)
end)

lib.callback.register("pickle_businesses:getInventory", function(source)
    local inv = Inventory.GetInventory(source)
    return inv
end)
lib.callback.register("pickle_businesses:getBusinessEmployees", function(source, businessId)
    if not CanAdministrateBusinesses(source) and not GetBusinessEmployee(source,businessId) then return {} end
    return GetBusinessEmployees(businessId)
end)
lib.callback.register("pickle_businesses:getStoreData", function(source, businessId)
    return Inventory.GetInventory(source), (CanAdministrateBusinesses(source) or GetBusinessEmployee(source,businessId)) and GetBusinessEmployees(businessId) or {}, CanAdministrateBusinesses(source)
end)
lib.callback.register("pickle_businesses:getNearbyPlayers", function(source)
    local source = source
    local players = {}
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    for _, player in ipairs(GetPlayers()) do
        local player = tonumber(player)
        if player ~= source then
            local playerPed = GetPlayerPed(player)
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - sourceCoords)
            if distance < 5.0 then
                table.insert(players, {
                    id = tonumber(player),
                    name = GetPlayerCharacterName(player),
                    distance = distance
                })
            end
        end
    end
    return players
end)
lib.callback.register("pickle_businesses:getPlayerBusinesses", function(source, target)
    if target and target~=source and not CanAdministrateBusinesses(source) then return {} end
    return GetPlayerBusinesses(target or source)
end)

function ParseGameInfoSQL(data)
    local data = json.decode(data)
    local bounds = nil
    local locations = nil
    local webhooks = {}
    if data.bounds then
        bounds = {}
        for i=1, #data.bounds do 
            bounds[i] = vector3(data.bounds[i].x, data.bounds[i].y, data.bounds[i].z)
        end
    end
    if data.locations then
        locations = {}
        for i=1, #data.locations do
            local coords = vector3(data.locations[i].coords.x, data.locations[i].coords.y, data.locations[i].coords.z)
            local rotation = vector3(data.locations[i].rotation.x, data.locations[i].rotation.y, data.locations[i].rotation.z)
            locations[i] = data.locations[i]
            locations[i].coords = coords
            locations[i].rotation = rotation
        end
    end
    if data.webhooks then
        webhooks.business = data.webhooks.business or ""
        webhooks.purchase = data.webhooks.purchase or ""
        webhooks.trade = data.webhooks.trade or ""
    end
    return {
        placed = data.placed,
        bounds = bounds,
        locations = locations,
        webhooks = webhooks
    }
end

function ProcessBusinessRent()
    for index, business in pairs(Businesses) do
        if business.owner and business.renting then
            local cost = business.rent
            if business.money < cost then
                Businesses[index].money = 0
                StoreWipe(index)
            else
                Businesses[index].money = Businesses[index].money - cost
            end
            BusinessSQLExecute("UPDATE pickle_businesses_locations SET money = @money WHERE id = @id;", {
                ["@money"] = Businesses[index].money,
                ["@id"] = Businesses[index].id
            })
        end

    end
end

function ProcessBusinessSalary()
    for index, business in pairs(Businesses) do
        if business.owner then
            local moneyLeft = business.money
            for identifier, employee in pairs(business.employees) do
                local employeeSource = GetSourceFromIdentifier(identifier)
                local roleIndex, role = GetStoreRoleById(index, employee.roleId)
                if role then
                    local salary = role.salary
                    if moneyLeft - salary >= 0 then
                        moneyLeft = moneyLeft - salary
                        AddStoreEmployeePendingMoney(index, identifier, salary, true)
                        if employeeSource and salary > 0 then
                            ShowNotification(employeeSource, _L("salary_success", business.label, NumberWithCommas(salary)))
                        end
                    else
                        if employeeSource then
                            ShowNotification(employeeSource, _L("salary_fail", business.label))
                        end
                    end
                end
            end
            if Businesses[index].money ~= moneyLeft then
                Businesses[index].money = moneyLeft
                BusinessSQLExecute("UPDATE pickle_businesses_locations SET money = @money WHERE id = @id;", {
                    ["@money"] = Businesses[index].money,
                    ["@id"] = Businesses[index].id
                })
                UpdateStoreEmployeesSQL(index)
                TriggerClientEvent("pickle_businesses:updateEmployees", -1, index, GetBusinessEmployees(index))
            end
        end
    end
end

MySQL.ready(function()
    while not Inventory or not Inventory.Ready do Wait(10) end
    lib.cron.new(Config.BusinessSettings.rentCron, function()
        ProcessBusinessRent()
    end)
    lib.cron.new(Config.BusinessSettings.salaryCron, function()
        ProcessBusinessSalary()
    end)
    MySQL.Async.fetchAll("SELECT * FROM pickle_businesses_locations;", {}, function(result)
        if result then
            for _, row in ipairs(result) do
                local ok,err=pcall(function()
                row.renting = (row.renting == 1)
                row.label = row.label
                row.owner = row.owner
                row.price = tonumber(row.price)
                row.rent = tonumber(row.rent)
                row.money = tonumber(row.money)
                row.dirty_money = tonumber(row.dirty_money)
                row.zone = row.zone
                row.game_info = ParseGameInfoSQL(row.game_info)
                row.store_listings = json.decode(row.store_listings)
                row.trade_listings = json.decode(row.trade_listings)
                row.trade_inventory = json.decode(row.trade_inventory)
                row.daily_sales = json.decode(row.daily_sales)
                row.recent_sales = json.decode(row.recent_sales)
                row.recent_trades = json.decode(row.recent_trades)
                row.employees = json.decode(row.employees)
                row.roles = json.decode(row.roles)
                InitializeBusiness(row, false)
                end)
                if not ok then print("Skipping invalid business row "..tostring(row.id)..": "..tostring(err)) end
            end
        end
    end)
end)