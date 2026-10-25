import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Constants";
import "ComboNext.ComboLogic";
import "ComboNext.Localization";

local L = ComboNextL;
local HEADER = "CN3";
local MAX_IMPORT_COMBOS = 60;

local function Escape(text)
    return (string.gsub(tostring(text or ""), "[^%w%._%-]", function(c)
        return string.format("%%%02X", string.byte(c));
    end));
end

local function Unescape(text)
    return (string.gsub(text, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16));
    end));
end

local function Split(text, separator)
    local parts = {};
    local start = 1;
    while (true) do
        local stop = string.find(text, separator, start, true);
        if (not stop) then
            parts[#parts + 1] = string.sub(text, start);
            break;
        end
        parts[#parts + 1] = string.sub(text, start, stop - 1);
        start = stop + 1;
    end
    return parts;
end

local function EncodeRecord(record, findSkill)
    if (type(record) == "table" and type(record.effectName) == "string") then
        return "E:" .. (record.effectScope == "target" and "T" or "S")
            .. (record.effectEvent == "lost" and "L" or "G") .. ":"
            .. Escape(record.effectName) .. ":" .. tostring(tonumber(record.icon) or "");
    end
    if (type(record) == "table" and type(record.chatPattern) == "string" and record.chatPattern ~= "") then
        return "P:" .. Escape(record.chatPattern);
    end
    if (type(record) ~= "table" or record.data == nil) then
        return "";
    end
    local kind = record.shortcutType == Turbine.UI.Lotro.ShortcutType.Item and "I" or "S";
    local name = kind == "I" and (record.itemName or record.skillName) or record.skillName;
    local data = tostring(record.data);
    if (kind == "S" and findSkill and findSkill(data)) then
        name = nil;
    end
    data = string.match(data, "^0[xX](%x+)$") or data;
    local encoded = kind .. ":" .. Escape(data) .. (name and (":" .. Escape(name)) or "");
    if (kind == "I") then
        encoded = kind .. ":" .. Escape(data) .. ":" .. Escape(name)
            .. ":" .. tostring(tonumber(record.itemCooldown) or "");
    end
    return encoded;
end

local function EncodeCombo(rules, index, findSkill)
    local name = Escape(rules[1].name);
    if (rules[1].name == L("editor.comboDefault", index)) then
        name = "";
    end
    local fields = { name };
    for _, cfg in ipairs(rules) do
        local tokens = {};
        local joins = {};
        local steps = math.max(1, math.min(ComboNextConstants.maxSteps, cfg.stepCount or 1));
        for step = 1, steps do
            tokens[step] = EncodeRecord(cfg.skills and cfg.skills[step], findSkill);
            if (step > 1) then
                joins[#joins + 1] = ComboNextLogic.GetJoin(cfg, step) == "OR" and "O" or "A";
            end
        end
        local finisher = EncodeRecord(cfg.finisher, findSkill);
        if (finisher ~= "" or table.concat(tokens) ~= "") then
            fields[#fields + 1] = tostring(steps) .. ":" .. ComboNextLogic.GetMode(cfg)
                .. ":" .. table.concat(joins);
            fields[#fields + 1] = table.concat(tokens, ",");
            fields[#fields + 1] = finisher;
        end
    end
    if (#fields == 1) then
        return nil;
    end
    return table.concat(fields, "|");
end

ComboNextShareWindow = class(Turbine.UI.Lotro.Window);

function ComboNextShareWindow:Constructor(settings, save, changed, findSkill, editor)
    Turbine.UI.Lotro.Window.Constructor(self);
    self.settings = settings;
    self.save = save;
    self.changed = changed;
    self.findSkill = findSkill;
    self.editor = editor;
    self.undo = nil;
    self:SetText(L("share.title"));
    self:SetSize(460, 350);
    self:SetPosition(
        math.max(0, math.floor((Turbine.UI.Display.GetWidth() - 460) / 2)),
        math.max(0, math.floor((Turbine.UI.Display.GetHeight() - 350) / 2))
    );

    local hint = Turbine.UI.Label();
    hint:SetParent(self);
    hint:SetPosition(16, 42);
    hint:SetSize(428, 34);
    hint:SetText(L("share.hint"));
    hint:SetForeColor(Turbine.UI.Color(0.9, 0.85, 0.65));
    self.hint = hint;

    self.box = Turbine.UI.Lotro.TextBox();
    self.box:SetParent(self);
    self.box:SetPosition(16, 80);
    self.box:SetSize(428, 170);
    self.box:SetMultiline(true);
    self.box:SetText("");

    local function addButton(x, y, w, key, handler)
        local button = Turbine.UI.Lotro.Button();
        button:SetParent(self);
        button:SetPosition(x, y);
        button:SetSize(w, 26);
        button:SetText(L(key));
        button.Click = handler;
        return button;
    end

    addButton(16, 258, 138, "share.exportAll", function() self:Export(false); end);
    addButton(160, 258, 138, "share.exportCurrent", function() self:Export(true); end);
    addButton(304, 258, 140, "share.undo", function() self:Undo(); end);
    addButton(16, 288, 138, "share.importAdd", function() self:Import(false); end);
    addButton(160, 288, 138, "share.importReplace", function() self:Import(true); end);
    addButton(304, 288, 140, "share.close", function() self:SetVisible(false); end);

    self.status = Turbine.UI.Label();
    self.status:SetParent(self);
    self.status:SetPosition(16, 320);
    self.status:SetSize(428, 20);
    self.status:SetForeColor(Turbine.UI.Color(0.9, 0.85, 0.65));
end

function ComboNextShareWindow:ApplyTheme(accent, status)
    self.hint:SetForeColor(accent);
    self.status:SetForeColor(status);
end

function ComboNextShareWindow:Export(currentOnly)
    local combos = {};
    local groups = self.editor:GetCombos();
    local function rulesOf(group)
        local rules = {};
        for _, index in ipairs(group.rules) do
            rules[#rules + 1] = self.settings.seqs[index];
        end
        return rules;
    end
    if (currentOnly) then
        local position, group = self.editor:GetComboPosition();
        combos[1] = group and EncodeCombo(rulesOf(group), position, self.findSkill) or nil;
    else
        for position, group in ipairs(groups) do
            combos[#combos + 1] = EncodeCombo(rulesOf(group), position, self.findSkill);
        end
    end
    if (#combos == 0) then
        self.status:SetText(L("share.nothing"));
        return;
    end
    local text = HEADER .. "!" .. table.concat(combos, "!");
    self.box:SetText(text);
    pcall(function()
        self.box:SelectAll();
        self.box:Focus();
    end);
    self.status:SetText(L("share.exported", #combos, #text));
end

function ComboNextShareWindow:DecodeRecord(token)
    if (token == nil or token == "") then
        return nil;
    end
    local fields = Split(token, ":");
    if (fields[1] == "P") then
        local phrase = fields[2] and Unescape(fields[2]);
        if (not phrase or phrase == "") then
            return false;
        end
        return { skillName = phrase; chatPattern = phrase; speech = true; };
    end
    if (fields[1] == "E") then
        local flags = fields[2] or "";
        local effectName = fields[3] and Unescape(fields[3]);
        if (not effectName or effectName == "" or not string.match(flags, "^[ST][GL]$")) then
            return false;
        end
        local family = string.match(effectName, "^#(%a+)$");
        local health = tonumber(string.match(effectName, "^!hp<(%d+)$"));
        return {
            skillName = family and L("editor.family", family)
                or health and L("editor.healthBelow", health) or effectName;
            effectName = effectName;
            effectFamily = family;
            healthBelow = health;
            effectScope = string.sub(flags, 1, 1) == "T" and "target" or "self";
            effectEvent = string.sub(flags, 2, 2) == "L" and "lost" or "gained";
            icon = tonumber(fields[4]);
        };
    end
    local kind, data, name = fields[1], fields[2] and Unescape(fields[2]), fields[3] and Unescape(fields[3]) or "";
    if (not data or data == "" or (kind ~= "S" and kind ~= "I")) then
        return false;
    end
    if (string.match(data, "^%x+$") and string.len(data) >= 8) then
        data = "0x" .. data;
    end
    local types = Turbine.UI.Lotro.ShortcutType;
    local shortcutType = kind == "I" and types.Item or types.Skill;
    local okShortcut, shortcut = pcall(Turbine.UI.Lotro.Shortcut, shortcutType, data);
    if (not okShortcut or not shortcut) then
        return false;
    end
    if (kind == "I") then
        local duration = tonumber(fields[4]);
        if (fields[4] and fields[4] ~= ""
            and (not duration or duration < 1 or duration > 3600 or duration % 1 ~= 0)) then
            return false;
        end
        return {
            shortcutType = shortcutType;
            data = data;
            itemName = name ~= "" and name or nil;
            skillName = name ~= "" and name or nil;
            itemCooldown = duration;
        };
    end
    local catalog = self.findSkill(data);
    local okName, gameName = pcall(function() return shortcut:GetSkillName(); end);
    if (type(gameName) == "table") then
        gameName = gameName[1];
    end
    if (not okName or type(gameName) ~= "string" or gameName == ""
        or string.match(gameName, "^0[xX]")) then
        gameName = nil;
    end
    if (not catalog and not gameName) then
        return false;
    end
    return {
        shortcutType = shortcutType;
        data = data;
        skillName = (catalog and catalog.skillName) or gameName or (name ~= "" and name or nil);
        icon = catalog and catalog.icon or nil;
    };
end

function ComboNextShareWindow:Import(replace)
    local text = string.gsub(self.box:GetText() or "", "%s+", "");
    local parts = Split(text, "!");
    if ((parts[1] ~= HEADER and parts[1] ~= "CN2" and parts[1] ~= "CN1") or #parts < 2) then
        self.status:SetText(L("share.invalid"));
        return;
    end

    local imported, skipped, groupCount = {}, 0, 0;
    for index = 2, math.min(#parts, MAX_IMPORT_COMBOS + 1) do
        local fields = Split(parts[index], "|");
        local maxSteps = ComboNextConstants.maxSteps;
        local comboName = string.sub(Unescape(fields[1] or ""), 1, 24);
        if (comboName == "") then
            comboName = L("editor.comboDefault", groupCount + 1);
        end
        local groupRules = {};
        for base = 2, #fields, 3 do
            local stepText, mode, joins;
            if (parts[1] == HEADER or parts[1] == "CN2") then
                if (parts[1] == HEADER) then
                    stepText, mode, joins = string.match(fields[base] or "", "^(%d+):(%a+):([AO]*)$");
                else
                    stepText, mode = string.match(fields[base] or "", "^(%d+):(%a+)$");
                end
                if (not stepText or (mode ~= "ordered" and mode ~= "any" and mode ~= "or"
                    and mode ~= "allConditions" and mode ~= "anyConditions")
                    or (parts[1] == HEADER and (mode == "or" or mode == "anyConditions"
                        or tonumber(stepText) < 1 or tonumber(stepText) > maxSteps
                        or #joins ~= tonumber(stepText) - 1))) then
                    self.status:SetText(L("share.invalid"));
                    return;
                end
            else
                stepText, mode = fields[base], "ordered";
            end
            local steps = math.max(1, math.min(maxSteps, math.floor(tonumber(stepText) or 1)));
            local cfg = {
                name = comboName;
                skills = {};
                stepCount = steps;
                triggerMode = mode;
                anyOrder = mode == "any" or nil;
            };
            if (joins) then
                cfg.triggerJoins = {};
                for step = 2, steps do
                    cfg.triggerJoins[step] = string.sub(joins, step - 1, step - 1) == "O"
                        and "OR" or "AND";
                end
            end
            ComboNextLogic.NormalizeRule(cfg);
            local tokens = Split(fields[base + 1] or "", ",");
            local last = 0;
            for step = 1, math.min(steps, #tokens) do
                local record = self:DecodeRecord(tokens[step]);
                if (record) then
                    cfg.skills[step] = record;
                    last = step;
                elseif (record == false) then
                    if (parts[1] == HEADER) then
                        self.status:SetText(L("share.invalid"));
                        return;
                    end
                    skipped = skipped + 1;
                end
            end
            local finisher = self:DecodeRecord(fields[base + 2]);
            if (finisher) then
                cfg.finisher = finisher;
            elseif (finisher == false) then
                skipped = skipped + 1;
            end
            if (last > 0 or cfg.finisher) then
                cfg.stepCount = math.max(1, math.min(steps, last));
                cfg.starter = last == 0 or nil;
                groupRules[#groupRules + 1] = cfg;
            else
                skipped = skipped + 1;
            end
        end
        if (#groupRules > 0) then
            groupCount = groupCount + 1;
            for _, cfg in ipairs(groupRules) do
                cfg.groupId = groupCount;
                imported[#imported + 1] = cfg;
            end
        end
    end

    if (#imported == 0) then
        self.status:SetText(L("share.noneImported", skipped));
        return;
    end

    local previous = {};
    for i = 1, #self.settings.seqs do
        previous[i] = self.settings.seqs[i];
    end
    self.undo = previous;
    local result = replace and {} or previous;
    if (not replace) then
        result = {};
        for i = 1, #previous do
            result[i] = previous[i];
        end
    end
    local offset = 0;
    for i = 1, #result do
        if (type(result[i].groupId) == "number") then
            offset = math.max(offset, result[i].groupId);
        end
    end
    for i = 1, #imported do
        imported[i].groupId = imported[i].groupId + offset;
        result[#result + 1] = imported[i];
    end
    self.settings.seqs = result;
    self:Applied();
    self.status:SetText(L("share.imported", #imported, skipped));
end

function ComboNextShareWindow:Undo()
    if (not self.undo) then
        self.status:SetText(L("share.nothingUndo"));
        return;
    end
    self.settings.seqs = self.undo;
    self.undo = nil;
    self:Applied();
    self.status:SetText(L("share.undone"));
end

function ComboNextShareWindow:Applied()
    self.save();
    self.changed();
    self.editor.comboIndex = math.max(1, math.min(self.editor.comboIndex, #self.settings.seqs));
    self.editor.selectedSlot = 1;
    self.editor:Refresh();
end
