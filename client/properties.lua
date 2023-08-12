if not Config.useProperties then return end
local propertyZones = {}
local interiorZones = {}
local isInZone = false

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
    local totaltax = Config.Taxes.General
    for taxname, tax in pairs(Config.Taxes) do
        if taxes[taxname] then
            totaltax = totaltax + tax
        end
    end
    return math.floor(price + (price * (totaltax/100)))
end

local function populatePropertyMenu(propertyData, propertyType)
    if not propertyData then return end
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return end
    local isRealEstateAgent = PlayerData.job.type == 'realestate'
    local isBought, isRented, hasKeys = propertyData.owners and true or false, propertyData.rent_expiration and true or false, propertyData.owners[propertyData.citizenid] and true or false

    local options = {}

    if isBought or isRented then
        if hasKeys then
            options[#options+1] = {
                label = Lang:t('property_menu.enter'),
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
                args = {
                    action = 'ring',
                    propertyData = propertyData,
                    propertyType = propertyType,
                },
                close = true
            }
        end
        if isRented then
            options[#options+1] = {
                label = Lang:t('property_menu.extend_rent'),
                description = Lang:t('property_menu.extend_rent_desc', {rent_expiration = propertyData.rent_expiration, price = calcPrice(propertyData.rent, propertyData.appliedtaxes)}),
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
            label = Lang:t('property_menu.sell', {price = calcPrice(propertyData.price, propertyData.taxes)}),
            args = {
                action = 'sell',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
        options[#options+1] = {
            label = Lang:t('property_menu.rent'),
            args = {
                action = 'rent',
                propertyData = propertyData,
                propertyType = propertyType,
            },
            close = true
        }
    end

    if isRealEstateAgent then
        options[#options+1] = {
            label = Lang:t('property_menu.modify'),
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
        args = {
            action = 'back',
        },
        close = true
    }


    lib.registerMenu({
        id = 'property_menu',
        title = propertyData.name,
        position = 'top-left',
        options = options
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

        elseif args.action == 'sell' then
        elseif args.action == 'modify' then
        elseif args.action == 'back' then
            lib.showMenu('properties_menu')
        end
    end)
end

local function populatePropertiesMenu(ids, propertyType)
    if not ids then return end
    local options = {}

    for _, propertyId in pairs(ids) do
        local propertyData = lib.callback.await('qbx-property:server:GetPropertyData', false, propertyId)
        if not propertyData then goto continue end
        options[#options+1] = {
            label = propertyData.name,
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
    local Status = (propertyGroup.propertyType == 'garage' and 'Garage') or (isRented and 'Rent') or 'Owned'
    AddBlip(propertyId, propertyGroup.name, propertyGroup.coords, Config.Properties.Blip[Status].sprite, Config.Properties.Blip[Status].color, Config.Properties.Blip[Status].scale)
end

local function createPropertiesZones()
    local propertiesGroups = lib.callback.await('qbx-property:server:GetProperties', false)
    if not propertiesGroups then return end

    local Markercolor = Config.Properties.Marker.color
    local MarkerScale = Config.Properties.Marker.scale
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
            if self.reset then self.remove() return end
            if not self.currentDistance then return end
            DrawMarker(Config.Properties.Marker.type,
                self.coords.x, self.coords.y, self.coords.z + Config.Properties.Marker.offsetZ, -- coords
                0.0, 0.0, 0.0, -- direction?
                0.0, 0.0, 0.0, -- rotation
                MarkerScale.x, MarkerScale.y, MarkerScale.z, -- scale
                Markercolor.r, Markercolor.g, Markercolor.b, Markercolor.a, -- color RBGA
                false, true, 2, false, nil, nil, false
            )

            if self.currentDistance < 1 and not lib.getOpenMenu() then
                SetTextComponentFormat("STRING")
                AddTextComponentString(Lang:t('properties_menu.showmenuhelp', {propertyType = Lang:t('properties_menu.'..self.propertyType)}))
                DisplayHelpTextFromStringLabel(0, 0, 1, 20000)
                isInZone = true
                if IsControlJustPressed(0, 38) then
                    populatePropertiesMenu(self.propertyIds, self.propertyType)
                    --lib.showMenu('properties_menu')
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
end

RegisterNetEvent('qbx-property:client:refreshProperties', function()
    print('refreshProperties')
    clearProperties()
    createPropertiesZones()
end)

--- Create a list of interiors
--- @param Garage boolean
--- @param Furnished boolean
--- @return table
local function createInteriorsList(Garage, Furnished)
    local options = {}
    for k,v in pairs((Garage and Config.GarageIPLs) or (Furnished and Config.IPLS) or Config.Shells) do
        options[#options+1] = {}
        options[#options].label = Garage and (k .. " (" .. #v.coords.slots .. ' Slots)') or nil -- Lang:t('', {slots = #v.slots})
        options[#options].value = k
    end
    return options
end

--- Get the list of taxes
--- return table
local function getTaxesList()
    local taxes = {}
    for k, _ in pairs(Config.Taxes) do
        if k ~= 'General' then
            taxes[#taxes + 1] = {
                label = k,
                value = k
            }
        end
    end
    return taxes
end

--- Create a property
---@param propertyData table
local function createProperty(propertyData)
    propertyData.maxWeight = propertyData.weight and propertyData.weight * 1000 or false
    TriggerServerEvent('qbx-property:server:CreateProperty', propertyData)
end

--- Get the list of applied taxes if any
---@param taxes table | nil
---@return table | nil
local function getAppliedTaxesList(taxes)
    if not taxes then return nil end
    local appliedTaxes = {}
    for _, v in pairs(taxes) do
        appliedTaxes[v] = Config.Taxes[v]
    end
    return appliedTaxes
end

RegisterNetEvent('qbx-property:client:OpenCreationMenu', function()
    if isInZone then
        QBCore.Functions.Notify('A property already exists there!', 'error', 5000)
        return
    end
    local generalOptions = lib.inputDialog('Property Creator', {
        {type = 'input', label = 'Name', description = 'Name the Property (Optional)', placeholder = 'Vinewood Villa'},
        {type = 'number', label = 'Price', required = true, icon = 'dollar-sign', default = 1000, min = Config.MinimumPrice},
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
        if Config.UseTaxes then
            propertyOptions[4] = {type = 'multi-select', label = "Taxes", description = "Adds a tax if the property has the selected feature", options = getTaxesList()}
        end
    end

    local propertyCreation = lib.inputDialog('Property Creator', propertyOptions, {allowCancel = true})
    if not propertyCreation then return end
    if not propertyCreation[1] then
        QBCore.Functions.Notify('You need to select an interior!', 'error')
        return
    end
    local coords = GetEntityCoords(cache.ped)
    local inputResult = {
        name = generalOptions[1] or GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z)),
        price = generalOptions[2],
        rent = generalOptions[3],
        garage = generalOptions[4] or nil,
        furnished = generalOptions[4] and nil or generalOptions[5],
        interior = propertyCreation[1],
        weight = propertyCreation[2] or nil,
        slots = propertyCreation[3] or nil,
        appliedtaxes = getAppliedTaxesList(propertyCreation[4]) or nil,
        coords = {x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(cache.ped)},
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

CreateThread(function()
    createPropertiesZones()
end)
