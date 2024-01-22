local scenes = {}

RegisterNetEvent('dk-scenes:server:DeleteScene', function(id)
    for k, v in pairs(scenes) do
        if v.id == id then
            table.remove(scenes, k)
            break
        end
    end
    GlobalState.Scenes = scenes
    TriggerClientEvent('dk-scenes:client:UpdateAllScenes', -1, id)
end)

RegisterNetEvent('dk-scenes:server:CreateScene', function(sceneData)
    scenes[#scenes+1] = sceneData
    GlobalState.Scenes = scenes
    TriggerClientEvent('dk-scenes:client:UpdateAllScenes', -1, sceneData)
end)