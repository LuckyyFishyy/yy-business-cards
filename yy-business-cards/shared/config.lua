Config = {}

Config.PrinterItem = 'business_printer'
Config.BlankCardItem = 'blank_business_card'
Config.BusinessCardItem = 'business_card'

Config.PrinterModel = 'v_ret_gc_fax'

Config.Placement = {
    MaxDistance = 15.0,
    RotationStep = 1.5,
    ZOffset = 0.0,
    RightOffset = 0.15,
    ConfirmKey = 191, -- Enter
    CancelKey = 194, -- Backspace
    RotateLeftKey = 174, -- Left arrow
    RotateRightKey = 175 -- Right arrow
}

Config.Printing = {
    MaxAmount = 50,
    MinAmount = 1
}

Config.CardPreview = {
    Width = 340,
    Height = 210
}

Config.CardSides = {
    EnableBack = true,
    FrontOnlyAutoCloseMs = 4000
}

Config.ImageRules = {
    RequireHttps = true,
    RestrictHosts = false,
    AllowedHosts = {
        'i.imgur.com',
        'imgur.com',
        'cdn.discordapp.com',
        'media.discordapp.net'
    }
}
