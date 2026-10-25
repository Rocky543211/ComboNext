import "Turbine.Gameplay";
import "ComboNext.Localization";

ComboNextClassTriggers = {};
local M = ComboNextClassTriggers;
local L = ComboNextL;
local definitions = {
    focus = { class = "Hunter"; getter = "GetFocus"; event = "FocusChanged"; min = 0; max = 9; default = 3 };
    fervour = { class = "Champion"; getter = "GetFervor"; event = "FervorChanged"; min = 0; max = 5; default = 5 };
    wrath = { class = "Beorning"; getter = "GetWrath"; event = "WrathChanged"; min = 0; max = 100; default = 50 };
    bear = { class = "Beorning"; getter = "IsInBearForm"; boolean = true };
    battle = { class = "RuneKeeper"; getter = "GetAttunement"; event = "AttunementChanged"; min = 0; max = 9; default = 3 };
    healing = { class = "RuneKeeper"; getter = "GetAttunement"; event = "AttunementChanged"; min = 0; max = 9; default = 3 };
    charged = { class = "RuneKeeper"; getter = "IsCharged"; boolean = true };
    balance = { class = "Mariner"; getter = "GetBalance"; event = "BalanceChanged"; min = -1000; max = 1000; default = 0 };
    mettle = { class = "Brawler"; effect = "mettle"; min = 0; max = 9; default = 3 };
    fortification = { class = "Guardian"; effect = "fortification"; min = 0; max = 5; default = 5 };
    technique = { class = "Warden"; effect = "technique"; min = 0; max = 5; default = 1 };
};
local order = { "focus", "fervour", "wrath", "bear", "battle", "healing",
    "charged", "balance", "mettle", "fortification", "technique" };
local stanceChoices = {
    Hunter = { "Endurance", "Precision", "Strength" };
    Warden = { "Assailment", "Determination" };
    Minstrel = { "Melody", "Dissonance", "Resonance" };
};
for _, className in ipairs({ "Hunter", "Warden", "Minstrel" }) do
    local choices = stanceChoices[className];
    for _, choice in ipairs(choices) do
        local key = className .. "_" .. choice;
        definitions[key] = { class = className; getter = "GetStance"; event = "StanceChanged";
            stance = choice; boolean = true };
        order[#order + 1] = key;
    end
end
for slot = 1, 5 do
    local key = "gambit" .. slot;
    definitions[key] = { class = "Warden"; getter = "GetGambit"; event = "GambitChanged";
        slot = slot; min = 0; max = 3; default = 1 };
    order[#order + 1] = key;
end
local comparators = {
    lt = function(a, b) return a < b; end;
    le = function(a, b) return a <= b; end;
    eq = function(a, b) return a == b; end;
    ge = function(a, b) return a >= b; end;
    gt = function(a, b) return a > b; end;
};
local symbols = { lt = "<"; le = "<="; eq = "="; ge = ">="; gt = ">" };

function M.Definition(key)
    return definitions[key];
end

function M.Validate(record)
    local definition = type(record) == "table" and definitions[record.classTrigger];
    if (not definition or not comparators[record.classCompare]) then
        return false;
    end
    local value = record.classValue;
    if (type(value) ~= "number" or value ~= value or value % 1 ~= 0) then
        return false;
    end
    if (definition.boolean) then
        return record.classCompare == "eq" and (value == 0 or value == 1);
    end
    return value >= definition.min and value <= definition.max;
end

function M.Label(record)
    local definition = definitions[record.classTrigger];
    if (not definition) then
        return L("class.invalid");
    end
    local name = definition.slot and L("class.gambit", definition.slot)
        or definition.stance and L("class.stance", L("class." .. definition.stance))
        or L("class." .. record.classTrigger);
    if (definition.boolean) then
        return L(record.classValue == 1 and "class.is" or "class.isNot", name);
    end
    return name .. " " .. (symbols[record.classCompare] or "?") .. " " .. tostring(record.classValue);
end

function M.Record(key, compare, value)
    local record = { classTrigger = key; classCompare = compare; classValue = value };
    if (not M.Validate(record)) then
        return nil;
    end
    record.skillName = M.Label(record);
    return record;
end

function M.Key(record)
    return "@class:" .. record.classTrigger .. ":" .. record.classCompare .. ":" .. record.classValue;
end

function M.Catalog(className)
    local records = {};
    for _, key in ipairs(order) do
        local definition = definitions[key];
        if (definition.class == className) then
            if (definition.min == 0 and not definition.slot) then
                for value = 1, definition.max do
                    records[#records + 1] = M.Record(key, "ge", value);
                end
            else
                records[#records + 1] = M.Record(key, definition.boolean and "eq"
                    or definition.slot and "eq" or "ge", definition.boolean and 1 or definition.default);
            end
        end
    end
    return records;
end

local romans = { I = 1; II = 2; III = 3; IV = 4; V = 5 };
local function ReadEffectResource(player, resource, locale)
    if (locale ~= "en" and resource ~= "mettle") then
        return nil, L("class.effectLanguage");
    end
    local patterns = {
        en = "^Battle Flow (%d+)$";
        de = "^Kampffluss %(Stufe (%d+)%)$";
        fr = "^Flot de Bataille (%d+)$";
    };
    if (resource == "mettle" and not patterns[locale]) then
        return nil, L("class.effectLanguage");
    end
    local highest = 0;
    local effects = player:GetEffects();
    for index = 1, effects:GetCount() do
        local name = effects:Get(index):GetName();
        local value;
        if (resource == "mettle") then
            value = tonumber(string.match(name, patterns[locale]));
        elseif (resource == "fortification") then
            value = romans[string.match(name, "^Improved Fortification ([IV]+)$")];
        else
            value = romans[string.match(name, "^Advanced Technique ([IV]+)$")];
        end
        if (value) then
            if (value > (resource == "mettle" and 9 or 5)) then
                return nil, L("class.apiUnavailable");
            end
            highest = math.max(highest, value);
        end
    end
    return highest;
end

-- Stance reads are unreliable after trait changes until an explicit stance selection.
function M.Read(record, player, locale, confirmedStance)
    if (not M.Validate(record)) then
        return nil, L("class.invalid");
    end
    local definition = definitions[record.classTrigger];
    local ok, value, reason = pcall(function()
        local classes = Turbine.Gameplay.Class or {};
        if (not player.GetClass or classes[definition.class] == nil
            or player:GetClass() ~= classes[definition.class]) then
            return nil, L("class.wrongClass");
        end
        if (definition.effect) then
            return ReadEffectResource(player, definition.effect, locale);
        end
        local attributes = player:GetClassAttributes();
        if (not attributes or type(attributes[definition.getter]) ~= "function") then
            return nil, L("class.apiUnavailable");
        end
        if (definition.stance) then
            if (not confirmedStance or not confirmedStance[attributes]) then
                return nil, L("class.selectStance");
            end
            local enums = Turbine.Gameplay.Attributes or {};
            local stances = enums[definition.class .. "Stance"] or {};
            local expected = stances[definition.stance];
            if (definition.class == "Minstrel") then
                local known = { Melody = 0; Dissonance = 1; Resonance = 2 };
                expected = known[definition.stance];
            end
            local actual = attributes:GetStance();
            local valid = false;
            for _, choice in ipairs(stanceChoices[definition.class]) do
                local candidate = stances[choice];
                if (definition.class == "Minstrel") then
                    candidate = ({ Melody = 0; Dissonance = 1; Resonance = 2 })[choice];
                end
                if (candidate ~= nil and actual == candidate) then
                    valid = true;
                end
            end
            if (expected == nil or not valid) then
                return nil, L("class.apiUnavailable");
            end
            return actual == expected and 1 or 0;
        end
        if (definition.slot and (not attributes.GetMaxGambitCount
            or definition.slot > attributes:GetMaxGambitCount())) then
            return nil, L("class.apiUnavailable");
        end
        local result;
        if (definition.slot) then
            result = attributes:GetGambit(definition.slot);
        else
            result = attributes[definition.getter](attributes);
        end
        if (definition.boolean) then
            if (type(result) ~= "boolean") then
                return nil, L("class.apiUnavailable");
            end
            return result and 1 or 0;
        end
        if (type(result) ~= "number" or result ~= result) then
            return nil, L("class.apiUnavailable");
        end
        if (record.classTrigger == "battle" or record.classTrigger == "healing") then
            if (result < 1 or result > 19 or result % 1 ~= 0) then
                return nil, L("class.apiUnavailable");
            end
            result = math.max(0, record.classTrigger == "battle" and 10 - result or result - 10);
        end
        if (result < definition.min or result > definition.max or result % 1 ~= 0) then
            return nil, L("class.apiUnavailable");
        end
        return result;
    end);
    if (not ok) then
        return nil, L("class.readError", tostring(value));
    end
    return value, reason;
end

function M.Evaluate(record, player, locale, confirmedStance)
    local value, reason = M.Read(record, player, locale, confirmedStance);
    if (value == nil) then
        return nil, M.Label(record) .. ": " .. (reason or L("class.apiUnavailable"));
    end
    return comparators[record.classCompare](value, record.classValue),
        L("class.currentValue", M.Label(record), value);
end

function M.Events(player, attributes)
    local events, seen = {}, {};
    local classes = Turbine.Gameplay.Class or {};
    for _, key in ipairs(order) do
        local definition = definitions[key];
        if (definition.event and not seen[definition.event] and player.GetClass
            and classes[definition.class] ~= nil and player:GetClass() == classes[definition.class]
            and type(attributes[definition.getter]) == "function") then
            seen[definition.event] = true;
            events[#events + 1] = definition.event;
        end
    end
    return events;
end
