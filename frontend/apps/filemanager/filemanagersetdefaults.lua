local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local CenterContainer = require("ui/widget/container/centercontainer")
local Screen = require("ui/screen")
local Menu = require("ui/widget/menu")
local Font = require("ui/font")

local SetDefaults = InputContainer:new{
    defaults_name = {},
    defaults_value = {},
    results = {},
    defaults_menu = {},
}

local function settype(b,t)
    if t == "boolean" then
        if b == "false" then return false else return true end
    else
        return b
    end
end

local function __genOrderedIndex( t )
-- this function is taken from http://lua-users.org/wiki/SortedIteration
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

local function orderedNext(t, state)
-- this function is taken from http://lua-users.org/wiki/SortedIteration

    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
        return key, t[key]
    end
    -- fetch the next value
    key = nil
    for i = 1,table.getn(t.__orderedIndex) do
        if t.__orderedIndex[i] == state then
            key = t.__orderedIndex[i+1]
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

local function orderedPairs(t)
-- this function is taken from http://lua-users.org/wiki/SortedIteration
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    return orderedNext, t, nil
end

function SetDefaults:ConfirmEdit()
    if not SetDefaults.EditConfirmed then
        UIManager:show(ConfirmBox:new{
            text = _("Wrong settings might crash Koreader! Continue?"),
            ok_callback = function()
                self.EditConfirmed = true
                self:init()
            end,
        })
    else
        self:init()
    end
end

function SetDefaults:init()

    local function setdisplayname(i)
        local dummy = self.defaults_name[i] .. " = " 
        if type(_G[self.defaults_name[i]]) == "string" and not tonumber(self.defaults_value[i]) then
            dummy = dummy .. "\"" .. tostring(self.defaults_value[i]) .. "\"" -- add quotation marks to strings
        else
            dummy = dummy .. tostring(self.defaults_value[i])
        end
        return dummy
    end

    self.defaults_name = {}
    self.defaults_value = {}
    self.results = {}

    self.filldefaults()

    local menu_container = CenterContainer:new{
        dimen = Screen:getSize(),
    }

    self.defaults_menu = Menu:new{
        width = Screen:getWidth()-15,
        height = Screen:getHeight()-15,
        cface = Font:getFace("cfont", 22),
        show_parent = menu_container,
        _manager = self,
    }
    table.insert(menu_container, self.defaults_menu)
    self.defaults_menu.close_callback = function()
        UIManager:close(menu_container)
    end

    for i=1,#self.defaults_name do
        local settings_type = type(_G[self.defaults_name[i]])
        if settings_type == "boolean" then
            table.insert(self.results, {
                text = setdisplayname(i),
                callback = function()
                    GLOBAL_INPUT_VALUE = tostring(self.defaults_value[i])
                    self.set_dialog = InputDialog:new{
                        title = self.defaults_name[i] .. ":",
                        buttons = {
                            {
                                {
                                    text = _("Cancel"),
                                    enabled = true,
                                    callback = function()
                                        self:close()
                                        UIManager:show(menu_container)
                                    end 
                                },
                                {
                                    text = "true",
                                    enabled = true,
                                    callback = function()
                                        self.defaults_value[i] = true
                                        if not _G[self.defaults_name[i]] then
                                            _G[self.defaults_name[i]] = true
                                            settings_changed = true
                                        end
                                        self.results[i].text = setdisplayname(i)
                                        self:close()
                                        self.defaults_menu:swithItemTable("Defaults", self.results, i)
                                        UIManager:show(menu_container)
                                    end
                                },
                                {
                                    text = "false",
                                    enabled = true,
                                    callback = function()
                                        self.defaults_value[i] = false
                                        if _G[self.defaults_name[i]] then
                                            _G[self.defaults_name[i]] = false
                                            settings_changed = true
                                        end
                                        self.results[i].text = setdisplayname(i)
                                        self.defaults_menu:swithItemTable("Defaults", self.results, i)
                                        self:close()
                                        UIManager:show(menu_container)
                                    end
                                },
                            },
                        },
                        input_type = settings_type,
                        width = Screen:getWidth() * 0.95,
                        height = Screen:getHeight() * 0.2,
                    }
                    GLOBAL_INPUT_VALUE = nil
                    self.set_dialog:onShowKeyboard()
                    UIManager:show(self.set_dialog)
                end
            })
        else
            table.insert(self.results, {
                text = setdisplayname(i),
                callback = function()
                    GLOBAL_INPUT_VALUE = tostring(self.defaults_value[i])
                    self.set_dialog = InputDialog:new{
                        title = self.defaults_name[i] .. ":",
                        buttons = {
                            {
                                {
                                    text = _("Cancel"),
                                    enabled = true,
                                    callback = function()
                                        self:close()
                                        UIManager:show(menu_container)
                                    end,
                                },
                                {
                                    text = _("OK"),
                                    enabled = true,
                                    callback = function()
                                        if _G[self.defaults_name[i]] ~= settype(self.set_dialog:getInputText(),settings_type) then
                                            _G[self.defaults_name[i]] = settype(self.set_dialog:getInputText(),settings_type)
                                            settings_changed = true
                                        end
                                        self.defaults_value[i] = _G[self.defaults_name[i]]
                                        self.results[i].text = setdisplayname(i)
                                        self:close()
                                        self.defaults_menu:swithItemTable("Defaults", self.results, i)
                                        UIManager:show(menu_container)
                                    end,
                                },
                            },
                        },
                        input_type = settings_type,
                        width = Screen:getWidth() * 0.95,
                        height = Screen:getHeight() * 0.2,
                    }
                    GLOBAL_INPUT_VALUE = nil
                    self.set_dialog:onShowKeyboard()
                    UIManager:show(self.set_dialog)
                end
            })
        end
    end
    self.defaults_menu:swithItemTable("Defaults", self.results)
    UIManager:show(menu_container)
end

function SetDefaults:filldefaults()
    local i = 0
    for n,v in orderedPairs(_G) do
        if (not string.find(tostring(v), "<")) and (not string.find(tostring(v), ": ")) and string.sub(n,1,1) ~= "_" and string.upper(n) == n and n ~= "GLOBAL_INPUT_VALUE" and n ~= "LIBRARY_PATH" then
            i = i + 1
            SetDefaults.defaults_name[i] = n
            SetDefaults.defaults_value[i] = v
        end
    end
end

function SetDefaults:close()
    self.set_dialog:onClose()
    UIManager:close(self.set_dialog)
end

function SetDefaults:ConfirmSave()
    UIManager:show(ConfirmBox:new{
        text = _("Are you sure to save the settings to \"defaults.persistent.lua\"?"),
        ok_callback = function()
            self:SaveSettings()
        end,
    })
end

function SetDefaults:SaveSettings()

    local function fileread(filename,array)
        local file = io.open(filename)
        local line = file:read()
        local counter = 0
        while line do
            counter = counter + 1
            local i = string.find(line,"[-][-]") -- remove comments from file
            if (i or 0)>1 then line = string.sub(line,1,i-1) end
            array[counter] = line:gsub("^%s*(.-)%s*$", "%1") -- trim
            line = file:read()
        end
        file:close()
    end

    local function build_setting(j)
        local ret = SetDefaults.defaults_name[j] .. " = "
        if tonumber(SetDefaults.defaults_value[j]) then
            ret = ret .. tostring(tonumber(SetDefaults.defaults_value[j]))
        elseif type(_G[SetDefaults.defaults_name[j]]) == "boolean" then
            ret = ret .. tostring(SetDefaults.defaults_value[j])
        else
            ret = ret .. "\"" .. tostring(SetDefaults.defaults_value[j]) .. "\""
        end
        return ret
    end

    local filename = "defaults.persistent.lua"
    local file
    if io.open(filename,"r") == nil then
        file = io.open(filename, "w")
        file:write("-- For configuration changes that persists between (nightly) releases\n")
        file:close()
    end

    local dpl = {}
    fileread("defaults.persistent.lua",dpl)
    local dl = {}
    fileread("defaults.lua",dl)
    self.results = {}
    self.filldefaults()
    local done = {}

    -- handle case "found in persistent", replace it
    for i = 1,#dpl do
        for j=1,#SetDefaults.defaults_name do
            if string.find(dpl[i],SetDefaults.defaults_name[j]) == 1 then
                dpl[i] = build_setting(j)
                done[j] = true
            end
        end
    end

    -- handle case "exists identical in non-persistent", ignore it
    for i = 1,#dl do
        for j=1,#SetDefaults.defaults_name do
            if dl[i]:gsub("1024[*]1024[*]10","10485760"):gsub("1024[*]1024[*]30","31457280"):gsub("[.]0$",""):gsub("([.][0-9]+)0","%1") == build_setting(j) then
                done[j] = true
            end
        end
    end

    -- handle case "not in persistent and different in non-persistent", add to persistent
    for j=1,#SetDefaults.defaults_name do
        if not done[j] then
            dpl[#dpl+1] = build_setting(j)
        end
    end

    file = io.open("defaults.persistent.lua", "w")
    for i = 1,#dpl do
        file:write(dpl[i] .. "\n")
    end
    file:close()
    UIManager:show(InfoMessage:new{text = _("Default settings successfully saved!")})
    settings_changed = false
end
return SetDefaults
