BusinessLocks={}
function BusinessInt(n,min,max) return type(n)=='number' and n%1==0 and n>=min and n<=max end
function BusinessIdentity(src)
    if not GetPlayerName(src) then return end
    local ok,id=pcall(GetIdentifier,src); return ok and id or nil
end
function BusinessVector(v)
    if type(v)~='table' and type(v)~='vector3' then return false end
    for _,key in ipairs({'x','y','z'}) do local n=v[key]; if type(n)~='number' or n~=n or math.abs(n)>20000 then return false end end
    return true
end
function BusinessNear(src,id,radius)
    local b=Businesses and Businesses[id]; local ped=GetPlayerPed(src)
    if not b or ped==0 then return false end
    for _,location in ipairs(b.game_info.locations or {}) do
        if BusinessVector(location.coords) and #(GetEntityCoords(ped)-vector3(location.coords.x,location.coords.y,location.coords.z))<=(radius or 20) then return true end
    end
    return false
end
local function safe(value,depth,budget)
    local t=type(value)
    if t=='number' then return value==value and math.abs(value)<=2147483647 end
    if t=='string' then return #value<=2048 and not value:find('[<>%z]') end
    if t=='nil' or t=='boolean' then return true end
    if t=='vector3' or t=='vector4' then return true end
    if t~='table' or depth>8 then return false end
    for k,v in pairs(value) do
        budget.n=budget.n+1
        if budget.n>1500 or not safe(k,depth+1,budget) or not safe(v,depth+1,budget) then return false end
    end
    return true
end
function BusinessSQLExecute(query,params,cb)
    local rows=MySQL.Sync.execute(query,params)
    if type(rows)~='number' then error('Business SQL mutation failed') end
    if cb then cb(rows) end
    return rows
end
local rate={}
local function guarded(name,fn,src,...)
    if not BusinessIdentity(src) then return false end
    local args=table.pack(...)
    if not safe(args,0,{n=0}) then return false end
    local now=GetGameTimer(); local rateKey=src..':'..name
    if rate[rateKey] and now-rate[rateKey]<250 then return false end
    rate[rateKey]=now
    local id=args[1]; local b=Businesses and Businesses[id]
    if b and name~='pickle_businesses:purchaseSupply' and not BusinessNear(src,id,100) and not CanAdministrateBusinesses(src) then return false end
    if name=='pickle_businesses:purchaseBusiness' then
        if not b or b.owner or (args[2]~='purchase' and args[2]~='rent') then return false end
        local price=args[2]=='purchase' and b.price or b.rent
        if not BusinessInt(price,1,2147483647) then return false end
    elseif name=='pickle_businesses:balanceTransaction' then
        if not BusinessInt(args[4],1,2147483647) then return false end
    elseif name=='pickle_businesses:addStoreListing' then
        if type(args[2])~='table' or not BusinessInt(args[3],0,2147483647) or not BusinessInt(args[4],1,1000000) then return false end
    elseif name=='pickle_businesses:editStoreListing' then
        if not BusinessInt(args[3],0,2147483647) or not BusinessInt(args[4],0,1000000) then return false end
    elseif name=='pickle_businesses:addTradeInventory' then
        if type(args[2])~='table' or not BusinessInt(args[3],1,1000000) then return false end
    elseif name=='pickle_businesses:editTradeInventory' then
        if not BusinessInt(args[3],0,1000000) then return false end
    elseif name=='pickle_businesses:placeMarket' then
        if not BusinessVector(args[2]) or not BusinessVector(args[3]) or #(GetEntityCoords(GetPlayerPed(src))-vector3(args[2].x,args[2].y,args[2].z))>5 then return false end
    elseif name=='pickle_businesses:customize:updateBusiness' then
        if not CanAdministrateBusinesses(src) then return false end
        if type(args[2])~='table' or type(args[2].bounds)~='table' or #args[2].bounds>100 then return false end
        for _,v in ipairs(args[2].bounds) do if not BusinessVector(v) then return false end end
    elseif name=='pickle_businesses:customize:updateLocation' then
        local loc=args[2]
        if type(loc)~='table' or not BusinessVector(loc.coords) or not BusinessVector(loc.rotation)
            or type(loc.type)~='string' or loc.model~=nil and type(loc.model)~='number' and type(loc.model)~='string' then return false end
        if not CanAdministrateBusinesses(src) and (not BusinessWithinBounds(id,loc.coords) or not BusinessModelAllowed(loc.model)) then return false end
        local _,old=GetBusinessLocation(id,loc.id)
        if old and old.type=='management' and not CanAdministrateBusinesses(src) then return false end
        if old and old.storageId and loc.type~='storage' and not BusinessStorageEmpty(old.storageId) then return false end
        if not loc.id and #b.game_info.locations>=Config.BusinessSettings.maxLocations then return false end
        if not CanAdministrateBusinesses(src) and (loc.type=='management' or not BusinessNear(src,id,20)) then return false end
    elseif name=='pickle_businesses:addEmployee' then
        if not BusinessInt(args[2],1,65535) or not GetPlayerName(args[2]) or not IsPlayerNearby(src,args[2]) then return false end
        if b.employees[BusinessIdentity(args[2])] then return false end
    elseif name=='pickle_businesses:editEmployee' then
        local employee=b and b.employees[args[2]]
        if not employee or b.owner==args[2] or not CanPlayerHireToRole(src,id,employee.roleId) then return false end
    elseif name=='pickle_businesses:sellBusiness' then
        if not b or not b.owner or b.owner~=BusinessIdentity(src) then return false end
    elseif name=='pickle_businesses:customize:deleteLocation' then
        local _,loc=GetBusinessLocation(id,args[2])
        if loc and loc.storageId and not BusinessStorageEmpty(loc.storageId) then return false end
    elseif name=='pickle_businesses:transferBusiness' then
        if not b or not b.owner or not BusinessEstateEmpty(id) or not BusinessInt(args[2],1,65535) or not IsPlayerNearby(src,args[2]) then return false end
        local accepted=lib.callback.await('pickle_businesses:acceptOwnership',args[2],b.label)
        if accepted~=true then return false end
    end
    local key=b and id or 'source:'..src
    if BusinessLocks[key] or BusinessLocks['player:'..src] then return false end
    BusinessLocks[key],BusinessLocks['player:'..src]=true,true
    local snapshot=b and json.encode(b)
    local result=table.pack(pcall(fn,src,table.unpack(args,1,args.n)))
    BusinessLocks[key],BusinessLocks['player:'..src]=nil,nil
    if not result[1] then
        if snapshot then Businesses[id]=json.decode(snapshot) end
        print('[pickle_businesses] '..name..' failed: '..tostring(result[2]))
        return false
    end
    return table.unpack(result,2,result.n)
end
local register=RegisterNetEvent
RegisterNetEvent=function(name,fn) register(name,function(...) local src=source; return guarded(name,function(_,...) return fn(...) end,src,...) end) end
local callback=lib.callback.register
lib.callback.register=function(name,fn) callback(name,function(src,...) return guarded(name,fn,src,...) end) end
AddEventHandler('playerDropped',function()
    local prefix=source..':'
    for k in pairs(rate) do if k:sub(1,#prefix)==prefix then rate[k]=nil end end
end)
local send=TriggerClientEvent
function BusinessView(src,b)
    if not b then return nil end
    local clone=json.decode(json.encode(b))
    if clone.game_info then clone.game_info.webhooks={} end
    if not CanAdministrateBusinesses(src) and not GetBusinessEmployee(src,'business_'..b.id) then
        clone.owner=b.owner and 'owned' or nil
        clone.employees={}; clone.roles={}; clone.money=0; clone.dirty_money=0
        clone.recent_sales={}; clone.recent_trades={}; clone.daily_sales={}; clone.trade_inventory={}
    end
    return clone
end
TriggerClientEvent=function(event,target,...)
    local args=table.pack(...)
    if event:sub(1,18)~='pickle_businesses:' then return send(event,target,...) end
    local function deliver(src)
        local id=args[1]
        local private=event:find('Employees') or event:find('Balance') or event:find('TradeInventory') or event:find('Roles')
        if private and Businesses[id] and not CanAdministrateBusinesses(src) and not GetBusinessEmployee(src,id) then return end
        if event=='pickle_businesses:updateBusiness' then
            if id then send(event,src,id,BusinessView(src,args[2])) else
                local view={}; for key,b in pairs(args[2] or {}) do view[key]=BusinessView(src,b) end
                send(event,src,nil,view)
            end
        elseif event=='pickle_businesses:updateBusinessSettings' and args[2] then
            local data=json.decode(json.encode(args[2])); if data.game_info then data.game_info.webhooks={} end
            send(event,src,id,data)
        elseif event=='pickle_businesses:updateBusinessOwner' then
            if Businesses[id] then send('pickle_businesses:updateBusiness',src,id,BusinessView(src,Businesses[id])) end
        else send(event,src,table.unpack(args,1,args.n)) end
    end
    if target==-1 then for _,id in ipairs(GetPlayers()) do deliver(tonumber(id)) end else deliver(target) end
end

function BusinessSQLInsert(query,params,cb)
    local id=MySQL.Sync.insert(query,params)
    if type(id)~='number' or id<1 then error('Business insert failed') end
    if cb then cb(id) end
    return id
end
