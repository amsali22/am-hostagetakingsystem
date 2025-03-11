Config = {
    ---- Enable or disable debug mode (will print logs on the console) 
    --- I dont use this as i just removed the debug print lines from the code.
    -- Debug = true, 

    ---- List of weapons that will scare the hostage 
    WeaponList = {
        "WEAPON_M1911",
        "WEAPON_GLOCK17",
        "WEAPON_CROWBAR",
        "WEAPON_BAT",
    },

    --- Hostage ped models that will be used for the hostages (random)  https://docs.fivem.net/docs/game-references/ped-models/
    HostageModels = {
        "a_f_m_tourist_01",
        "a_m_y_business_03",
        "cs_marnie",
    },

    --- Hostage Spawn locations
    --- @param vector4 SpawnCoords - The coords where the hostage will spawn
    --- @param vector4 SurrunderCoords - The coords where the hostage will walk to surrunder
    HostageLocations = {
        {
            SpawnCoords = vec4(-714.32, -909.53, 19.22, 357.47),
            SurrunderCoords = vec4(-711.82, -914.38, 19.22, 183.99),
        },
        {
            SpawnCoords = vec4(28.83, -1342.64, 29.5, 355.47),
            SurrunderCoords = vec4(28.98, -1346.96, 29.5, 180.6),
        },
        {
            SpawnCoords = vec4(-50.12, -1749.4, 29.42, 315.1),
            SurrunderCoords = vec4(-51.71, -1755.2, 29.42, 137.73),
        },
        {
            SpawnCoords = vec4(-3042.05, 592.97, 7.91, 18.95),
            SurrunderCoords = vec4(-3040.18, 589.03, 7.91, 287.23),
        },
        {
            SpawnCoords = vec4(-3246.67, 1003.27, 12.83, 81.58),
            SurrunderCoords = vec4(-3241.72, 1004.52, 12.83, 262.55),
        },
        {
            SpawnCoords = vec4(381.08, 324.32, 103.57, 254.45),
            SurrunderCoords = vec4(376.95, 325.08, 103.57, 170.3),
        },
        {
            SpawnCoords = vec4(1152.9, -322.71, 69.21, 102.9),
            SurrunderCoords = vec4(1159.44, -324.88, 69.21, 189.6),
        },
        --- You can add more locations here if you want by following same format.
    },

    --- Hostage Release time if taken and no police arrive to release the hostage (in minutes)
    HostageReleaseTime = 15,

    --- Reset hostages each X minutes (in minutes), so lets say 60 minutes, all hostages will be removed and new ones will spawn.
    ResetHostagesTime = 60,
}