-- Add a callback for getting the available deposits as styled text
-- The "Get" prefix is required as the UI element of <X> calls 
-- GetX on the context object, in this case T{"<ExtractorAvailableDepositInfo>"}
Mine.GetExtractorAvailableDepositInfo = function(self)
    local lines = { }
    -- fills in "lines" with deposit information
    AvailableDeposits(self, lines)
    -- the last line should contain the actual deposit info already styled
    return lines[#lines]
end

-- install the new section
function OnMsg.ClassesBuilt()
    ExtractorAvailableDepositAddInfoSection()
end

-- installs a new text section in the Mine->Production Infopanel section
function ExtractorAvailableDepositAddInfoSection()
    table.insert(XTemplates.sectionMine[1], 
        PlaceObj("XTemplateTemplate", {
            "__template", "InfopanelText", 
            "Text", T{"<ExtractorAvailableDepositInfo>"}
        })
    )
    table.insert(XTemplates.sectionWaterProduction[1], 
        PlaceObj("XTemplateTemplate", {
            "__template", "InfopanelText", 
            "Text", T{"<ExtractorAvailableDepositInfo>"}
        })
    )
end
