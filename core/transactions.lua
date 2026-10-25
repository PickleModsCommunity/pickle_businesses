function BusinessWebhookURL(url)
    return type(url)=='string' and (#url==0 or #url<=512 and url:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$')~=nil)
end
function BusinessDirtyAllowed(id)
    local b=Businesses[id]
    return b and DoesZoneAcceptDirtyCash and DoesZoneAcceptDirtyCash(b.zone)==true
end
function BusinessStorageEmpty(stash)
    if GetResourceState('ox_inventory')~='started' then return false end
    local ok,items=pcall(function() return exports.ox_inventory:GetInventoryItems(stash) end)
    return ok and type(items)=='table' and not next(items)
end
function BusinessEstateEmpty(id)
    local b=Businesses[id]
    if not b or b.money>0 or b.dirty_money>0 or #b.store_listings>0 or #b.trade_inventory>0 then return false end
    for _,e in pairs(b.employees) do if (e.pendingMoney or 0)>0 then return false end end
    for _,loc in ipairs(b.game_info.locations or {}) do if loc.storageId and not BusinessStorageEmpty(loc.storageId) then return false end end
    return true
end
local function metadataKey(meta)
    if type(meta)~='table' then return '' end
    local keys={}; for k in pairs(meta) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local parts={}
    for _,k in ipairs(keys) do parts[#parts+1]=json.encode(k)..':'..(type(meta[k])=='table' and metadataKey(meta[k]) or json.encode(meta[k])) end
    return table.concat(parts,'|')
end
function AddStoreTradeInventory(id,data)
    if not BusinessInt(data.quantity,1,1000000) then return false end
    local b=Businesses[id]
    for _,row in ipairs(b.trade_inventory) do
        if row.name==data.name and metadataKey(row.metadata)==metadataKey(data.metadata) then
            row.quantity=row.quantity+data.quantity; UpdateStoreTradeInventorySQL(id); return true
        end
    end
    b.trade_inventory[#b.trade_inventory+1]={name=data.name,metadata=data.metadata or {},quantity=data.quantity,sku=GenerateStoreTradeInventorySku(id)}
    UpdateStoreTradeInventorySQL(id)
    TriggerClientEvent('pickle_businesses:updateTradeInventory',-1,id,b.trade_inventory)
    return true
end
function RemoveStoreTradeInventoryQuantity(id,name,quantity)
    local inventory=Businesses[id].trade_inventory
    local left=quantity
    for i=#inventory,1,-1 do
        local row=inventory[i]
        if row.name==name and not next(row.metadata or {}) then
            local take=math.min(left,row.quantity); row.quantity=row.quantity-take; left=left-take
            if row.quantity==0 then table.remove(inventory,i) end
            if left==0 then break end
        end
    end
    if left~=0 then error('Trade stock reservation failed') end
    UpdateStoreTradeInventorySQL(id)
end
function GetStoreTradeInventoryItemCount(id,name)
    local count=0
    for _,row in ipairs(Businesses[id].trade_inventory) do if row.name==name and not next(row.metadata or {}) then count=count+row.quantity end end
    return count
end
function ProcessPlayerItemRemoval(src,id,itemInfo,quantity)
    local count,items=GetStackedItems(src,itemInfo)
    if not count or count<quantity then return false end
    local left=quantity; local taken={}
    for _,item in ipairs(items) do
        local n=math.min(left,item.count)
        if n>0 then
            if Inventory.RemoveItem(src,item.name,n,item.slot)~=true then
                for _,r in ipairs(taken) do Inventory.AddItem(src,r.item.name,r.count,r.item.metadata) end
                return false
            end
            taken[#taken+1]={item=item,count=n}; left=left-n
            if left==0 then return true end
        end
    end
    return false
end
function StartStoreTradeTransaction(src,id,sku)
    local _,trade=GetStoreTradeListingBySku(id,sku)
    if not trade or not IsStoreTradeListingValid(trade) or not BusinessNear(src,id,20)
        or not CanPlayerPerformTrade(src,id,sku) or not CanStorePerformTrade(id,sku) then return false end
    -- Name-only trade recipes are restricted to plain items; tagged items retain their own SKU.
    local available={}
    for _,item in ipairs(Inventory.GetInventory(src)) do
        if not next(item.metadata or {}) then
            available[item.name]=available[item.name] or {}; table.insert(available[item.name],item)
        end
    end
    for _,row in ipairs(trade.receive.items) do
        local count=0; for _,item in ipairs(available[row.name] or {}) do count=count+item.count end
        if count<row.quantity then return false end
    end
    for _,row in ipairs(trade.give.items) do if not Inventory.CanCarryItem(src,row.name,row.quantity) then return false end end
    local undo={}
    local function apply(action,rollback)
        if action()~=true then
            for i=#undo,1,-1 do pcall(undo[i]) end
            return false
        end
        undo[#undo+1]=rollback; return true
    end
    for _,row in ipairs(trade.receive.items) do
        local left=row.quantity
        for _,item in ipairs(available[row.name]) do
            local n=math.min(left,item.count)
            if n>0 then
                if not apply(function() return Inventory.RemoveItem(src,item.name,n,item.slot) end,function() Inventory.AddItem(src,item.name,n,item.metadata) end) then return false end
                left=left-n; if left==0 then break end
            end
        end
    end
    for _,row in ipairs(trade.receive.currencies) do
        if not apply(function() return ChargePaymentMethod(src,row.name,row.quantity) end,function() AddPaymentMethodAmount(src,row.name,row.quantity) end) then return false end
    end
    for _,row in ipairs(trade.give.items) do
        if not apply(function() return Inventory.AddItem(src,row.name,row.quantity) end,function() Inventory.RemoveItem(src,row.name,row.quantity) end) then return false end
    end
    for _,row in ipairs(trade.give.currencies) do
        if not apply(function() return AddPaymentMethodAmount(src,row.name,row.quantity) end,function() ChargePaymentMethod(src,row.name,row.quantity) end) then return false end
    end
    StoreTradeTransactionStore(id,sku)
    ShowNotification(src,_L('market_trade_success'))
    return true
end
function BusinessStorageAccess(src,stash)
    for id,b in pairs(Businesses) do for _,loc in ipairs(b.game_info.locations or {}) do
        if loc.storageId==stash then
            if not BusinessNear(src,id,5) then return false end
            if CanAdministrateBusinesses(src) or b.owner==BusinessIdentity(src) then return true end
            local employee=GetBusinessEmployee(src,id)
            if not employee then return false end
            local rank=GetStoreRoleIndex(id,employee.roleId)
            return rank and rank<=math.min(tonumber(loc.rank) or #b.roles,#b.roles)
        end
    end end
    return nil -- unrelated inventory
end
CreateThread(function()
    if GetResourceState('ox_inventory')~='started' then return end
    exports.ox_inventory:registerHook('openInventory',function(payload)
        local access=BusinessStorageAccess(payload.source,tostring(payload.inventoryId))
        return access~=false
    end)
    exports.ox_inventory:registerHook('swapItems',function(payload)
        local a=BusinessStorageAccess(payload.source,tostring(payload.fromInventory))
        local b=BusinessStorageAccess(payload.source,tostring(payload.toInventory))
        return a~=false and b~=false
    end)
end)

function GetListingItemInfo(src,listing)
    local count,items=0,{}
    for _,item in ipairs(Inventory.GetInventory(src)) do
        if item.name==listing.name and metadataKey(item.metadata)==metadataKey(listing.metadata) then count=count+item.count; items[#items+1]=item end
    end
    return count,items
end
local function takeMatching(src,listing,quantity)
    local count,items=GetListingItemInfo(src,listing)
    if count<quantity then return false end
    local left=quantity; local taken={}
    for _,item in ipairs(items) do
        local amount=math.min(left,item.count)
        if Inventory.RemoveItem(src,item.name,amount,item.slot)~=true then
            for _,r in ipairs(taken) do Inventory.AddItem(src,r.name,r.count,r.metadata) end
            return false
        end
        taken[#taken+1]={name=item.name,count=amount,metadata=item.metadata}; left=left-amount
        if left==0 then return true end
    end
    return false
end
function ProcessListingStockAddition(id,sku,price,amount,src)
    local _,listing=GetStoreListingBySku(id,sku)
    if not listing or not BusinessInt(amount,1,1000000) then return false end
    if src and not takeMatching(src,listing,amount) then return false end
    EditStoreListing(id,sku,price,listing.quantity+amount)
    return true
end
function ProcessTradeInventoryAddition(id,sku,amount,src)
    local _,listing=GetStoreTradeInventoryBySku(id,sku)
    if not listing or not BusinessInt(amount,1,1000000) then return false end
    if src and not takeMatching(src,listing,amount) then return false end
    EditStoreTradeInventory(id,sku,listing.quantity+amount)
    return true
end

local originalAdmin=CanAdministrateBusinesses
CanAdministrateBusinesses=function(src)
    if not BusinessIdentity(src) then return false end
    local ok,allowed=pcall(originalAdmin,src)
    return ok and allowed==true
end

function BusinessModelAllowed(model)
    if model==nil then return true end
    for _,cat in ipairs(Config.Furniture.categories) do for _,option in ipairs(cat.options) do if option.model==model then return true end end end
    return false
end
function BusinessWithinBounds(id,pos)
    local b=Businesses[id]; local points=b.game_info.bounds or {}
    if #points<3 then
        for _,loc in ipairs(b.game_info.locations or {}) do if #(vector3(pos.x,pos.y,pos.z)-vector3(loc.coords.x,loc.coords.y,loc.coords.z))<10 then return true end end
        return false
    end
    local inside=false; local j=#points
    for i=1,#points do
        local a,c=points[i],points[j]
        if (a.y>pos.y)~=(c.y>pos.y) and pos.x<(c.x-a.x)*(pos.y-a.y)/(c.y-a.y)+a.x then inside=not inside end
        j=i
    end
    return inside
end
function BusinessAtSupplier(src)
    local coords=GetEntityCoords(GetPlayerPed(src))
    for _,supplier in ipairs(Config.SupplyStores) do if #(coords-supplier.coords)<5 then return true end end
    return false
end
