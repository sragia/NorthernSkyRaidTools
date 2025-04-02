local _, NSI = ... -- Internal namespace
_G["NSAPI"] = {}
NSI.specs = {}
local NSAPI2 = NSAPI

-- storing NSAPI in NSAPI2 so I can overwrite it again if user still has the old database WA installed
-- this is needed because the database WA will overwrite the global NSAPI which would cause newer functions to be nil
hooksecurefunc("setglobal", function(name, _)
    if name == "NSAPI" then
        print("Please uninstall the old database WA to prevent conflicts with the Northern Sky Raid Tools Addon.")
        NSAPI = NSAPI2
    end
end)