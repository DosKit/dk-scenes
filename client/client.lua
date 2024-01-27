local closestScenes, scenes, Prompts = {}, GlobalState.Scenes or {}, {}
local ColorTable = {
    white = {255, 255, 255},
    red = {117, 0, 16},
    green = {0, 117, 16},
    blue = {7, 1, 125},
    purple = {102, 1, 125},
    yellow = {143, 153, 2},
    pink = {176, 2, 129}
}

-----------------------------------------------------------------------
---- FUNCTIONS
-----------------------------------------------------------------------

local function RotationToDirection(rotation)
    local rot = rotation * (math.pi / 180)
    local direction = vector3(-math.sin(rot.z) * math.abs(math.cos(rot.x)), math.cos(rot.z) * math.abs(math.cos(rot.x)), math.sin(rot.x))
    return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination = vector3(cameraCoord.x + direction.x * distance, cameraCoord.y + direction.y * distance, cameraCoord.z + direction.z * distance)
	local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
	return hit == 1, endCoords
end

local function DrawLaser(color)
    local hit, coords = RayCastGamePlayCamera(25.0)
    if hit then
        local position = GetEntityCoords(PlayerPedId())
        Citizen.InvokeNative(`DRAW_LINE` & 0xFFFFFFFF, position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
    end
    return hit, coords
end

local function RegisterPrompts(data)
    for i=1, #data do
        local prompt = PromptRegisterBegin()
        PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", data[i][2]))
        PromptSetControlAction(prompt, data[i][1])
        PromptRegisterEnd(prompt)
        PromptSetEnabled(prompt, true)
        PromptSetVisible(prompt, true)
        Prompts[i] = prompt
    end
end

local function DeleteScene(coords)
    local closestScene = nil
    local shortestDistance = nil
    for i=1,#scenes do
        local currentScene = scenes[i]
        local distance =  #(coords - currentScene.coords)
        if distance < 1 and (shortestDistance == nil or distance < shortestDistance) then
            closestScene = currentScene.id
            shortestDistance = distance
        end
    end
    if not closestScene then return end
    TriggerServerEvent('dk-scenes:server:DeleteScene', closestScene)
end

local function DrawScene(currentScene)
    local onScreen, sX, sY = GetScreenCoordFromWorldCoord(currentScene.coords.x, currentScene.coords.y, currentScene.coords.z)
    if onScreen then
        local camCoords = GetGameplayCamCoord()
        local distance = #(currentScene.coords - camCoords)
        local fov = (1 / GetGameplayCamFov()) * 75
        local scale = (1 / distance) * (4) * fov * (currentScene.size)
    	SetTextScale(0.0, scale)
  		SetTextFontForCurrentCommand(1)
        local text = ColorTable[currentScene.color]
    	SetTextColor(text[1], text[2], text[3], 215)
    	SetTextCentre(1)
        local str = CreateVarString(10, "LITERAL_STRING", currentScene.text, Citizen.ResultAsLong())
    	DisplayText(str,sX,sY)
    end
end

local function ToggleDeletionLaser()
    RegisterPrompts({{0xCEFD9220, 'Delete Scene'}, {0x760A9C6F, 'Cancel'}})
    local colorlazer = {r = 255, g = 0, b = 0, a = 200}
    while true do
        local hit, coords = DrawLaser(colorlazer)
        if IsControlJustReleased(0, 0xCEFD9220) then
            if hit then DeleteScene(coords) break end
        elseif IsControlJustReleased(0, 0x760A9C6F) then
            break
        end
        Wait(3)
    end
    for _, v in pairs(Prompts) do PromptDelete(v) end
    Prompts = {}
end

local function ToggleCreationLaser(data)
    RegisterPrompts({{0xCEFD9220, 'Place Scene'}, {0x760A9C6F, 'Cancel Scene'}})
    local colorlazer = {r = 2, g = 241, b = 181, a = 200}
    while true do
        local hit, coords = DrawLaser(colorlazer)
        data.coords = coords
        DrawScene(data)
        if IsControlJustReleased(0, 0xCEFD9220) then
            if hit then
                data.id, data.dist, data.size = math.random(1, 5000), tonumber(data.dist), tonumber(data.size)
                TriggerServerEvent('dk-scenes:server:CreateScene', data)
                break
            else
                TriggerEvent("DKCore:Notify", "Laser did not hit anything.", "error")
            end
        elseif IsControlJustReleased(0, 0x760A9C6F) then
            break
        end
        Wait(3)
    end
    for _, v in pairs(Prompts) do PromptDelete(v) end
    Prompts = {}
end

local function OpenMenu()
    local data = exports['qbr-input']:ShowInput({
        header = "Scenes",
        submitText = "Submit",
        inputs = {
            {
                text = "Text",
                name = "text",
                type = "text",
                isRequired = true
            },
            {
                text = "Color",
                name = "color",
                type = "select",
                options = {
                    { value = 'white', text = "White" },
                    { value = 'red',   text = "Red" },
                    { value = 'green', text = "Green" },
                    { value = 'blue',  text = "Blue" },
                    { value = 'purple',text = "Purple" },
                    { value = 'yellow',text = "Yellow" },
                    { value = 'pink',  text = "Pink" }
                },
            },
            {
                text = "Font Size",
                name = "size",
                type = "radio",
                options = {
                    { value = 0.5,  text = "1" },
                    { value = 0.70, text = "2" },
                    { value = 0.90, text = "3" },
                    { value = 1.0,  text = "4" },
                    { value = 1.1,  text = "5" }
                },
            },
            {
                text = "View Distance",
                name = "dist",
                type = "radio",
                options = {
                    { value = 5.0, text = "5" },
                    { value = 10.0, text = "10" },
                    { value = 15.0, text = "15" },
                    { value = 20.0, text = "20" },
                    { value = 25.0, text = "25" }
                },
            },
        },
    })
    if not data then return end
    ToggleCreationLaser(data)
end

-----------------------------------------------------------------------
---- COMMANDS AND EVENTS
-----------------------------------------------------------------------

RegisterCommand('createscene', OpenMenu)
RegisterCommand('deletescene', ToggleDeletionLaser)

RegisterNetEvent('dk-scenes:client:UpdateAllScenes', function(data)
    if type(data) == 'number' then
        for k, v in pairs(scenes) do
            if v.id == data then
                return table.remove(scenes, k)
            end
        end
    else
        scenes[#scenes+1] = data
    end
end)

-----------------------------------------------------------------------
---- THREADS
-----------------------------------------------------------------------

CreateThread(function()
    while true do
        closestScenes = {}
        if #scenes > 0 then
            local plyPosition = GetEntityCoords(PlayerPedId())
            for i=1, #scenes do
                local currentScene = scenes[i]
                local distance = #(plyPosition - currentScene.coords)
                if distance < 25.0 then
                    closestScenes[#closestScenes+1] = currentScene
                end
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        if #closestScenes > 0 then
            local plyPosition = GetEntityCoords(PlayerPedId())
            for i=1, #closestScenes do
                local currentScene = closestScenes[i]
                local distance = #(plyPosition - currentScene.coords)
                if distance <= currentScene.dist then
                    wait = 3
                    DrawScene(closestScenes[i])
                end
            end
        end
        Wait(wait)
    end
end)
