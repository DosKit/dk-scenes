local closestScenes, scenes, Prompts = {}, GlobalState.Scenes or {}, {}
local creationLaser, deletionLaser = false, false
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
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
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

local function DrawScene(currentScene)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(currentScene.coords.x, currentScene.coords.y, currentScene.coords.z)
    if onScreen then
        local camCoords = GetGameplayCamCoord()
        local distance = #(currentScene.coords - camCoords)
        local fov = (1 / GetGameplayCamFov()) * 75
        local scale = (1 / distance) * (4) * fov * (currentScene.fontsize)
    	SetTextScale(0.0, scale)
  		SetTextFontForCurrentCommand(1)
        local text = ColorTable[currentScene.color]
    	SetTextColor(text[1], text[2], text[3], 215)
    	SetTextCentre(1)
        local str = CreateVarString(10, "LITERAL_STRING", currentScene.text, Citizen.ResultAsLong())
    	DisplayText(str,screenX,screenY)
    end
end

local function RegisterPrompts(data)
    for k, v in pairs(data) do
        local prompt = PromptRegisterBegin()
        PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", v.label))
        PromptSetControlAction(prompt, v.key)
        PromptRegisterEnd(prompt)
        PromptSetEnabled(prompt, true)
        PromptSetVisible(prompt, true)
        Prompts[k] = prompt
    end
end

local function ToggleCreationLaser(data)
    deletionLaser = false
    creationLaser = not creationLaser
    if creationLaser then
        CreateThread(function()
            local prompts = {
                [1] = {key = 0xCEFD9220, label = 'Place Scene'},
                [2] = {key = 0x760A9C6F, label = 'Cancel Scene'},
            }
            RegisterPrompts(prompts)
            local colorlazer = {r = 2, g = 241, b = 181, a = 200}
            while creationLaser do
                local hit, coords = DrawLaser(colorlazer)
                data.coords = coords
                DrawScene(data)
                if IsControlJustReleased(0, 0xCEFD9220) then
                    creationLaser = false
                    if hit then
                        data.id = math.random(1, 5000)
                        data.viewdistance = tonumber(data.viewdistance)
                        data.fontsize = tonumber(data.fontsize)
                        TriggerServerEvent('dk-scenes:server:CreateScene', data)
                    else
                        TriggerEvent("DKCore:Notify", "Laser did not hit anything.", "error")
                    end
                elseif IsControlJustReleased(0, 0x760A9C6F) then
                    creationLaser = false
                end
                Wait(0)
            end
            for k, v in pairs(Prompts) do
                PromptDelete(v)
            end
            Prompts = {}
        end)
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
    if closestScene then
        TriggerServerEvent('dk-scenes:server:DeleteScene', closestScene)
    end
end

local function ToggleDeletionLaser()
    creationLaser = false
    deletionLaser = not deletionLaser
    if deletionLaser then
        CreateThread(function()
            local prompts = {
                [1] = {key = 0xCEFD9220, label = 'Delete Scene'},
                [2] = {key = 0x760A9C6F, label = 'Cancel'},
            }
            RegisterPrompts(prompts)
            local colorlazer = {r = 255, g = 0, b = 0, a = 200}
            while deletionLaser do
                local hit, coords = DrawLaser(colorlazer)
                if IsControlJustReleased(0, 0xCEFD9220) then
                    deletionLaser = false
                    if hit then
                        DeleteScene(coords)
                    end
                elseif IsControlJustReleased(0, 0x760A9C6F) then
                    deletionLaser = false
                end
                Wait(0)
            end
            for k, v in pairs(Prompts) do
                PromptDelete(v)
            end
            Prompts = {}
        end)
    end
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
                name = "fontsize",
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
                name = "viewdistance",
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
---- EVENTS AND HANDLERS
-----------------------------------------------------------------------

RegisterCommand('createscene', OpenMenu)
RegisterCommand('deletescene', ToggleDeletionLaser)

RegisterNetEvent('dk-scenes:client:UpdateAllScenes', function(data, start)
    if start then scenes = data return end
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
                if distance <= currentScene.viewdistance then
                    wait = 3
                    DrawScene(closestScenes[i])
                end
            end
        end
        Wait(wait)
    end
end)