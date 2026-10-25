-- Market (Shared)

function GetStackedItems(source, item)
    local count = 0
    local items = {}
    local name = item.name
    local inventoryItem = GetReferencedItem(source, item)
    local inventory = Inventory.GetInventory(source)
    if not inventoryItem then return 0,{} end
    if ((inventoryItem.durability or 100) < 100) then
        return 1, {inventoryItem}
    end
    for i=1, #inventory do
        if (inventory[i].name == name and (inventory[i].durability or 100) >= 100 and json.encode(inventory[i].metadata or {})==json.encode(inventoryItem.metadata or {})) then
            count = count + inventory[i].count;
            items[#items + 1] = inventory[i];
        end
    end
    return count, items
end

function ProcessPlayerItemRemoval(source, businessId, itemInfo, quantity)
    local business = Businesses[businessId]
    if not business then return end
    local count, items = GetStackedItems(source, itemInfo)
    if count < quantity then return end
    if quantity == 1 then
        Inventory.RemoveItem(source, items[1].name, 1, items[1].slot)
    else
        if items[1].slot then
            if items[1].count >= quantity then
                Inventory.RemoveItem(source, items[1].name, quantity, items[1].slot)
            else
                local amountToRemove = quantity - items[1].count
                Inventory.RemoveItem(source, items[1].name, items[1].count, items[1].slot)
                for i=2, #items do
                    local item = items[i]
                    if item.count >= amountToRemove then
                        Inventory.RemoveItem(source, item.name, amountToRemove, item.slot)
                        amountToRemove = 0
                        break
                    else
                        amountToRemove = amountToRemove - item.count
                        Inventory.RemoveItem(source, item.name, item.count, item.slot)
                    end
                end    
            end
        else
            Inventory.RemoveItem(source, itemInfo.name, quantity)
        end
    end
    return true
end

-- Market (Buy)

function GetListingItemInfo(source, listing)
    local count = 0
    local items = {}
    local name = listing.name
    local inventory = Inventory.GetInventory(source)
    if ((listing.metadata.durability or 100) < 100) then
        return 0, {listing}
    end
    for i=1, #inventory do
        if (inventory[i].name == name and (inventory[i].durability or 100) >= 100 and json.encode(inventory[i].metadata or {})==json.encode(inventoryItem.metadata or {})) then
            count = count + inventory[i].count;
            items[#items + 1] = inventory[i];
        end
    end
    return count, items
end

function GetReferencedItem(source, item)
    local inventory = Inventory.GetInventory(source)
    if not inventory then return end
    if not item then return end
    for i=1, #inventory do
        if item.slot ~= nil then
            if inventory[i].slot == item.slot then
                return inventory[i]
            end
        elseif inventory[i].name == item.name then
            return inventory[i]
        end
    end
end

function IsListingStockAdditionValid(businessId, sku, amount, source)
    local business = Businesses[businessId]
    if not business then 
        if source then
            ShowNotification(source, _L("business_invalid"))
        end
        return
    end
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then 
        if source then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    local newQuantity = listing.quantity + amount
    if source then
        local count, items = GetListingItemInfo(source, listing)
        if count == 0 and (listing.metadata.durability or 100) < 100 then
            local count = Inventory.GetItemCount(source, listing.name)
            if count > 1 then
                ShowNotification(source, _L("cant_stack_damaged"))
                return
            end
        end
        if count < amount then 
            ShowNotification(source, _L("not_enough", (Inventory.Items[listing.name] and Inventory.Items[listing.name].label or "Unknown Item"), amount - count))
            return
        end
    end
    return true
end

function IsListingStockRemovalValid(businessId, sku, amount, source)
    local business = Businesses[businessId]
    if not business then 
        if source then
            ShowNotification(source, _L("business_invalid"))
        end
        return
    end
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then 
        if source then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    local newQuantity = listing.quantity - amount
    if newQuantity < 0 then 
        if source then
            ShowNotification(source, _L("not_enough", (Inventory.Items[listing.name] and Inventory.Items[listing.name].label or "Unknown Item"), math.abs(newQuantity)))
        end
        return
    end
    if source then
        if not (Inventory.CanCarryItem(source, listing.name, amount)) then 
            ShowNotification(source, _L("no_room"))
            return
        end
    end
    return true
end

function IsTradeInventoryAdditionValid(businessId, sku, amount, source)
    local business = Businesses[businessId]
    if not business then 
        if source then
            ShowNotification(source, _L("business_invalid"))
        end
        return
    end
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then 
        if source then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    local newQuantity = tradeItem.quantity + amount
    if source then
        local count, items = GetListingItemInfo(source, tradeItem)
        if count == 0 and (tradeItem.metadata.durability or 100) < 100 then
            local count = Inventory.GetItemCount(source, tradeItem.name)
            if count > 1 then
                ShowNotification(source, _L("cant_stack_damaged"))
                return
            end
        end
        if count < amount then 
            ShowNotification(source, _L("not_enough", (Inventory.Items[tradeItem.name] and Inventory.Items[tradeItem.name].label or "Unknown Item"), amount - count))
            return
        end
    end
    return true
end

function IsTradeInventoryRemovalValid(businessId, sku, amount, source)
    local business = Businesses[businessId]
    if not business then 
        if source then
            ShowNotification(source, _L("business_invalid"))
        end
        return
    end
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then 
        if source then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    local newQuantity = tradeItem.quantity - amount
    if newQuantity < 0 then 
        if source then
            ShowNotification(source, _L("not_enough", (Inventory.Items[tradeItem.name] and Inventory.Items[tradeItem.name].label or "Unknown Item"), math.abs(newQuantity)))
        end
        return
    end
    if source then
        if not (Inventory.CanCarryItem(source, tradeItem.name, amount)) then 
            ShowNotification(source, _L("no_room"))
            return
        end
    end
    return true
end

function ProcessListingStockAddition(businessId, sku, price, amount, source, dontNotify)
    if not IsListingStockAdditionValid(businessId, sku, amount, source) then return end
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then 
        if source and not dontNotify then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    if source then
        if Inventory.RemoveItem(source,listing.name,amount)~=true then return false end
    end
    if source and not dontNotify then ShowNotification(source, _L("market_buy_listing_editsuccess")) end
    EditStoreListing(businessId, sku, price, listing.quantity + amount)
    return true 
end

function ProcessListingStockRemoval(businessId, sku, price, amount, source, dontNotify)
    if not IsListingStockRemovalValid(businessId, sku, amount, source) then return end
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not listing then 
        if source and not dontNotify then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    if source then
        if Inventory.AddItem(source,listing.name,amount,listing.metadata)~=true then return false end
    end
    if source and not dontNotify then
        if listing.quantity - amount == 0 then
            ShowNotification(source, _L("market_buy_listing_removesuccess"))
        else
            ShowNotification(source, _L("market_buy_listing_editsuccess"))
        end
    end
    EditStoreListing(businessId, sku, price, listing.quantity - amount)
    return true 
end

function ProcessTradeInventoryAddition(businessId, sku, amount, source, dontNotify)
    if not IsTradeInventoryAdditionValid(businessId, sku, amount, source) then return end
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then 
        if source and not dontNotify then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    if source then
        if Inventory.RemoveItem(source,tradeItem.name,amount)~=true then return false end
    end
    if source and not dontNotify then ShowNotification(source, _L("market_buy_listing_editsuccess")) end
    EditStoreTradeInventory(businessId, sku, tradeItem.quantity + amount)
    return true 
end

function ProcessTradeInventoryRemoval(businessId, sku, amount, source, dontNotify)
    if not IsTradeInventoryRemovalValid(businessId, sku, amount, source) then return end
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not tradeItem then 
        if source and not dontNotify then
            ShowNotification(source, _L("listing_invalid"))
        end
        return
    end
    if source then
        if Inventory.AddItem(source,tradeItem.name,amount,tradeItem.metadata)~=true then return false end
    end
    if source and not dontNotify then
        if tradeItem.quantity - amount == 0 then
            ShowNotification(source, _L("market_buy_listing_removesuccess"))
        else
            ShowNotification(source, _L("market_buy_listing_editsuccess"))
        end
    end
    EditStoreTradeInventory(businessId, sku, tradeItem.quantity - amount)
    return true 
end

function IsPaymentMethodSufficient(source, businessId, paymentMethod, cost)
    local business = Businesses[businessId]
    if not business then return end
    if not BusinessInt(cost,0,2147483647) then return false end
    if paymentMethod=="dirtycash" and not BusinessDirtyAllowed(businessId) then return false end
    if paymentMethod == "cash" then
        local cash = GetPaymentMethodAmount(source, "cash")
        if cash < cost then
            ShowNotification(source, _L("not_enough_money", NumberWithCommas(cost), _L("money_cash")))
            return
        end
    elseif paymentMethod == "card" then
        local cash = GetPaymentMethodAmount(source, "card")
        if cash < cost then
            ShowNotification(source, _L("not_enough_money", NumberWithCommas(cost), _L("money_card")))
            return
        end
    elseif paymentMethod == "dirtycash" then
        local cash = GetPaymentMethodAmount(source, "dirtycash")
        if cash < cost then
            ShowNotification(source, _L("not_enough_money", NumberWithCommas(cost), _L("money_dirtycash")))
            return
        end
    else
        ShowNotification(source, _L("invalid_payment_method"))
        return
    end
    return true
end

function CanCarryItems(source, items)
    if not Inventory.CanCarryItem then return true end
    for i=1, #items do 
        if not Inventory.CanCarryItem(source, items[i].name, items[i].count) then
            return false
        end
    end
    return true 
end

function IsCartPurchasable(source, businessId, cart, paymentMethod)
    if type(cart)~='table' or #cart<1 or #cart>100 then return false end
    local seen={}
    for _,row in ipairs(cart) do
        if type(row)~='table' or type(row.sku)~='string' or seen[row.sku] or not BusinessInt(row.quantity,1,1000000) then return false end
        seen[row.sku]=true
    end
    local itemSearch = {}
    local cost = 0
    for i=1, #cart do 
        local index, listing = GetStoreListingBySku(businessId, cart[i].sku)
        if not listing then 
            ShowNotification(source, _L("market_buy_listing_invalid"))
            return
        end
        if cart[i].quantity < 1 or cart[i].quantity > listing.quantity then 
            ShowNotification(source, _L("not_enough_store", (Inventory.Items[listing.name] and Inventory.Items[listing.name].label or "Unknown Item"), cart[i].quantity - listing.quantity))
            return
        end
        itemSearch[#itemSearch + 1] = {
            name = listing.name,
            count = cart[i].quantity
        }
        cost = cost + (listing.price * cart[i].quantity)
    end
    if not CanCarryItems(source, itemSearch) then 
        ShowNotification(source, _L("no_room"))
        return
    end
    if not IsPaymentMethodSufficient(source, businessId, paymentMethod, cost) then return end
    return BusinessCallback("purchaseCheck", source, businessId, cart, cost)
end

function ProcessCartPurchase(src,businessId,cart,method)
    if not IsCartPurchasable(src,businessId,cart,method) or not BusinessNear(src,businessId,20) then return false end
    local total=0
    for _,row in ipairs(cart) do local _,listing=GetStoreListingBySku(businessId,row.sku); total=total+listing.price*row.quantity end
    if ChargePaymentMethod(src,method,total)~=true then return false end
    local delivered,cost={},0
    for _,row in ipairs(cart) do
        local _,listing=GetStoreListingBySku(businessId,row.sku)
        if Inventory.AddItem(src,listing.name,row.quantity,listing.metadata)==true then
            cost=cost+listing.price*row.quantity
            delivered[#delivered+1]={sku=row.sku,name=listing.name,price=listing.price,quantity=row.quantity}
            EditStoreListing(businessId,row.sku,listing.price,listing.quantity-row.quantity)
        end
    end
    if total>cost then AddPaymentMethodAmount(src,method,total-cost) end
    if cost>0 then AddStoreFunds(businessId,method,cost); CreatePurchaseLog(src,businessId,delivered,method,cost) end
    return cost==total
end

RegisterNetEvent("pickle_businesses:moveStoreListing", function(businessId, fromSku, toSku)
    local source = source
    local fromIndex, fromListing = GetStoreListingBySku(businessId, fromSku)
    local toIndex, toListing = GetStoreListingBySku(businessId, toSku)
    if not DoesPlayerHaveStorePermission(source, businessId, "items") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not fromListing or not toListing then return end
    Businesses[businessId].store_listings[fromIndex] = toListing
    Businesses[businessId].store_listings[toIndex] = fromListing
    MySQL.Async.execute("UPDATE pickle_businesses_locations SET store_listings = @store_listings WHERE id = @id;", {
        ["@store_listings"] = json.encode(Businesses[businessId].store_listings),
        ["@id"] = Businesses[businessId].id
    }, function(rowsChanged)
    end)
    TriggerClientEvent("pickle_businesses:updateListings", -1, businessId, Businesses[businessId].store_listings)
end)

RegisterNetEvent("pickle_businesses:addStoreListing", function(businessId, itemInfo, price, quantity)
    local source = source
    local business = Businesses[businessId]
    local count, items = GetStackedItems(source, itemInfo)
    if not DoesPlayerHaveStorePermission(source, businessId, "items") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not business then return end
    if not ProcessPlayerItemRemoval(source, businessId, itemInfo, quantity) then return end
    ShowNotification(source, _L("market_buy_listing_addsuccess"))
    AddStoreListing(businessId, {
        name = items[1].name,
        metadata = items[1].metadata or {},
        price = price,
        quantity = quantity
    })
end)

RegisterNetEvent("pickle_businesses:editStoreListing", function(businessId, sku, price, quantity)
    local source = source
    local index, listing = GetStoreListingBySku(businessId, sku)
    if not DoesPlayerHaveStorePermission(source, businessId, "items") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not listing then return end
    if price < 0 or quantity < 0 then return end
    if listing.quantity < quantity then
        local diff = quantity - listing.quantity
        ProcessListingStockAddition(businessId, sku, price, diff, source)
    elseif listing.quantity > quantity then
        local diff = listing.quantity - quantity
        ProcessListingStockRemoval(businessId, sku, price, diff, source)
    else
        ShowNotification(source, _L("market_buy_listing_editsuccess"))
        EditStoreListing(businessId, sku, price, listing.quantity)
    end
end)

lib.callback.register("pickle_businesses:purchaseCart", function(source, businessId, cart, paymentMethod)
    return ProcessCartPurchase(source, businessId, cart, paymentMethod)
end)

function CanInteractWithRoleId(source, businessId, roleId)
    local business = Businesses[businessId]
    if not business then return end
    if CanAdministrateBusinesses(source) then return true end
    if GetIdentifier(source) == business.owner then return true end
    local employee = GetBusinessEmployee(source, businessId)
    if roleId == employee.roleId then return false end
    local roles = business.roles
    for i=1, #roles do
        if roles[i].id == roleId then return false end
        if roles[i].id == employee.roleId then return true end
    end
end

function GetStoreRoleIndex(businessId, roleId)
    local business = Businesses[businessId]
    if not business then return end
    for i=1, #business.roles do
        if business.roles[i].id == roleId then
            return i, business.roles[i]
        end
    end
end

-- Market (Trade)

RegisterNetEvent("pickle_businesses:addTradeListing", function(businessId, tradeData)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "funds") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    AddStoreTradeListing(businessId, tradeData)
end)

RegisterNetEvent("pickle_businesses:updateTradeListing", function(businessId, sku, tradeData)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "funds") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    EditStoreTradeListing(businessId, sku, tradeData)
end)

RegisterNetEvent("pickle_businesses:deleteTradeListing", function(businessId, sku)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "funds") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    DeleteStoreTradeListing(businessId, sku)
end)

RegisterNetEvent("pickle_businesses:acceptTrade", function(businessId, sku)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not BusinessNear(source,businessId,20) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    StartStoreTradeTransaction(source, businessId, sku)
end)

-- Market (Manage)

RegisterNetEvent("pickle_businesses:addTradeInventory", function(businessId, itemInfo, quantity)
    local source = source
    local business = Businesses[businessId]
    local count, items = GetStackedItems(source, itemInfo)
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "items") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not ProcessPlayerItemRemoval(source, businessId, itemInfo, quantity) then return end
    ShowNotification(source, _L("market_manage_newitem_addsuccess"))
    AddStoreTradeInventory(businessId, {
        name = items[1].name,
        metadata = items[1].metadata or {},
        price = price,
        quantity = quantity
    })
end)

RegisterNetEvent("pickle_businesses:editTradeInventory", function(businessId, sku, quantity)
    local source = source
    local index, tradeItem = GetStoreTradeInventoryBySku(businessId, sku)
    if not DoesPlayerHaveStorePermission(source, businessId, "items") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not tradeItem then return end
    if quantity < 0 then return end
    if tradeItem.quantity < quantity then
        local diff = quantity - tradeItem.quantity
        ProcessTradeInventoryAddition(businessId, sku, diff, source)
    elseif tradeItem.quantity > quantity then
        local diff = tradeItem.quantity - quantity
        ProcessTradeInventoryRemoval(businessId, sku, diff, source)
    else
        ShowNotification(source, _L("market_buy_listing_editsuccess"))
        EditStoreTradeInventory(businessId, sku, tradeItem.quantity)
    end
end)

RegisterNetEvent("pickle_businesses:addRole", function(businessId, roleData)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "roles") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    AddStoreRole(businessId, roleData)
end)

RegisterNetEvent("pickle_businesses:moveRole", function(businessId, roleId, promote)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "roles") or not CanInteractWithRoleId(source, businessId, roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if not CanAdministrateBusinesses(source) then
        local employee = GetBusinessEmployee(source, businessId)
        local roleIndex = GetStoreRoleIndex(businessId, employee.roleId)
        local targetRoleIndex = GetStoreRoleIndex(businessId, roleId)
        if promote and roleIndex + 1 == targetRoleIndex then
            ShowNotification(source, _L("no_permission"))
            return
        end
    end
    MoveStoreRole(businessId, roleId, promote)
end)

RegisterNetEvent("pickle_businesses:editRole", function(businessId, roleId, roleData)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "roles") or not CanInteractWithRoleId(source, businessId, roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    EditStoreRole(businessId, roleId, roleData)
end)

RegisterNetEvent("pickle_businesses:deleteRole", function(businessId, roleId)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "roles") or not CanInteractWithRoleId(source, businessId, roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    DeleteStoreRole(businessId, roleId)
end)

RegisterNetEvent("pickle_businesses:addEmployee", function(businessId, target, roleId)
    local source = source
    local business = Businesses[businessId]
    if not business or target == -1 then return end
    if not CanPlayerHireToRole(source, businessId, roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    AddStoreEmployee(businessId, target, roleId)
end)

RegisterNetEvent("pickle_businesses:editEmployee", function(businessId, identifier, roleId)
    local source = source
    local business = Businesses[businessId]
    if not business or not identifier or identifier == GetIdentifier(source) or not CanPlayerHireToRole(source, businessId, roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    EditStoreEmployee(businessId, identifier, roleId)
end)

RegisterNetEvent("pickle_businesses:deleteEmployee", function(businessId, identifier)
    local source = source
    local business = Businesses[businessId]
    if not business or not identifier then return end
    local employee = GetBusinessEmployee(identifier, businessId)
    if not employee then return end
    if not CanPlayerHireToRole(source, businessId, employee.roleId) then
        ShowNotification(source, _L("no_permission"))
        return
    end
    RemoveStoreEmployee(businessId, identifier)
end)

RegisterNetEvent("pickle_businesses:saveSettings", function(businessId, settings)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "owner") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    SaveStoreSettings(businessId, settings)
    ShowNotification(source, _L("market_manage_settings_success"))
end)

RegisterNetEvent("pickle_businesses:balanceTransaction", function(businessId, action, currency, amount)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    if not DoesPlayerHaveStorePermission(source, businessId, "funds") then
        ShowNotification(source, _L("no_permission"))
        return
    end
    if IsAmountOverflowing(amount) then return end
    if currency == "money" then 
        currency = "cash" 
    elseif currency == "dirty_money" then
        currency = "dirtycash" 
    end
    if currency ~= "cash" and currency ~= "dirtycash" then
        ShowNotification(source, _L("invalid_payment_method"))
        return
    end
    local playerMoney = GetPaymentMethodAmount(source, currency)
    if action == "deposit" then
        if playerMoney < amount then
            ShowNotification(source, _L("not_enough_money", NumberWithCommas(amount), _L("money_" .. currency)))
            return
        end
        SendBusinessWebhook(businessId, "business", {
            type = "add_funds",
            fundingType = _L("market_" .. currency),
            amount = amount,
            timestamp = GetDateTime()
        })
        ShowNotification(source, _L("market_manage_deposit_success", NumberWithCommas(amount), _L("money_" .. currency)))
        if ChargePaymentMethod(source,currency,amount)~=true then return end
        AddStoreFunds(businessId,currency,amount)
    elseif action == "withdraw" then
        local businessMoney = GetStoreFunds(businessId, currency)
        if businessMoney < amount then
            ShowNotification(source, _L("not_enough_money", NumberWithCommas(amount), _L("money_" .. currency)))
            return
        end
        SendBusinessWebhook(businessId, "business", {
            type = "remove_funds",
            fundingType = _L("market_" .. currency),
            amount = amount,
            timestamp = GetDateTime()
        })
        ShowNotification(source, _L("market_manage_withdraw_success", NumberWithCommas(amount), _L("money_" .. currency)))
        RemoveStoreFunds(businessId, currency, amount)
        if AddPaymentMethodAmount(source,currency,amount)~=true then AddStoreFunds(businessId,currency,amount) end
    end
end)

RegisterNetEvent("pickle_businesses:placeMarket", function(marketType, coords, rotation)
    local source = source
    local market = Config.PlaceableMarkets[marketType]
    if not market then return end
    local count = Inventory.GetItemCount(source, marketType)
    if count < 1 then return end
    if Inventory.RemoveItem(source,marketType,1)~=true then return end
    local businessData = {
        owner = GetIdentifier(source),
        price = 0,
        rent = 0,
        zone = market.zone,
        game_info = {
            placed = true,
            bounds = {},
            locations = {
                {
                    type = "market",
                    model = market.model,
                    coords = coords,
                    rotation = rotation
                }
            }
        },
    } 
    ShowNotification(source, _L("customize_market_created"))
    CreateBusiness(businessData, source)
end)

CreateThread(function()
    for k, v in pairs(Config.PlaceableMarkets) do
        RegisterUsableItem(k, function(source)
            TriggerClientEvent("pickle_businesses:placeMarket", source, k) 
        end)
    end
end)