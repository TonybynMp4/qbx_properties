if not Config.useProperties then return end
local propertyZones = {}
local interiorZones = {}
local isInZone = false
local inSelection = false

--#region Functions

--- Create the zones inside the property
---@param IPL any
---@param customZones any
local function createPropertyInteriorZones(IPL, customZones)
    --[[   coords = {
            entrance = vector4(-271.87, -940.34, 92.51, 70),
            wardrobe = vector4(-277.79, -960.54, 86.31, 70),
            stash = vector4(-272.98, -950.01, 92.52, 70),
            logout = vector3(-283.27, -959.68, 70),
        }
     ]]
    InteriorZones[#InteriorZones+1] = lib.points.new({
        coords = customZones.entrance.xyz or IPL.coords.entrance.xyz,
        distance = 15,
    })

    InteriorZones[#InteriorZones+1] = lib.points.new({
        coords = customZones.wardrobe.xyz or IPL.coords.wardrobe.xyz,
        distance = 15,
    })

    InteriorZones[#InteriorZones+1] = lib.points.new({
        coords = customZones.stash.xyz or IPL.coords.stash.xyz,
        distance = 15,
    })

    InteriorZones[#InteriorZones+1] = lib.points.new({
        coords = customZones.logout.xyz or IPL.coords.logout.xyz,
        distance = 15,
    })
end

local function calcPrice(price, taxes)
    local totaltax = Config.Properties.taxes.general
    if taxes then
        for taxname, tax in pairs(Config.Properties.taxes) do
            if taxes[taxname] then
                totaltax = totaltax + tax
            end
        end
    end
    return math.floor(price + (price * (totaltax/100)))
end

--- Get the list of applied taxes if any
---@param taxes table | nil
---@return table | nil
local function getAppliedTaxesList(taxes)
    if not taxes then return nil end
    local appliedTaxes = {}
    for _, v in pairs(taxes) do
        appliedTaxes[v] = Config.Properties.taxes[v]
    end
    return appliedTaxes
end

--- Create a list of interiors
--- @param Garage boolean
--- @param Furnished boolean
--- @return table
local function createInteriorsList(Garage, Furnished)
    local options = {}
    for k,v in pairs((Garage and Config.GarageIPLs) or (Furnished and Config.IPLS) or Config.Shells) do
        options[#options+1] = {}
        options[#options].label = Garage and Lang:t('create_property_menu.interior_label_garage', {interior = k, slots = #v.coords?.slots}) or Lang:t('create_property_menu.interior_label', {interior = k})
        options[#options].value = k
    end
    return options
end

--- Get the list of taxes
--- return table
local function getTaxesList()
    local taxes = {}
    for k, _ in pairs(Config.Properties.taxes) do
        if k ~= 'general' then
            taxes[#taxes + 1] = {
                label = k,
                value = k
            }
        end
    end
    return taxes
end

local function showSelectionScaleform(scaleform, action)
    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()

    for i, data in ipairs({
        {GetControlInstructionalButton(0, 38, true), Lang:t("selection.action", {action = action})},
        {GetControlInstructionalButton(0, 120, true), Lang:t("selection.cancel")},
        {GetControlInstructionalButton(0, 44, true), Lang:t("selection.nextPlayer")}
    }) do
        PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(i - 1)
        PushScaleformMovieFunctionParameterString(data[1])
        PushScaleformMovieFunctionParameterString(data[2])
        PopScaleformMovieFunctionVoid()
    end

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PushScaleformMovieFunctionParameterInt(0)
    PopScaleformMovieFunctionVoid()
    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
end

--- Start the player selection and return the selected player
---@param players table
---@param callback function
local function selectPlayer(players, action, callback)
    inSelection = true
    local playerNumber = 1
    local scaleform = lib.requestScaleformMovie("instructional_buttons", 10000)
    CreateThread(function()
        while true do
            Wait(0)
            showSelectionScaleform(scaleform, action)
            local player = players[playerNumber]
            local playerPed = player.ped
            local playerCoords = GetEntityCoords(playerPed)
            DrawMarker(2, playerCoords.x, playerCoords.y, playerCoords.z + 1.1, 0, 0, 0, 180, 0, 0, 0.25, 0.25, 0.25, 255, 50, 50, 255, true, true, 2, false, nil, nil, false)
            if IsControlJustPressed(0, 38) then -- E
                inSelection = false
                callback(player)
                break
            elseif IsControlJustPressed(0, 120) then -- X
                inSelection = false
                QBCore.Functions.Notify(Lang:t("error.cancelled"), 'error', 7500)
                break
            elseif IsControlJustPressed(0, 44) then -- Q (A on AZERTY)
                if playerNumber >= #players then
                    playerNumber = 1
                else
                    playerNumber = playerNumber + 1
                end
            end
        end
    end)
end

--- Sell the property to a player
---@param propertyData table
local function sellToPlayer(propertyData)
    local input = lib.inputDialog('Property Creator', {
        {
            type = 'slider',
            label = 'Commission %',
            default = Config.Properties.realtorCommission.default,
            min = Config.Properties.realtorCommission.min,
            max = Config.Properties.realtorCommission.max,
            step = 0.5,
            required = true,
            icon = 'percent'
        },
    }, { allowCancel = true })
    if not input then return end
    local comission = input[1]

    local players = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 10, true)
    if not players then
        QBCore.Functions.Notify(Lang:t('error.players_nearby'), 'error', 7500)
        return
    end

    selectPlayer(players, "Sell", function(player)
        TriggerServerEvent('qbx-property:server:sellProperty', GetPlayerServerId(player.id), propertyData.id, comission)
    end)
end

--- Rent (or extends the rent) the property to a player
--- @param propertyData table
--- @param isExtend boolean
local function rentToPlayer(propertyData, isExtend)
    local players = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 10, true)
    if not players then
        QBCore.Functions.Notify(Lang:t('error.players_nearby'), 'error', 7500)
        return
    end

    selectPlayer(players, "Rent", function(player)
        TriggerServerEvent('qbx-property:server:rentProperty', GetPlayerServerId(player.id), propertyData.id, isExtend)
    end)
end

--- Get a string of all taxes applied to a property
---@param taxes table
---@return string
local function getTaxesString(taxes)
    if not taxes or not next(taxes) then return Lang:t('general.none') end
    local str = ""
    for k, _ in pairs(taxes) do
        str = str .. k .. ", "
    end
    return string.sub(str, 1, -3)
end

--- Modify the property's characteristics
---@param propertyData table
local function modifyProperty(propertyData)
    local newData = {}
    local options = {
        {label = Lang:t('modify_property_menu.name', {name = propertyData.name}), args = { action = "name" }, close = true},
        {label = Lang:t('modify_property_menu.price', {price = propertyData.price}), args = { action = "price" }, close = true},
        {label = Lang:t('modify_property_menu.rent', {price = propertyData.rent}), args = { action = "rent" }, close = true},
        {label = Lang:t('modify_property_menu.property_type', {property_type = Lang:t('general.'..propertyData.property_type)}), close = false},
        {label = Lang:t('modify_property_menu.interior', {interior = propertyData.interior}), args = { action = "interior" }, close = true},
    }

    if propertyData.property_type ~= 'garage' then
        options[#options+1] = {label = Lang:t('modify_property_menu.storage.slots', {value = propertyData.slots or 0}), args = { action = "slots" }, close = true}
        options[#options+1] = {label = Lang:t('modify_property_menu.storage.maxweight', {value = propertyData.maxweight/1000}), args = { action = "maxweight" }, close = true}
    end
    if Config.Properties.useTaxes then
        options[#options+1] = {label = Lang:t('modify_property_menu.taxes', {taxes = getTaxesString(propertyData.appliedtaxes)}), args = { action = "taxes" }, close = true}
    end
    options[#options+1] = {label = Lang:t('modify_property_menu.coords'), args = { action = "coords" }, close = true}
    options[#options+1] = {label = Lang:t('modify_property_menu.done'), args = { action = "done" }, close = true}

    local point = lib.points.new({
        coords = propertyData.coords.xyz,
        heading = propertyData.coords.w,
        distance = 15,
    })

    function point:nearby()
        if not self then return end
        if not self.currentDistance then return end
        DrawMarker(26,
            self.coords.x, self.coords.y, self.coords.z + Config.Properties.marker.offsetZ, -- coords
            0.0, 0.0, 0.0, -- direction?
            0.0, 0.0, self.heading, -- rotation
            1,1,1, -- scale
            255, 50, 50, 255, -- color RBGA
            false, false, 2, false, nil, nil, false
        )
    end

    lib.registerMenu({
        id = 'modify_property_menu',
        title = Lang:t('modify_property_menu.title'),
        position = 'top-left',
        options = options,
    }, function(selected, scrollIndex, args)
        if not args then return end
        if args.action == "name" then
            local propertyString = string.split(propertyData.name, ' ')
            local propertyNumber = tonumber(propertyString[1])
            local input = lib.inputDialog(Lang:t('modify_property_menu.title'), {
                {type = 'input', label = Lang:t('modify_property_menu.name', {name = propertyData.name}), default = table.concat(propertyString, ' ', 2), required = true},
            }, {allowCancel = true})

            if input then
                newData.name = propertyNumber .. " " .. input[1]
                lib.setMenuOptions('modify_property_menu', {label = Lang:t('modify_property_menu.name', {name = newData.name})}, 1)
            end
        elseif args.action == "price" or args.action == "rent" then
            local price = newData[args.action] or propertyData[args.action]
            local input = lib.inputDialog(Lang:t('modify_property_menu.title'), {
                {type = 'input', label = Lang:t('modify_property_menu.'..args.action, {price = price}), default = price, required = true},
            }, {allowCancel = true})

            if input then
                newData[args.action] = tonumber(input[1])
                local newOptions = options[args.action == "price" and 2 or 3]
                newOptions.label = Lang:t('modify_property_menu.'..args.action, {price = newData[args.action]})
                lib.setMenuOptions('modify_property_menu', newOptions, args.action == "price" and 2 or 3)
            end
        elseif args.action == "interior" then
            local interior = newData.interior or propertyData.interior
            local input = lib.inputDialog(Lang:t('modify_property_menu.title'), {
                {type = 'select', label = Lang:t('modify_property_menu.interior', {interior = interior}), default = interior, options = createInteriorsList(propertyData.property_type == 'garage', propertyData.property_type ~= 'garage')},
            }, {allowCancel = true})

            if input then
                newData.interior = input[1]
                local newOptions = options[5]
                newOptions.label = Lang:t('modify_property_menu.interior', {interior = newData.interior})
                lib.setMenuOptions('modify_property_menu', newOptions, 5)
            end
        elseif args.action == "slots" or args.action == "maxweight" then
            local value = (newData[args.action] or propertyData[args.action]) / (args.action == "maxweight" and 1000 or 1)
            local input = lib.inputDialog(Lang:t('modify_property_menu.title'), {
                {type = 'number', label = Lang:t('modify_property_menu.storage.'..args.action, {value = value}), default = value, required = true},
            }, {allowCancel = true})

            if input then
                newData[args.action] = tonumber(input[1]) * (args.action == "maxweight" and 1000 or 1)
                local newOptions = options[args.action == "slots" and 6 or 7]
                newOptions.label = Lang:t('modify_property_menu.storage.'..args.action, {value = newData[args.action] / (args.action == "maxweight" and 1000 or 1)})
                lib.setMenuOptions('modify_property_menu', newOptions, args.action == "slots" and 6 or 7)
            end
        elseif args.action == "taxes" then
            local index = #options - 2
            local taxes = newData.taxes or propertyData.appliedtaxes
            local default = {}
            for k, _ in pairs(taxes) do
                default[#default+1] = k
            end
            local input = lib.inputDialog(Lang:t('modify_property_menu.title'), {
                {type = 'multi-select', label = Lang:t('modify_property_menu.taxes', {taxes = getTaxesString(taxes)}), default = default, options = getTaxesList()},
            }, {allowCancel = true})
            if input then
                newData.taxes = getAppliedTaxesList(input[1])
                local newOptions = options[index]
                newOptions.label = Lang:t('modify_property_menu.taxes', {taxes = getTaxesString(newData.taxes)})
                lib.setMenuOptions('modify_property_menu', newOptions, index)
            end
        elseif args.action == "coords" then
            local coord, heading = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
            local coords = {x = coord.x, y = coord.y, z = coord.z, w = heading}
            coords = GetRoundedCoords(coords)
            newData.coords = vec4(coords.x, coords.y, coords.z, coords.w)
            point.coords, point.heading = newData.coords.xyz, newData.coords.w
        end

        if args.action == 'done' then
            if not next(newData) then return end
            TriggerServerEvent('qbx-property:server:modifyProperty', propertyData.id, newData)
            point:remove()
        else
            lib.showMenu('modify_property_menu')
        end
    end)
    lib.showMenu('modify_property_menu')
end

--- Populate the property menu
---@param propertyData table
---@param propertyType string
local function populatePropertyMenu(propertyData, propertyType)
    if not propertyData then return end
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return end
    local isRealEstateAgent = PlayerData.job.type == 'realestate'
    local isBought, isRented, hasKeys = next(propertyData.owners) ~= nil and true or false, propertyData.rent_expiration and true or false, propertyData.owners[PlayerData.citizenid] and true or false
    local options = {}
    if isBought or isRented then
        if hasKeys then
            options[#options+1] = {
                label = Lang:t('property_menu.enter'),
                icon = 'door-open',
                args = {
                    action = 'enter',
                    propertyData = propertyData,
                    propertyType = propertyType,
                },
                close = true
            }
        else
            options[#options+1] = {
                label = Lang:t('property_menu.ring'),
                icon = 'bell',
                args = {
                    action = 'ring',
                    propertyData = propertyData,
                    propertyType = propertyType,
                },
                close = true
            }
        end
        if isRented and isRealEstateAgent then
            options[#options+1] = {
                label = Lang:t('property_menu.extend_rent'),
                description = Lang:t('property_menu.extend_rent_desc', {rent_expiration = propertyData.rent_expiration, price = calcPrice(propertyData.rent, propertyData.appliedtaxes)}),
                icon = 'file-invoice-dollar',
                args = {
                    action = 'extend_rent',
                    propertyData = propertyData,
                    propertyType = propertyType,
                },
                close = true
            }
        end
    elseif isRealEstateAgent then
        options[#options+1] = {
            label = Lang:t('property_menu.sell'),
            description = Lang:t('property_menu.sell_desc', {price = calcPrice(propertyData.price, propertyData.taxes)}),
            icon = 'file-invoice-dollar',
            args = {
                action = 'sell',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
        options[#options+1] = {
            label = Lang:t('property_menu.rent', {price = calcPrice(propertyData.rent, propertyData.taxes)}),
            description = Lang:t('property_menu.rent_desc', {price = calcPrice(propertyData.rent, propertyData.taxes)}),
            icon = 'file-invoice-dollar',
            args = {
                action = 'rent',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
    else
        options[#options+1] = {
            label = Lang:t('property_menu.visit'),
            args = {
                action = 'visit',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
    end

    if isRealEstateAgent then
        options[#options+1] = {
            label = Lang:t('property_menu.modify'),
            icon = "toolbox",
            args = {
                action = 'modify',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
    end

    options[#options+1] = {
        label = Lang:t('property_menu.back'),
        icon = 'arrow-left',
        args = {
            action = 'back',
        },
        close = true
    }


    lib.registerMenu({
        id = 'property_menu',
        title = propertyData.name,
        position = 'top-left',
        options = options,
        onClose = function(keyPressed)
            if keyPressed == "Backspace" then
                lib.showMenu('properties_menu')
            end
        end,
    }, function(selected, scrollIndex, args)
        if args.action == 'enter' then
            if args.propertyType == 'garage' then
                TriggerServerEvent('qbx-property:server:EnterGarage', args.propertyData.id)
            else
                TriggerServerEvent('qbx-property:server:EnterProperty', args.propertyData.id)
            end
        elseif args.action == 'ring' then
            TriggerServerEvent('qbx-property:server:RingDoor', args.propertyData.id)
        elseif args.action == 'extend_rent' then
            rentToPlayer(args.propertyData, true)
        elseif args.action == 'sell' then
            sellToPlayer(args.propertyData)
        elseif args.action == 'rent' then
            rentToPlayer(args.propertyData, false)
        elseif args.action == 'modify' then
            modifyProperty(args.propertyData)
        elseif args.action == 'back' then
            lib.showMenu('properties_menu')
        end
    end)
end

--- Populate the properties menu (list of properties in a same location)
---@param ids table
---@param propertyType string
local function populatePropertiesMenu(ids, propertyType)
    if not ids then return end
    local options = {}

    for _, propertyId in pairs(ids) do
        local propertyData = lib.callback.await('qbx-property:server:GetPropertyData', false, propertyId)
        if not propertyData then goto continue end
        options[#options+1] = {
            label = propertyData.name,
            icon = propertyType == 'garage' and 'warehouse' or 'house-chimney',
            args = {
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
        ::continue::
    end

    lib.registerMenu({
        id = 'properties_menu',
        title = 'Property List',
        position = 'top-left',
        options = options
    }, function(selected, scrollIndex, args)
        populatePropertyMenu(args.propertyData, args.propertyType)
        lib.showMenu('property_menu')
    end)
end

local function addPropertyGroupBlip(propertyId, propertyGroup, isRented)
    local Status = (propertyGroup.propertyType == 'garage' and 'garage') or (isRented and 'rent') or 'owned'
    AddBlip(propertyId, propertyGroup.name, propertyGroup.coords, Config.Properties.blip[Status].sprite, Config.Properties.blip[Status].color, Config.Properties.blip[Status].scale)
end

local function createPropertiesZones()
    local propertiesGroups = lib.callback.await('qbx-property:server:GetProperties', false)
    if not propertiesGroups then return end

    local markerColor = Config.Properties.marker.color
    local markerScale = Config.Properties.marker.scale
    local ownedOrRentedProperties = lib.callback.await('qbx-property:server:GetOwnedOrRentedProperties', false)

    for k, v in pairs(propertiesGroups) do
        print(string.format('ID: %s, Coords: %s, Type: %s', tostring(v.properties[1]), tostring(v.coords), tostring(v.propertyType)))
        local zone = lib.points.new({
            coords = v.coords.xyz,
            heading = v.coords.h,
            distance = 15,
            reset = false,
            propertyIds = v.properties,
            propertyType = v.propertyType
        })

        function zone:nearby()
            if not self then return end
            if self?.reset then self:remove() return end
            if not self.currentDistance then return end
            DrawMarker(Config.Properties.marker.type,
                self.coords.x, self.coords.y, self.coords.z + Config.Properties.marker.offsetZ, -- coords
                0.0, 0.0, 0.0, -- direction?
                0.0, 0.0, 0.0, -- rotation
                markerScale.x, markerScale.y, markerScale.z, -- scale
                markerColor.r, markerColor.g, markerColor.b, markerColor.a, -- color RBGA
                false, true, 2, false, nil, nil, false
            )

            if self.currentDistance < 1 and not lib.getOpenMenu() and not inSelection then
                SetTextComponentFormat("STRING")
                AddTextComponentString(Lang:t('properties_menu.showmenuhelp', {propertyType = Lang:t('properties_menu.'..self.propertyType)}))
                DisplayHelpTextFromStringLabel(0, 0, 1, 20000)
                isInZone = true
                if IsControlJustPressed(0, 38) then
                    populatePropertiesMenu(self.propertyIds, self.propertyType)
                    lib.showMenu('properties_menu')
                end
            else
                isInZone = false
            end
        end
        propertyZones[k] = zone
        if ownedOrRentedProperties[k] then
            addPropertyGroupBlip(k, v, ownedOrRentedProperties[k].isRented)
        end
    end
end

--- removes the lib.points objects and clears the propertyZones table
local function clearProperties()
    for _, v in pairs(propertyZones) do
        v.reset = true
    end
    propertyZones = {}
    RemoveBlips()
end

local function refreshProperties()
    print('refreshProperties')
    clearProperties()
    createPropertiesZones()
end

--- Create a property
---@param propertyData table
local function createProperty(propertyData)
    propertyData.maxweight = propertyData.maxweight and propertyData.maxweight * 1000 or false
    TriggerServerEvent('qbx-property:server:CreateProperty', propertyData)
end

local interiors = {
    [290561] = { -- Eclipse Boulevard
        entitysets = {
            "entity_set_shell_02",
            "entity_set_numbers_01",
            "entity_set_tint_01",
        },
        color = {
            "entity_set_tint_01",
            1
        }
    },
    [291841] = { -- Vinewood Car Club
        entitysets = {
            "entity_set_signs",
            "entity_set_plus",
            "entity_set_stairs",
            "entity_set_backdrop_frames"
        }
    },
    [290817] = {
        entitysets = {
            "entity_set_roller_door_closed"
        }
    }
}

local function setupInteriors()
    local Franklin = exports['bob74_ipl']:GetFranklinObject()
    Franklin.Style.Set(Franklin.Style.settled)
    Franklin.GlassDoor.Set(Franklin.GlassDoor.closed, true)

    for k, v in pairs(interiors) do
        for _, entityset in pairs(v.entitysets) do
            ActivateInteriorEntitySet(k, entityset)
        end
        if v.color then
            SetInteriorEntitySetColor(k, v.color[1], v.color[2])
        end
        RefreshInterior(k)
    end
end
--#endregion Functions

--#region Events
RegisterNetEvent('qbx-property:client:refreshProperties', refreshProperties)

RegisterNetEvent('qbx-property:client:OpenCreationMenu', function()
    if isInZone then
        QBCore.Functions.Notify('A property already exists there!', 'error', 5000)
        return
    end
    local generalOptions = lib.inputDialog('Property Creator', {
        {type = 'input', label = 'Name', description = 'Name the Property (Optional)', placeholder = 'Vinewood Villa'},
        {type = 'number', label = 'Price', required = true, icon = 'dollar-sign', default = Config.Properties.minimumPrice, min = Config.Properties.minimumPrice},
        {type = 'number', label = 'Rent Price', required = true, description = 'Rent price for 7 days', icon = 'dollar-sign', default = 100, placeholder = "69"},
        {type = 'checkbox', label = 'Garage?', checked = false},
        {type = 'checkbox', label = 'Furnished? (Not For Garages!)', checked = true},
    }, {allowCancel = true})
    if not generalOptions then return end
    if generalOptions[1] == '' then generalOptions[1] = nil end

    local propertyOptions = {
        {type = 'select', clearable = false, label = "Interior", options = createInteriorsList(generalOptions[4], generalOptions[5])}
    }
    if not generalOptions[4] then
        propertyOptions[2] = {type = 'number', label = "Storage Volume", description = "Size of the storage (Kg)", default = 50, min = 1}
        propertyOptions[3] = {type = 'number', label = "Storage Size", description = "Number of slots the Storage has", default = 10, min = 1}
        if Config.Properties.useTaxes then
            propertyOptions[4] = {type = 'multi-select', label = "Taxes", description = "Adds a tax if the property has the selected feature", options = getTaxesList()}
        end
    end

    local propertyCreation = lib.inputDialog('Property Creator', propertyOptions, {allowCancel = true})
    if not propertyCreation then return end
    if not propertyCreation[1] then
        QBCore.Functions.Notify('You need to select an interior!', 'error')
        return
    end
    local coord, heading = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local coords = {x = coord.x, y = coord.y, z = coord.z, w = heading}
    coords = GetRoundedCoords(coords)

    local inputResult = {
        name = generalOptions[1] or GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z)),
        price = generalOptions[2],
        rent = generalOptions[3],
        garage = generalOptions[4] or nil,
        furnished = generalOptions[4] and nil or generalOptions[5],
        interior = propertyCreation[1],
        maxweight = propertyCreation[2] or nil,
        slots = propertyCreation[3] or nil,
        appliedtaxes = getAppliedTaxesList(propertyCreation[4]) or nil,
        coords = {x = coords.x, y = coords.y, z = coords.z, w = coords.w},
    }
    createProperty(inputResult)
end)

RegisterNetEvent('qbx-property:client:enterProperty', function(coords, propertyid)

end)

RegisterNetEvent('qbx-property:client:LeaveProperty', function(coords)
    if not coords then return end
    interiorZones = nil
    DoScreenFadeOut(500)
    Wait(250)
    SetEntityCoords(cache.ped, coords.xyz, 0.0, 0.0, false, false, false, false)
    SetEntityHeading(cache.ped, coords.h or coords.w)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    setupInteriors()
    refreshProperties()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        setupInteriors()
        SetTimeout(2000, function()
            if not next(propertyZones) then
                refreshProperties()
            end
        end)
    end
end)
--#endregion Events

--#region Callbacks
lib.callback.register('qbx-properties:client:promptOffer', function(price, isRent)
    local alert = lib.alertDialog({
        header = Lang:t('general.promptOfferHeader'),
        content = Lang:t('general.promptOffer', {action = Lang:t('general.'.. (isRent and 'rent' or 'buy')), amount = price}),
        centered = true,
        cancel = true
    })
    return alert == 'confirm' and true or false
end)
--#endregion Callbacks