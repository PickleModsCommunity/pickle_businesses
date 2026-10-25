Config = {}

Config.Debug = false
Config.FoodLicenseItem = nil -- Set to a real license item to require one for food-store ownership.

Config.Language = "en" -- Language to use.

Config.InteractDistance = 2.0

Config.RenderDistance = 40.0 -- Prop Display Radius.

Config.DisplayDistance = 2.0 -- Interact Radius

Config.ItemImageFolder = "nui://ox_inventory/web/images" -- Don't put a slash at the end.

Config.XPEnabled = false -- Enables the XP feature for adding and checking XP Levels.

Config.InventoryLimit = false -- If using ESX 1.1, this must be on if using a limit-based inventory.

Config.EnableTarget = true -- If true, this will use third-eye instead of pressing [E] to interact with crafting locations.

Config.MenuPosition = "top-right" -- 'top-left' or 'top-right' or 'bottom-left' or 'bottom-right' (ox_lib menu position)

Config.BusinessAdministration = {
    groups = { "command", "admin", "god" }, -- This gives players with a specific group the ability to create and manage existing businesses. Don't hand this out to just anyone.
    jobs = {} -- This gives players with a specific job the ability to create and manage existing businesses. Don't hand this out to just anyone.
}

Config.BusinessSettings = {
    rentCron = "0 */1 * * *", -- https://overextended.dev/ox_lib/Modules/Cron/Server for more info.
    salaryCron = "*/30 * * * *", -- https://overextended.dev/ox_lib/Modules/Cron/Server for more info.
    sellScale = 0.5, -- The multiplier to give back to the player when selling a business to the "state".
    maxLocations = 75, -- The maximum amount of locations a business can have.
    recentSalesCapacity = 10, -- How many recent sales to store.
}

Config.WebhookEvents = {
    business = function(businessId, business, log, url)
        local discordWebhook = url
        local embed
        if log.type == "hire_employee" then
            embed = {
                title = "New Employee",
                description = "A new employee has been hired!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Employee Name", value = log.employee },
                    { name = "Role", value = log.role },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "fire_employee" then
            embed = {
                title = "Employee Fired",
                description = "An employee has been fired!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Employee Name", value = log.employee },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "role_employee" then
            embed = {
                title = "Role Change",
                description = "An employee's role has been changed!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Employee Name", value = log.employee },
                    { name = "Role", value = log.role },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "add_role" then
            embed = {
                title = "New Role",
                description = "A new role has been added to the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Role", value = log.role },
                    { name = "Salary", value = NumberWithCommas(log.salary) },
                    { name = "Commission", value = log.commission .. "%" },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "edit_role" then
            embed = {
                title = "Role Updated",
                description = "A role has been updated in the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Role", value = log.role },
                    { name = "Salary", value = NumberWithCommas(log.salary) },
                    { name = "Commission", value = log.commission .. "%" },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "move_role" then
            embed = {
                title = "Role Moved",
                description = "A role has been moved in the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Role", value = log.role },
                    { name = "New Position", value = "#" .. log.position },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "remove_role" then
            embed = {
                title = "Role Removed",
                description = "A role has been removed from the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Role", value = log.role },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "add_funds" then
            embed = {
                title = "Funds Deposited",
                description = "Funds have been deposited to the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Funding Type", value = log.fundingType },
                    { name = "Amount", value = NumberWithCommas(log.amount) },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "remove_funds" then
            embed = {
                title = "Funds Withdrawn",
                description = "Funds have been withdrawn from the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Funding Type", value = log.fundingType },
                    { name = "Amount", value = NumberWithCommas(log.amount) },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "add_listing" then
            embed = {
                title = "New Listing",
                description = "A new listing has been added to the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Item", value = log.item },
                    { name = "Price", value = NumberWithCommas(log.price) },
                    { name = "Stock", value = log.stock },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "remove_listing" then
            embed = {
                title = "Listing Removed",
                description = "A listing has been removed from the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Item", value = log.item },
                    { name = "Stock", value = log.stock },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "update_listing" then
            embed = {
                title = "Listing Updated",
                description = "A listing has been updated in the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Item", value = log.item },
                    { name = "Price", value = NumberWithCommas(log.price) },
                    { name = "Stock", value = log.stock },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "add_trade_listing" then
            embed = {
                title = "New Trade Listing",
                description = "A new trade listing has been added to the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Offers", value = StringifyListings(log.offers.items) .. "\n" .. StringifyListings(log.offers.currencies, true) },
                    { name = "Demands", value = StringifyListings(log.demands.items) .. "\n" .. StringifyListings(log.demands.currencies, true) },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "remove_trade_listing" then
            embed = {
                title = "Trade Listing Removed",
                description = "A trade listing has been removed from the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Offers", value = StringifyListings(log.offers.items) .. "\n" .. StringifyListings(log.offers.currencies, true) },
                    { name = "Demands", value = StringifyListings(log.demands.items) .. "\n" .. StringifyListings(log.demands.currencies, true) },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        elseif log.type == "update_trade_listing" then
            embed = {
                title = "Trade Listing Updated",
                description = "A trade listing has been updated in the business!",
                color = 16711680, -- Red color
                fields = {
                    { name = "Business Name", value = business.label },
                    { name = "Offers", value = StringifyListings(log.offers.items) .. "\n" .. StringifyListings(log.offers.currencies, true) },
                    { name = "Demands", value = StringifyListings(log.demands.items) .. "\n" .. StringifyListings(log.demands.currencies, true) },
                    { name = "Timestamp", value = log.timestamp },
                }
            }
        end
        PerformHttpRequest(discordWebhook, function(err, text, headers)
            if err == 200 then
                print("Discord webhook sent successfully!")
            else
                print("Failed to send Discord webhook:", err)
            end
        end, "POST", json.encode({
            embeds = {
                embed
            }
        }), { ["Content-Type"] = "application/json" })
    end,
    purchase = function(businessId, business, log, url)
        local discordWebhook = url
        PerformHttpRequest(discordWebhook, function(err, text, headers)
            if err == 200 then
                print("Discord webhook sent successfully!")
            else
                print("Failed to send Discord webhook:", err)
            end
        end, "POST", json.encode({
            embeds = {
                {
                    title = "New Purchase",
                    description = "A new purchase has been made!",
                    color = 16711680, -- Red color
                    fields = {
                        { name = "Business Name", value = business.label },
                        { name = "Price", value = NumberWithCommas(log.price) },
                        { name = "Items", value = StringifyListings(log.items) },
                        { name = "Timestamp", value = log.timestamp },
                    }
                }
            }
        }), { ["Content-Type"] = "application/json" })
    end,
    trade = function(businessId, business, log, url)
        local discordWebhook = url
        PerformHttpRequest(discordWebhook, function(err, text, headers)
            if err == 200 then
                print("Discord webhook sent successfully!")
            else
                print("Failed to send Discord webhook:", err)
            end
        end, "POST", json.encode({
            embeds = {
                {
                    title = "New Trade",
                    description = "A new trade has been made!",
                    color = 16711680, -- Red color
                    fields = {
                        { name = "Business Name", value = business.label },
                        { name = "Offers", value = StringifyListings(log.offers.items) .. "\n" .. StringifyListings(log.offers.currencies, true) },
                        { name = "Demands", value = StringifyListings(log.demands.items) .. "\n" .. StringifyListings(log.demands.currencies, true) },
                        { name = "Timestamp", value = log.timestamp },
                    }
                }
            }
        }), { ["Content-Type"] = "application/json" })
    end,
}

Config.Furniture = {
    categories = {
        {
            label = "Chairs",
            icon = "chair",
            options = {
                { label = "Chair #1", model = `prop_off_chair_01` },
                { label = "Chair #2", model = `prop_off_chair_03` },
                { label = "Chair #3", model = `prop_off_chair_04` },
                { label = "Chair #4", model = `prop_off_chair_05` },
                { label = "Chair #6", model = `hei_heist_stn_chairstrip_01` },
                { label = "Chair #7", model = `ex_mp_h_stn_chairstrip_01` },
                { label = "Chair #8", model = `apa_mp_h_stn_chairstrip_08` },
                { label = "Chair #9", model = `apa_mp_h_stn_chairstrip_06` },
                { label = "Chair #10", model = `ex_mp_h_off_chairstrip_01` },
                { label = "Chair #11", model = `hei_heist_din_chair_01` },
                { label = "Chair #12", model = `hei_heist_din_chair_04` },
                { label = "Chair #13", model = `h4_prop_h4_weed_chair_01a` },
                { label = "Chair #14", model = `v_club_ch_briefchair` },
                { label = "Chair #15", model = `ba_prop_battle_club_chair_01` },
                { label = "Chair #16", model = `ba_prop_battle_club_chair_03` },
                { label = "Chair #17", model = `sm_prop_offchair_smug_01` },
                { label = "Chair #18", model = `xm_prop_x17_corp_offchair` },
                { label = "Chair #19", model = `apa_mp_h_din_stool_04` },
                { label = "Chair #20", model = `v_res_tre_officechair` },
            }
        },
        {
            label = "Tables",
            icon = "shop",
            options = {
                { label = "Table #1", model = `prop_table_04` },
                { label = "Table #2", model = `bkr_int_02_plan_table` },
                { label = "Table #3", model = `tr_int1_plan_table05` },
            }
        },
        {
            label = "tv",
            icon = "tv",
            options = {
                { label = "tv #1", model = `ch_prop_ch_cctv_wall_atta_01a` },
                { label = "tv #2", model = `xs_x18intmod_office_tv_stand` },
                { label = "tv #3", model = `prop_tv_flat_02b` },
                { label = "tv #4", model = `prop_cs_tv_stand` },
                { label = "tv #5", model = `m24_1_prop_m24_1_carrier_bank_cctv_02` },
                { label = "tv #6", model = `prop_tv_flat_02` },
                { label = "tv #7", model = `xs_prop_arena_screen_tv_01` },
            }
        },
        {
            label = "electronics",
            icon = "shop",
            options = {
                { label = "electronics #1", model = `ba_prop_battle_club_computer_01` },
                { label = "electronics #2", model = `bkr_ware05_pcupgrade2` },
                { label = "electronics #3", model = `prop_pc_02a` },
                { label = "electronics #4", model = `v_res_pctower` },
                { label = "electronics #5", model = `bkr_ware05_pclatopbasic2` },
                { label = "electronics #6", model = `bkr_prop_clubhouse_laptop_01b` },
            }
        },
        {
            label = "shelving",
            icon = "shop",
            options = {
                { label = "shelving #1", model = `ch_chint02_flat_shelving` },
                { label = "shelving #2", model = `ch_chint02_office_shelving` },
                { label = "shelving #3", model = `ch_prop_ch_laundry_shelving_01b` },
                { label = "shelving #4", model = `ch_prop_ch_laundry_shelving_01c` },
            }
        },
        {
            label = "clothing",
            icon = "shop",
            options = {
                { label = "clothing #1", model = `prop_sglasses_stand_02b` },
                { label = "shelving #2", model = `prop_bikini_disp_01` },
                { label = "shelving #3", model = `prop_bikini_disp_04` },
                { label = "shelving #4", model = `prop_dress_disp_02` },
            }
        },
        {
            label = "till",
            icon = "shop",
            options = {
                { label = "till #1", model = `prop_till_03` },
                { label = "till #2", model = `prop_till_01` },
                { label = "till #3", model = `prop_till_02` },
                { label = "till #4", model = `vw_prop_casino_till` },
                { label = "till #5", model = `ch_prop_casino_till_01a` },
                { label = "till #6", model = `v_53_till` },
            }
        },
        {
            label = "counter",
            icon = "shop",
            options = {
                { label = "counter #1", model = `prop_ff_counter_03` },
                { label = "counter #2", model = `prop_ff_counter_02` },
                { label = "counter #3", model = `ch_chint02_counter` },
                { label = "counter #4", model = `p_new_j_counter_01` },
                { label = "counter #5", model = `p_new_j_counter_02` },
            }
        },
        {
            label = "24-7",
            icon = "shop",
            options = {
                { label = "24-7 #1", model = `v_ret_247_cereal1` },
                { label = "24-7 #2", model = `v_ret_247_vegsoup1` },
                { label = "24-7 #3", model = `v_ret_247_popcan2` },
                { label = "24-7 #4", model = `v_ret_247_soappowder2` },
                { label = "24-7 #5", model = `v_ret_247_popbot4` },
                { label = "24-7 #6", model = `v_ret_247_bread1` },
                { label = "24-7 #6", model = `v_ret_247shelves01` },
                { label = "24-7 #7", model = `v_ret_247shelves02` },
                { label = "24-7 #8", model = `v_ret_247shelves03` },
                { label = "24-7 #9", model = `v_ret_247shelves04` },
                { label = "24-7 #10", model = `v_ret_247shelves05` },
                { label = "24-7 #11", model = `v_ret_247_donuts` },
                { label = "24-7 #12", model = `v_ret_247_lottery` },
                { label = "24-7 #13", model = `prop_ven_shop_1_counter` },
                { label = "24-7 #14", model = `prop_ff_counter_01` },
                { label = "24-7 #15", model = `v_med_bench2` },
                { label = "24-7 #16", model = `v_med_bench1` },
                { label = "24-7 #17", model = `prop_fib_counter` },
            }
        },
        {
            label = "cctv",
            icon = "shop",
            options = {
                { label = "cctv #1", model = `prop_dest_cctv_03b` },
                { label = "cctv #2", model = `prop_cctv_cont_05` },
                { label = "cctv #3", model = `prop_cctv_cont_03` },
                { label = "cctv #4", model = `prop_cs_cctv` },
                { label = "cctv #5", model = `prop_cctv_cont_02` },
                { label = "cctv #6", model = `prop_cctv_cam_04a` },
                { label = "cctv #7", model = `prop_cctv_cam_06a` },
                { label = "cctv #8", model = `prop_cctv_cam_01a` },
                { label = "cctv #9", model = `prop_cctv_cam_01b` },
                { label = "cctv #10", model = `tr_prop_tr_camhedz_cctv_01a` },
            }
        },
        {
            label = "mechanic",
            icon = "shop",
            options = {
                { label = "mechanic #1", model = `tr_int1_tool_draw_01d005` },
                { label = "clothing #2", model = `tr_int1_smod_toolchest9` },
            }
        },
        {
            label = "sign",
            icon = "shop",
            options = {
                { label = "sign #1", model = `ch_chint02_degenatron_neon` },
                { label = "sign #2", model = `v_15_shrm_neonsign` },
                { label = "sign #3", model = `prop_beer_neon_02` },
                { label = "sign #4", model = `prop_ragganeon` },
                { label = "sign #5", model = `sf_prop_sf_sign_neon_01a` },
                { label = "sign #6", model = `prop_cherenneon` },
                { label = "sign #7", model = `prop_beer_neon_01` },
                { label = "sign #8", model = `prop_beer_neon_03` },
                { label = "sign #9", model = `prop_loggneon` },
                { label = "sign #10", model = `prop_patriotneon` },
                { label = "sign #11", model = `prop_barrachneon` },
                { label = "sign #12", model = `tr_int1_mod_neontubes_blue` },
                { label = "sign #13", model = `ch_chint07_neon_icons01` },
                { label = "sign #14", model = `v_ret_neon_logger` },
                { label = "sign #15", model = `prop_cockneon` },
                { label = "sign #16", model = `prop_beer_neon_04` },
                { label = "sign #17", model = `ch_chint07_neon_icons04` },
                { label = "sign #18", model = `v_4_backneon` },
                { label = "sign #19", model = `v_19_vanillasigneon2` },
                { label = "sign #20", model = `v_ret_neon_blarneys` },
                { label = "sign #21", model = `prop_beerneon` },
                { label = "sign #22", model = `v_ret_neon_baracho` },
                { label = "sign #23", model = `ch_chint02_vinewood_neon` },

            }
        },
        {
            label = "Poster",
            icon = "shop",
            options = {
                { label = "Poster #1", model = `m23_1_prop_m31_poster_skin_01` },
                { label = "poster #2", model = `ba_prop_battle_poster_skin_01` },
                { label = "poster #3", model = `m23_2_prop_m32_poster_01a` },
                { label = "poster #4", model = `h4_prop_battle_poster_skin_03` },
                { label = "poster #5", model = `ba_prop_battle_poster_skin_02` },
                { label = "poster #6", model = `sum_prop_ac_qub3d_poster_01a` },
                { label = "poster #7", model = `ba_prop_battle_poster_skin_04` },
                { label = "poster #8", model = `ba_maisn_poster` },

            }
        },
        {
            label = "Kitchen",
            icon = "shop",
            options = {
                { label = "Kitchen #1", model = `v_res_fridgemoda` },
                { label = "Kitchen #2", model = `prop_ff_sink_02` },
                { label = "Kitchen #3", model = `prop_cooker_03` },
                { label = "Kitchen #4", model = `v_med_lab_fridge` },
                { label = "Kitchen #5", model = `prop_bar_beerfridge_01` },
                { label = "Kitchen #6", model = `prop_bar_fridge_02` },
                { label = "Kitchen #7", model = `ba_prop_battle_bar_fridge_01` },
                { label = "Kitchen #8", model = `prop_foodprocess_01` },
                { label = "Kitchen #9", model = `prop_chip_fryer` },
                { label = "Kitchen #10", model = `prop_food_cb_bshelf` },
                { label = "Kitchen #11", model = `prop_food_cb_bshelf` },
                { label = "Kitchen #12", model = `prop_bread_rack_02` },
                { label = "Kitchen #13", model = `v_med_benchcentr` },
                { label = "Kitchen #14", model = `v_med_metalfume` },
            }
        },
        {
            label = "BurgerShot",
            icon = "shop",
            options = {
                { label = "BurgerShot #1", model = `prop_food_bs_tray_03` },
                { label = "BurgerShot #2", model = `prop_food_bs_tray_02` },
                { label = "BurgerShot #3", model = `prop_cs_burger_01` },
                { label = "BurgerShot #4", model = `prop_cs_hotdog_01` },
                { label = "BurgerShot #5", model = `prop_food_cb_tray_01` },
                { label = "BurgerShot #6", model = `prop_food_napkin_02` },
                { label = "BurgerShot #7", model = `prop_food_bs_cups01` },
                { label = "BurgerShot #8", model = `prop_foodprocess_01` },
                { label = "BurgerShot #9", model = `prop_cs_ice_locker` },

            }
        },
    }
}

Config.Actions = {
    ["cook"] = function(data)
        local playerPed = PlayerPedId()
        local coords = data.coords
        local pcoords = GetEntityCoords(playerPed)
        local calcHeading = GetHeadingFromCoords(coords, pcoords)
        local object = CreateProp(`prop_fish_slice_01`, coords.x, coords.y, coords.z, true, false, false)
        AttachEntityToEntity(object, playerPed, GetPedBoneIndex(playerPed, 57005), 0.1, 0.05, -0.025, 0.0, 0.0, 150.0, false, false, false, false, 2, true)
        SetEntityHeading(playerPed, calcHeading)
        PlayAnim(playerPed, "amb@prop_human_bbq@male@base", "base", 8.0, -8.0, -1, 49, 0, false, false, false)
        lib.progressBar({ duration = 5000, label = 'Cooking ' .. GetItemLabel(data.craftingItem.name) .. "..."})
        DeleteEntity(object)
        ClearPedTasks(playerPed)
        return true
    end,
    ["dispense_drink"] = function(data)
        local playerPed = PlayerPedId()
        local coords = data.coords
        local pcoords = GetEntityCoords(playerPed)
        local calcHeading = GetHeadingFromCoords(coords, pcoords)
        SetEntityHeading(playerPed, calcHeading)
        PlayAnim(playerPed, "amb@prop_human_bbq@male@base", "base", 8.0, -8.0, -1, 49, 0, false, false, false)
        lib.progressBar({ duration = 5000, label = 'Cooking ' .. GetItemLabel(data.craftingItem.name) .. "..."})
        ClearPedTasks(playerPed)
        return true
    end,
}

Config.Crafting = {
    timeoutTime = 120, -- The amount of seconds to wait before removing a player's crafting status if they haven't finished. (Player disconnects, etc.)
}

Config.Storage = {
    slots = 50, -- The amount of slots a storage location can hold.
    maxWeight = 10000, -- The maximum weight a storage location can hold.
}

Config.SupplyStores = {
    {
        coords = vector3(55.1603, -1739.1967, 28.5928),
        heading = 54.9914,
        model = { modelType = "ped", hash = "s_m_m_linecook" },
        zones = {}, -- Leave this empty to allow all business zones to access their supply store here.
    },
}

Config.DefaultCallbacks = { -- If undefined in zone.callbacks, these will be used.
    ownerCheck = function(source, businessId, ownershipType, price)
        -- Add checks for licenses, etc. Whatever you want!
        return true
    end,
    postOwner = function(source, businessId, ownershipType, price)
        -- Add checks for licenses, etc. Whatever you want!
    end,
    purchaseCheck = function(source, businessId, cart, price)
        -- Add checks for licenses, etc. Whatever you want!
        return true
    end,
    postPurchase = function(source, businessId, cart, price)
        -- Add checks for licenses, etc. Whatever you want!
    end,
}

Config.PlaceableMarkets = { -- This is where you can create placeable market items.
    ["food_trailer_1"] = { -- ["item_name"] = { ... } 
        model = `prop_food_van_02`, -- The model to display at the market location.
        zone = "food_store", -- The business zone to associate this with (Config.BusinessZones).
    },
    ["food_trailer_2"] = { -- ["item_name"] = { ... } 
        model = `prop_food_van_01`, -- The model to display at the market location.
        zone = "food_store", -- The business zone to associate this with (Config.BusinessZones).
    },
}

Config.InteractOffsetModels = { -- These are used for placeable markets that have an abnormal offset, add more as needed.
    [`prop_food_van_01`] = vector3(0.0, 0.0, 1.5),
    [`prop_food_van_02`] = vector3(0.0, 0.0, 1.5),
    
}

Config.BusinessZones = { -- This is where you can create business types, which give access to zone-specific supplies and craftables.
    {
        name = "food_store", -- Set unique to other business zones.
        label = "Food Store",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                local itemCount = Config.FoodLicenseItem and Inventory.GetItemCount(source,Config.FoodLicenseItem) or 1
                if not itemCount or itemCount < 1 then
                    ShowNotification(source, "You need a food store license to purchase items from here.")
                    return false
                end
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "syrup_mix",
                count = 1,
                price = 10
            },
            {
                name = "carbonated_water",
                count = 1,
                price = 10
            },
            {
                name = "burger_bun",
                count = 1,
                price = 10
            },
            {
                name = "hotdog_bun",
                count = 1,
                price = 10
            },
            {
                name = "burger_patty",
                count = 1,
                price = 10
            },
            {
                name = "sausage",
                count = 1,
                price = 10
            },
            {
                name = "lettuce",
                count = 2,
                price = 20
            },
            {
                name = "tomato",
                count = 2,
                price = 20
            },
            {
                name = "potato",
                count = 2,
                price = 20
            },
            {
                name = "special_seasoning",
                count = 2,
                price = 20
            },
        },
        craftingTypes = {
            {
                name = "food", -- Set unique to other crafting types in this zone.
                label = "Cook Food",
                craftableItems = {
                    {
                        name = "burger", count = 1,
                        required = {
                            {name = "burger_bun", count = 1},
                            {name = "burger_patty", count = 1},
                            {name = "lettuce", count = 1},
                            {name = "tomato", count = 1},
                        },
                        action = "cook"
                    },
                    {
                        name = "fries", count = 1,
                        required = {
                            {name = "potato", count = 1},
                            {name = "special_seasoning", count = 1},
                        },
                        action = "cook"
                    },
                    {
                        name = "hotdog", count = 1,
                        required = {
                            {name = "hotdog_bun", count = 1},
                            {name = "sausage", count = 1},
                        },
                        action = "cook"
                    },
                }
            },
            {
                name = "drink", -- Set unique to other crafting types in this zone.
                label = "Dispense Drink",
                craftableItems = {
                    {
                        name = "sprunk",
                        count = 1,
                        required = {
                            {name = "syrup_mix", count = 1},
                            {name = "carbonated_water", count = 1},
                        },
                        action = "dispense_drink"
                    },
                    {
                        name = "ecola",
                        count = 1,
                        required = {
                            {name = "syrup_mix", count = 1},
                            {name = "carbonated_water", count = 1},
                        },
                        action = "dispense_drink"
                    },
                    {
                        name = "ecolalight",
                        count = 1,
                        required = {
                            {name = "syrup_mix", count = 1},
                            {name = "carbonated_water", count = 1},
                        },
                        action = "dispense_drink"
                    },
                }
            }
        }
    },
    --[[ -- Examples below.
        {
        name = "ls_firearms_and_supplies.",
        label = "LS Firearms and supplies.",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "WEAPON_BULLPUPSHOTGUN",
                count = 1,
                price = 300
            },
            {
                name = "WEAPON_BZGAS",
                count = 1,
                price = 800
            },
            {
                name = "WEAPON_CARBINERIFLE",
                count = 1,
                price = 50
            }
        },
        craftingTypes = {
            {
                name = "repair",
                label = "Repair Electronics",
                craftableItems = {
                    { name = "repaired_CARBINERIFLE", count = 1, required = { {name = "wood", count = 1} }, action = "repair" },
                    { name = "repaired_BZGAS", count = 1, required = { {name = "wood", count = 1} }, action = "repair" },
                }
            }
        }
    },
    {
        name = "electronics_store",
        label = "Electronics Store",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "smartphone",
                count = 1,
                price = 300
            },
            {
                name = "laptop",
                count = 1,
                price = 800
            },
            {
                name = "headphones",
                count = 1,
                price = 50
            }
        },
        craftingTypes = {
            {
                name = "repair",
                label = "Repair Electronics",
                craftableItems = {
                    { name = "repaired_smartphone", count = 1, required = { {name = "smartphone", count = 1} }, action = "repair" },
                    { name = "repaired_laptop", count = 1, required = { {name = "laptop", count = 1} }, action = "repair" },
                }
            }
        }
    },
    --]]
    --[[
    {
        name = "pharmacy",
        label = "Pharmacy",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "painkiller",
                count = 1,
                price = 10
            },
            {
                name = "antibiotic",
                count = 1,
                price = 25
            },
            {
                name = "bandage",
                count = 5,
                price = 5
            }
        },
        craftingTypes = {
            {
                name = "medication",
                label = "Prepare Medications",
                craftableItems = {
                    { name = "custom_painkiller", count = 1, required = { {name = "painkiller", count = 1} }, action = "prepare" },
                }
            }
        }
    },
    --]]
    --[[
    {
        name = "jewelry_store",
        label = "Jewelry Store",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "necklace",
                count = 1,
                price = 200
            },
            {
                name = "ring",
                count = 1,
                price = 150
            },
            {
                name = "bracelet",
                count = 1,
                price = 100
            }
        },
        craftingTypes = {
            {
                name = "custom_jewelry",
                label = "Custom Jewelry",
                craftableItems = {
                    { name = "custom_necklace", count = 1, required = { {name = "necklace", count = 1} }, action = "customize" },
                    { name = "custom_ring", count = 1, required = { {name = "ring", count = 1} }, action = "customize" },
                }
            }
        }
    },
    --]]
    --[[
    {
        name = "auto_parts_store",
        label = "Auto Parts Store",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "engine_oil",
                count = 1,
                price = 30
            },
            {
                name = "tire",
                count = 1,
                price = 80
            },
            {
                name = "battery",
                count = 1,
                price = 120
            }
        },
        craftingTypes = {
            {
                name = "custom_parts",
                label = "Custom Auto Parts",
                craftableItems = {
                    { name = "high_performance_tire", count = 1, required = { {name = "tire", count = 1} }, action = "upgrade" },
                }
            }
        }
    },
    --]]
    --[[
    {
        name = "bakery",
        label = "Bakery",
        callbacks = {
            ownerCheck = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postOwner = function(source, businessId, purchaseType, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
            purchaseCheck = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
                return true
            end,
            postPurchase = function(source, businessId, cart, price)
                -- Add checks for licenses, etc. Whatever you want!
            end,
        },
        supplies = {
            {
                name = "bread",
                count = 1,
                price = 5
            },
            {
                name = "cake",
                count = 1,
                price = 20
            },
            {
                name = "cookies",
                count = 1,
                price = 10
            }
        },
        craftingTypes = {
            {
                name = "bake_goods",
                label = "Bake Goods",
                craftableItems = {
                    { name = "custom_cake", count = 1, required = { {name = "cake", count = 1} }, action = "decorate" },
                    { name = "custom_bread", count = 1, required = { {name = "bread", count = 1} }, action = "season" },
                }
            }
        }
    }
    --]]
}