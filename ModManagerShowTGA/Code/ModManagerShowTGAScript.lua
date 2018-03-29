-- Alter the Mod Manager screen (when classes have been loaded?)
function OnMsg.ClassesBuilt()
    ModManagerShowTGAPatch()
end

function ModManagerShowTGAPatch()
    -- based on Lua/UI/ModManager.lua
    local oldFunc = ShowModDescription

    if oldFunc then
        ShowModDescription = function(item, dialog)
            -- run the old function, to setup the dialog
            oldFunc(item, dialog)

            local mod_image = item.image
            
            -- is the image a PNG?
            if mod_image:sub(-4):lower() == ".png" then
                -- change it to TGA
                mod_image = mod_image:sub(1, mod_image:len() - 4) .. ".tga"
                -- update the image display
                (dialog.idImage):SetImage(mod_image)

                return "success"
            end
            return "no png"
        end
        return "function patched"
    end

    return "function not found"
end