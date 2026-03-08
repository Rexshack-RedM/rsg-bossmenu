Config = {}

-- blip settings
Config.Blip = {
    blipName = 'Boss Menu', -- Config.Blip.blipName
    blipSprite = 'blip_honor_good', -- Config.Blip.blipSprite
    blipScale = 0.2 -- Config.Blip.blipScale
}

-- settings
Config.Keybind = 'J'
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 50

Config.BossLocations = {

    {   -- example
        id = 'boss1',
        name = 'Boss Menu',
        jobname = 'medic', -- Name of the job from rsg-core/shared/jobs.lua you want to be able to access the bossmenu (Only the isBoss = true grades will be able to acces it)
        coords = vector3(0, 0, 0),
        showblip = false
    },

}
