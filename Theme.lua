import "Turbine";
import "Turbine.Gameplay";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Localization";

ComboNextTheme = {};
local T = ComboNextTheme;
local L = ComboNextL;
T.races = { "Gondorian", "Man", "Elf", "Dwarf", "Hobbit", "Beorning",
    "HighElf", "StoutAxe", "RiverHobbit" };
T.classes = { "Beorning", "Brawler", "Burglar", "Captain", "Champion", "Guardian",
    "Hunter", "LoreMaster", "Mariner", "Minstrel", "RuneKeeper", "Warden" };
T.modes = { "automatic", "race", "class", "raceClass" };
local raceColours = {
    Gondorian = { 0.78, 0.65, 0.40 }; Man = { 0.82, 0.69, 0.44 };
    Elf = { 0.62, 0.79, 0.65 }; Dwarf = { 0.83, 0.61, 0.36 };
    Hobbit = { 0.78, 0.70, 0.43 }; Beorning = { 0.81, 0.64, 0.43 };
    HighElf = { 0.75, 0.78, 0.94 }; StoutAxe = { 0.86, 0.55, 0.36 };
    RiverHobbit = { 0.54, 0.79, 0.76 };
};
local classColours = {
    Beorning = { 0.88, 0.69, 0.43 }; Brawler = { 0.86, 0.70, 0.50 };
    Burglar = { 0.80, 0.69, 0.88 }; Captain = { 0.88, 0.80, 0.49 };
    Champion = { 0.92, 0.60, 0.47 }; Guardian = { 0.70, 0.82, 0.92 };
    Hunter = { 0.65, 0.83, 0.54 }; LoreMaster = { 0.60, 0.82, 0.78 };
    Mariner = { 0.54, 0.80, 0.89 }; Minstrel = { 0.90, 0.74, 0.86 };
    RuneKeeper = { 0.71, 0.73, 0.97 }; Warden = { 0.85, 0.73, 0.51 };
};
local painters = setmetatable({}, { __mode = "k" });
local profile = { race = "Gondorian"; colour = raceColours.Gondorian; custom = true };
local function Contains(values, value)
    for _, candidate in ipairs(values) do
        if (candidate == value) then return true; end
    end
    return false;
end

local function Detect(player, method, enum, names)
    if (not player or type(player[method]) ~= "function") then return nil; end
    local ok, value = pcall(player[method], player);
    if (not ok) then return nil; end
    for _, name in ipairs(names) do
        if (enum and enum[name] ~= nil and value == enum[name]) then return name; end
    end
    return nil;
end

function T.Resolve(settings, player, gameplay)
    local mode = Contains(T.modes, settings.appearanceMode) and settings.appearanceMode or "automatic";
    local race = Contains(T.races, settings.appearanceRace) and settings.appearanceRace or nil;
    local className = Contains(T.classes, settings.appearanceClass) and settings.appearanceClass or nil;
    local warnings = {};
    if (mode == "automatic" or (mode ~= "class" and not race)) then
        race = Detect(player, "GetRace", gameplay.Race, T.races);
        if (not race) then warnings[#warnings + 1] = L("theme.raceUnknown"); end
    end
    if (mode == "automatic" or ((mode == "class" or mode == "raceClass") and not className)) then
        className = Detect(player, "GetClass", gameplay.Class, T.classes);
        if (not className) then warnings[#warnings + 1] = L("theme.classUnknown"); end
    end
    race = race or "Gondorian";
    if (mode == "race") then className = nil; end
    if (mode == "class") then race = "Gondorian"; end
    return {
        mode = mode; race = race; class = className; custom = settings.uiStyle ~= "classic";
        colour = mode == "class" and className and classColours[className] or raceColours[race];
        warning = #warnings > 0 and table.concat(warnings, " ") or nil;
    };
end

function T.Configure(settings, player)
    if (settings.uiStyle ~= "classic" and settings.uiStyle ~= "custom") then
        settings.uiStyle = "custom";
    end
    if (not Contains(T.modes, settings.appearanceMode)) then
        settings.appearanceMode = "automatic";
    end
    settings.uiTheme = nil;
    if (not Contains(T.races, settings.appearanceRace)) then settings.appearanceRace = "automatic"; end
    if (not Contains(T.classes, settings.appearanceClass)) then settings.appearanceClass = "automatic"; end
    profile = T.Resolve(settings, player, Turbine.Gameplay);
    for control in pairs(painters) do control.themePaint(control); end
    return profile;
end

function T.Profile()
    return profile;
end

function T.Accent()
    return Turbine.UI.Color(unpack(profile.colour));
end

function T.Text()
    return Turbine.UI.Color(0.94, 0.91, 0.83);
end

function T.Background()
    local colour = profile.colour;
    return Turbine.UI.Color(1, 0.025 + colour[1] * 0.045,
        0.025 + colour[2] * 0.045, 0.025 + colour[3] * 0.045);
end

local function Register(control, paint)
    control.themePaint = paint;
    painters[control] = true;
    paint(control);
end

local function Line(parent)
    local control = Turbine.UI.Control();
    control:SetParent(parent);
    control:SetMouseVisible(false);
    return control;
end

local function CloseOnEscape(control, args)
    if (args.Key ~= 27) then return; end
    local owner = control:GetParent();
    while (owner) do
        if (owner.themeClose) then owner:SetVisible(false); return; end
        owner = owner:GetParent();
    end
end

-- A native button remains available in classic mode; both faces share one handler.
function T.Button()
    local button = Turbine.UI.Control();
    local native = Turbine.UI.Lotro.Button();
    native:SetParent(button);
    local face = Turbine.UI.Label();
    face:SetParent(button);
    face:SetMouseVisible(false);
    face:SetMultiline(true);
    face:SetFont(Turbine.UI.Lotro.Font.Verdana12 or Turbine.UI.Lotro.Font.Verdana10);
    face:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
    local edges = { Line(button), Line(button), Line(button), Line(button) };
    local hover, pressed, focused, explicitFont = false, false, false, nil;
    button:SetWantsKeyEvents(true);
    local function Paint()
        local enabled = button:IsEnabled();
        native:SetVisible(not profile.custom);
        face:SetVisible(profile.custom);
        button:SetBackColor(profile.custom and (not enabled and Turbine.UI.Color(0.065, 0.075, 0.08)
            or pressed and Turbine.UI.Color(0.10, 0.13, 0.15)
            or (hover or focused) and Turbine.UI.Color(0.18, 0.22, 0.24)
            or T.Background()) or Turbine.UI.Color(0, 0, 0, 0));
        face:SetForeColor(enabled and T.Text() or Turbine.UI.Color(0.62, 0.64, 0.62));
        for _, edge in ipairs(edges) do
            edge:SetVisible(profile.custom);
            edge:SetBackColor(enabled and T.Accent() or Turbine.UI.Color(0.30, 0.34, 0.35));
        end
    end
    local size, enable = button.SetSize, button.SetEnabled;
    button.SetSize = function(self, width, height)
        size(self, width, height);
        native:SetSize(width, height);
        face:SetFont(explicitFont or (width < 120 and Turbine.UI.Lotro.Font.Verdana10
            or Turbine.UI.Lotro.Font.Verdana12) or Turbine.UI.Lotro.Font.Verdana10);
        face:SetSize(math.max(0, width - 8), height);
        face:SetPosition(4, 0);
        local rects = { { 0, 0, width, 1 }, { 0, height - 1, width, 1 },
            { 0, 0, 1, height }, { width - 1, 0, 1, height } };
        for index, edge in ipairs(edges) do
            local rect = rects[index];
            edge:SetPosition(rect[1], rect[2]); edge:SetSize(rect[3], rect[4]);
        end
    end;
    button.SetText = function(_, text) face:SetText(text); native:SetText(text); end;
    button.GetText = function() return face:GetText(); end;
    button.SetEnabled = function(self, enabled)
        enable(self, enabled); native:SetEnabled(enabled);
        if (not enabled) then hover, pressed, focused = false, false, false; end
        Paint();
    end;
    button.SetForeColor = function(_, colour) face:SetForeColor(colour); native:SetForeColor(colour); end;
    button.SetFont = function(_, font)
        explicitFont = font; face:SetFont(font); native:SetFont(font);
    end;
    button.SetTextAlignment = function(_, alignment)
        face:SetTextAlignment(alignment); native:SetTextAlignment(alignment);
    end;
    local function Activate()
        if (button:IsEnabled() and button.Click) then button.Click(button, {}); end
    end
    native.Click = Activate;
    native.KeyDown = CloseOnEscape;
    button.MouseEnter = function() hover = true; Paint(); end;
    button.MouseLeave = function() hover, pressed = false, false; Paint(); end;
    button.MouseDown = function(_, args)
        if (button:IsEnabled() and args.Button == Turbine.UI.MouseButton.Left) then
            pressed = true; button:Focus(); Paint();
        end
    end;
    button.MouseUp = function() pressed = false; Paint(); end;
    button.MouseClick = function(_, args)
        if (args.Button == Turbine.UI.MouseButton.Left) then Activate(); end
    end;
    button.FocusGained = function() focused = true; Paint(); end;
    button.FocusLost = function() focused, pressed = false, false; Paint(); end;
    button.KeyDown = function(_, args)
        if (args.Key == 13 or args.Key == 32) then Activate();
        else CloseOnEscape(button, args); end
    end;
    button.EnabledChanged = Paint;
    button.themeNative, button.themeFace = native, face;
    button.themeEdges = edges;
    Register(button, Paint);
    return button;
end

function T.TextBox()
    local box = Turbine.UI.Lotro.TextBox();
    box.KeyDown = CloseOnEscape;
    Register(box, function()
        box:SetFont(Turbine.UI.Lotro.Font.Verdana12 or Turbine.UI.Lotro.Font.Verdana10);
        box:SetForeColor(T.Text());
        box:SetBackColor(profile.custom and T.Background()
            or Turbine.UI.Color(1, 0, 0, 0));
    end);
    return box;
end

-- Opaque artwork covers only the window chrome, never the interactive contents.
function T.DecorateWindow(window, advisor)
    local body = Line(window);
    body:SetBackColor(Turbine.UI.Color(0.045, 0.06, 0.075));
    local header = Turbine.UI.Control();
    header:SetParent(window);
    header:SetSize(0, 34);
    local emblem, badge = Line(header), Line(header);
    emblem:SetSize(28, 28); emblem:SetPosition(6, 3);
    badge:SetSize(28, 28);
    local caption = Turbine.UI.Label();
    caption:SetParent(header); caption:SetMouseVisible(false);
    caption:SetPosition(42, 4);
    caption:SetFont(Turbine.UI.Lotro.Font.TrajanProBold16 or Turbine.UI.Lotro.Font.Verdana14
        or Turbine.UI.Lotro.Font.Verdana10);
    local trim = { Line(window), Line(window), Line(window), Line(window) };
    local close;
    if (not advisor) then
        close = T.Button();
        close:SetParent(header); close:SetSize(24, 24); close:SetText("X");
        close.Click = function() window:SetVisible(false); end;
    end
    local nativeSize, nativeText = window.SetSize, window.SetText;
    local function Layout()
        local width, height = window:GetWidth(), window:GetHeight();
        body:SetSize(width, height); header:SetSize(width, 34);
        local artWidth = ({ [390] = true, [430] = true, [460] = true, [500] = true })[width]
            and width or 500;
        header:SetBackground("ComboNext/Resources/header_" .. tostring(artWidth) .. ".tga");
        caption:SetSize(math.max(0, width - 125), 26);
        badge:SetPosition(width - (advisor and 31 or 62), 3);
        if (close) then close:SetPosition(width - 29, 4); end
        trim[1]:SetPosition(0, 34); trim[1]:SetSize(1, math.max(0, height - 34));
        trim[2]:SetPosition(width - 1, 34); trim[2]:SetSize(1, math.max(0, height - 34));
        trim[3]:SetPosition(0, height - 1); trim[3]:SetSize(width, 1);
        trim[4]:SetPosition(8, 33); trim[4]:SetSize(math.max(0, width - 16), 1);
    end
    window.SetSize = function(self, width, height) nativeSize(self, width, height); Layout(); end;
    if (not advisor) then
        window.SetText = function(self, text) nativeText(self, text); caption:SetText(text); end;
    end
    local moving, mx, my, left, top;
    header.MouseDown = function(_, args)
        if (args.Button ~= Turbine.UI.MouseButton.Left) then return; end
        moving = true; mx, my = Turbine.UI.Display.GetMousePosition();
        left, top = window:GetPosition();
        window:Activate();
    end;
    header.MouseMove = function()
        if (not moving) then return; end
        local x, y = Turbine.UI.Display.GetMousePosition();
        local scale = T.scale or 1;
        window:SetPosition(
            math.max(0, math.min(left + x - mx, Turbine.UI.Display.GetWidth() - window:GetWidth() * scale)),
            math.max(0, math.min(top + y - my, Turbine.UI.Display.GetHeight() - window:GetHeight() * scale)));
    end;
    header.MouseUp = function() moving = false; end;
    local visibleChanged = window.VisibleChanged;
    window.VisibleChanged = function(...)
        moving = false;
        if (visibleChanged) then visibleChanged(...); end
    end;
    window.themeHeader = header;
    window.themeBadge = badge;
    window.themeEmblem = emblem;
    window.themeBody = body;
    window.themeClose = close;
    window.themeCaption = caption;
    window.KeyDown = function(_, args)
        if (args.Key == 27 and close) then window:SetVisible(false); end
    end;
    Register(window, function()
        moving = false;
        body:SetBackColor(T.Background());
        body:SetVisible(profile.custom); header:SetVisible(profile.custom);
        emblem:SetVisible(profile.custom);
        caption:SetVisible(not advisor);
        emblem:SetBackground("ComboNext/Resources/race_" .. profile.race .. ".tga");
        badge:SetVisible(profile.custom and profile.class ~= nil);
        badge:SetBackground(profile.class and ("ComboNext/Resources/class_" .. profile.class .. ".tga") or nil);
        caption:SetForeColor(T.Text());
        for _, line in ipairs(trim) do
            line:SetVisible(profile.custom); line:SetBackColor(T.Accent());
        end
        Layout();
    end);
    return header;
end
