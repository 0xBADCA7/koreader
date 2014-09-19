local lfs = require("libs/libkoreader-lfs")
local DocSettings = {}

function DocSettings:getHistoryPath(fullpath)
    return "./history/[" .. fullpath:gsub("(.*/)([^/]+)","%1] %2"):gsub("/","#") .. ".lua"
end

function DocSettings:getPathFromHistory(hist_name)
    -- 1. select everything included in brackets
    local s = string.match(hist_name,"%b[]")
    -- 2. crop the bracket-sign from both sides
    -- 3. and finally replace decorative signs '#' to dir-char '/'
    return string.gsub(string.sub(s,2,-3),"#","/")
end

function DocSettings:getNameFromHistory(hist_name)
    -- at first, search for path length
    local s = string.len(string.match(hist_name,"%b[]"))
    -- and return the rest of string without 4 last characters (".lua")
    return string.sub(hist_name, s+2, -5)
end

function DocSettings:open(docfile)
    local history_path = nil
    local sidecar_path = nil
    if docfile == ".reader" then
        -- we handle reader setting as special case
        history_path = "settings.reader.lua"
    else
        if lfs.attributes("./history", "mode") ~= "directory" then
            lfs.mkdir("history")
        end
        history_path = self:getHistoryPath(docfile)

        local sidecar = docfile:match("(.*)%.")..".sdr"
        if lfs.attributes(sidecar, "mode") ~= "directory" then
            lfs.mkdir(sidecar)
        end
        sidecar_path = sidecar.."/"..docfile:match(".*%/(.*)")..".lua"
    end
    -- construct settings obj
    local new = {
        history_file = history_path,
        sidecar_file = sidecar_path,
        data = {}
    }
    local ok, stored = pcall(dofile, new.history_file or "")
    if not ok then
        ok, stored = pcall(dofile, new.sidecar_file or "")
        if not ok then
            -- try legacy conf path, for backward compatibility. this also
            -- takes care of reader legacy setting
            ok, stored = pcall(dofile, docfile..".kpdfview.lua")
        end
    end
    if ok and stored then
        new.data = stored
    end
    return setmetatable(new, { __index = DocSettings})
end

function DocSettings:readSetting(key)
    return self.data[key]
end

function DocSettings:saveSetting(key, value)
    self.data[key] = value
end

function DocSettings:delSetting(key)
    self.data[key] = nil
end

function DocSettings:dump(data, max_lv)
    local out = {}
    self:_serialize(data, out, 0, max_lv)
    return table.concat(out)
end

-- simple serialization function, won't do uservalues, functions, loops
function DocSettings:_serialize(what, outt, indent, max_lv)
    if not max_lv then
        max_lv = math.huge
    end

    if indent > max_lv then
        return
    end

    if type(what) == "table" then
        local didrun = false
        table.insert(outt, "{")
        for k, v in pairs(what) do
            if didrun then
                table.insert(outt, ",")
            end
            table.insert(outt, "\n")
            table.insert(outt, string.rep("\t", indent+1))
            table.insert(outt, "[")
            self:_serialize(k, outt, indent+1, max_lv)
            table.insert(outt, "] = ")
            self:_serialize(v, outt, indent+1, max_lv)
            didrun = true
        end
        if didrun then
            table.insert(outt, "\n")
            table.insert(outt, string.rep("\t", indent))
        end
        table.insert(outt, "}")
    elseif type(what) == "string" then
        table.insert(outt, string.format("%q", what))
    elseif type(what) == "number" or type(what) == "boolean" then
        table.insert(outt, tostring(what))
    end
end

function DocSettings:flush()
    -- write serialized version of the data table into
    --  i) history directory in root directory of koreader
    -- ii) sidecar directory in the same directory of the document
    if not self.history_file and not self.sidecar_file then
        return
    end

    local serials = {}
    if self.history_file then
        pcall(table.insert, serials, io.open(self.history_file, "w"))
    end
    if self.sidecar_file then
        pcall(table.insert, serials, io.open(self.sidecar_file, "w"))
    end
    os.setlocale('C', 'numeric')
    local out = {"-- we can read Lua syntax here!\nreturn "}
    self:_serialize(self.data, out, 0)
    table.insert(out, "\n")
    local s_out = table.concat(out)
    for _, f_out in ipairs(serials) do
        if f_out ~= nil then
            f_out:write(s_out)
            f_out:close()
        end
    end
end

function DocSettings:close()
    self:flush()
end

return DocSettings
