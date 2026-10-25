import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Constants";
import "ComboNext.ComboLogic";
import "ComboNext.Localization";
import "ComboNext.ClassTriggers";

local L = ComboNextL;

ComboNextSequenceEditor = class(Turbine.UI.Lotro.Window);

local function ClassLabel(className)
    if (className == ComboNextConstants.effectsClass) then
        return L("editor.effectsClass");
    end
    return className;
end

function ComboNextSequenceEditor:Constructor(settings, getSkills, getClassNames, makeSkillRecord, save, changed, beginCapture, displayChanged, markItemReady)
    Turbine.UI.Lotro.Window.Constructor(self);
    self.settings = settings;
    self.getSkills = getSkills;
    self.getClassNames = getClassNames;
    self.makeSkillRecord = makeSkillRecord;
    self.save = save;
    self.changed = changed;
    self.displayChanged = displayChanged;
    self.markItemReady = markItemReady;
    self.comboIndex = 1;
    self.selectedSlot = 1;
    self.page = 1;
    self.pageSize = 5;
    self.maxSteps = ComboNextConstants.maxSteps;
    self.finisherSlot = self.maxSteps + 1;
    self.maxCells = 35;
    self.beginCapture = beginCapture;
    self:SetText(L("editor.title", ComboNextConstants.version));
    self:SetSize(500, 696);
    self:SetPosition(
        math.max(0, Turbine.UI.Display.GetWidth() - 510),
        math.max(0, math.floor((Turbine.UI.Display.GetHeight() - 696) / 2))
    );

    self.previousCombo = Turbine.UI.Lotro.Button();
    self.previousCombo:SetParent(self);
    self.previousCombo:SetPosition(16, 52);
    self.previousCombo:SetSize(92, 28);
    self.previousCombo:SetText(L("editor.previousCombo"));
    self.previousCombo.Click = function()
        self:MoveCombo(-1);
    end;

    self.nameBox = Turbine.UI.Lotro.TextBox();
    self.nameBox:SetParent(self);
    self.nameBox:SetPosition(16, 82);
    self.nameBox:SetSize(145, 24);
    self.nameBox:SetMultiline(false);

    self.saveName = Turbine.UI.Lotro.Button();
    self.saveName:SetParent(self);
    self.saveName:SetPosition(165, 82);
    self.saveName:SetSize(55, 24);
    self.saveName:SetText(L("editor.save"));
    self.saveName.Click = function()
        self:SaveCurrentName();
        self:Refresh();
    end;

    self.nextCombo = Turbine.UI.Lotro.Button();
    self.nextCombo:SetParent(self);
    self.nextCombo:SetPosition(370, 52);
    self.nextCombo:SetSize(112, 28);
    self.nextCombo:SetText(L("editor.nextCombo"));
    self.nextCombo.Click = function()
        self:MoveCombo(1);
    end;

    self.chooseCombo = Turbine.UI.Lotro.Button();
    self.chooseCombo:SetParent(self);
    self.chooseCombo:SetPosition(114, 52);
    self.chooseCombo:SetSize(250, 28);
    self.chooseCombo:SetText(L("editor.chooseCombo"));
    self.chooseCombo.Click = function()
        local menu = Turbine.UI.ContextMenu();
        local items = menu:GetItems();
        local combos = self:GetCombos();
        local currentPosition = self:GetComboPosition();
        local total = #combos;
        local groupSize = 10;
        local grouped = total > 12;
        local function addCombo(target, comboPosition)
            local combo = combos[comboPosition];
            local sequence = self.settings.seqs[combo.rules[1]];
            local name = type(sequence.name) == "string" and sequence.name ~= ""
                and sequence.name or L("editor.comboDefault", comboPosition);
            local label = comboPosition .. ". " .. name;
            local priority = ComboNextLogic.GetPriority(sequence);
            if (priority) then
                label = label .. " " .. L("editor.priorityTag", priority);
            end
            if (#combo.rules > 1) then
                label = label .. " " .. L("editor.rulesTag", #combo.rules);
            end
            if (self:IsGroupEmpty(combo)) then
                label = label .. " " .. L("editor.emptyTag");
            end
            local item = Turbine.UI.MenuItem(
                (comboPosition == currentPosition and "> " or "") .. label
            );
            item.Click = function()
                self:SelectCombo(combo.rules[1]);
            end;
            target:Add(item);
        end
        for first = 1, total, grouped and groupSize or total do
            local target = items;
            if (grouped) then
                local last = math.min(total, first + groupSize - 1);
                local group = Turbine.UI.MenuItem(
                    (currentPosition >= first and currentPosition <= last and "> " or "")
                    .. first .. " - " .. last
                );
                items:Add(group);
                target = group:GetItems();
            end
            for comboIndex = first, math.min(total, first + (grouped and groupSize or total) - 1) do
                addCombo(target, comboIndex);
            end
        end
        local cleanup = Turbine.UI.MenuItem(L("editor.removeEmpty"));
        cleanup.Click = function()
            self:RemoveEmptyCombos();
        end;
        items:Add(cleanup);
        if (total > 0) then
            menu:ShowMenu();
        end
    end;

    self.newCombo = Turbine.UI.Lotro.Button();
    self.newCombo:SetParent(self);
    self.newCombo:SetPosition(238, 82);
    self.newCombo:SetSize(110, 26);
    self.newCombo:SetText(L("editor.newCombo"));
    self.newCombo.Click = function()
        self:SaveCurrentName();
        self:CreateCombo();
    end;

    self.deleteCombo = Turbine.UI.Lotro.Button();
    self.deleteCombo:SetParent(self);
    self.deleteCombo:SetPosition(354, 82);
    self.deleteCombo:SetSize(128, 26);
    self.deleteCombo:SetText(L("editor.deleteCombo"));
    self.deleteCombo.Click = function()
        self:DeleteCombo();
    end;

    self.multiFinisherToggle = Turbine.UI.Lotro.Button();
    self.multiFinisherToggle:SetParent(self);
    self.multiFinisherToggle:SetPosition(16, 112);
    self.multiFinisherToggle:SetSize(210, 22);
    self.multiFinisherToggle:SetVisible(false);
    self.multiFinisherToggle.Click = function()
        self.settings.showAllFinishers = not self.settings.showAllFinishers;
        self.settings.finisherSlots = self.settings.showAllFinishers and 6 or 1;
        self.save();
        self:Refresh();
        if (self.displayChanged) then
            self.displayChanged();
        end
    end;

    self.cells = {};
    self.slots = {};
    for i = 1, self.maxCells do
        local slotIndex = i;
        local frame = Turbine.UI.Control();
        frame:SetParent(self);
        frame:SetPosition(16 + ((i - 1) % 5) * 42 - 3, 116 + math.floor((i - 1) / 5) * 42 - 3);
        frame:SetSize(42, 42);
        frame:SetMouseVisible(false);
        frame:SetZOrder(0);
        local slot = Turbine.UI.Control();
        slot:SetParent(self);
        slot.frame = frame;
        slot:SetPosition(16 + ((i - 1) % 5) * 42, 116 + math.floor((i - 1) / 5) * 42);
        slot:SetSize(36, 36);
        slot:SetMouseVisible(true);
        slot:SetAllowDrop(true);
        slot:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
        slot:SetBackColor(Turbine.UI.Color(1, 0.04, 0.04, 0.05));

        slot.quickslot = Turbine.UI.Lotro.Quickslot();
        slot.quickslot:SetParent(slot);
        slot.quickslot:SetPosition(0, 0);
        slot.quickslot:SetSize(36, 36);
        slot.quickslot:SetZOrder(1);
        slot.quickslot:SetMouseVisible(false);
        slot.quickslot:SetAllowDrop(true);

        slot.overlay = Turbine.UI.Label();
        slot.overlay:SetParent(slot);
        slot.overlay:SetPosition(3, 3);
        slot.overlay:SetSize(32, 32);
        slot.overlay:SetZOrder(2);
        slot.overlay:SetMouseVisible(false);
        slot.overlay:SetFont(Turbine.UI.Lotro.Font.Verdana10);
        slot.overlay:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
        slot.overlay:SetFontStyle(Turbine.UI.FontStyle.Outline);
        slot.overlay:SetOutlineColor(Turbine.UI.Color(1, 0, 0, 0));
        slot.overlay:SetMultiline(true);
        slot.overlay:SetMarkupEnabled(true);
        slot.overlay:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);

        slot.number = Turbine.UI.Label();
        slot.number:SetParent(slot);
        slot.number:SetSize(38, 38);
        slot.number:SetZOrder(3);
        slot.number:SetFont(Turbine.UI.Lotro.Font.TrajanPro15);
        slot.number:SetFontStyle(Turbine.UI.FontStyle.Outline);
        slot.number:SetOutlineColor(Turbine.UI.Color(1, 0, 0, 0));
        slot.number:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
        slot.number:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
        slot.number:SetMouseVisible(true);
        slot.number:SetAllowDrop(true);

        slot.joinButton = Turbine.UI.Label();
        slot.joinButton:SetParent(slot);
        slot.joinButton:SetPosition(0, 22);
        slot.joinButton:SetSize(36, 14);
        slot.joinButton:SetZOrder(4);
        slot.joinButton:SetFont(Turbine.UI.Lotro.Font.Verdana10);
        slot.joinButton:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
        slot.joinButton:SetForeColor(Turbine.UI.Color(1, 1, 0.85, 0.55));
        slot.joinButton:SetBackColor(Turbine.UI.Color(1, 0.04, 0.04, 0.05));
        slot.joinButton:SetMouseVisible(true);
        slot.joinButton.Click = function()
            local cell = self:SelectCell(slotIndex);
            if (cell) then
                self:ToggleTriggerJoin();
            end
        end;
        slot.joinButton.MouseClick = function(_, args)
            if (args.Button == Turbine.UI.MouseButton.Left) then
                slot.joinButton.Click();
            end
        end;

        local function HandleSkillDrop(_, args)
            local dragInfo = args and args.DragDropInfo;
            local shortcut = dragInfo and dragInfo:GetShortcut();
            local record = shortcut and self.makeSkillRecord(shortcut);
            local cell = self:SelectCell(slotIndex);
            if (not cell) then
                return;
            end
            if (not record) then
                if (dragInfo) then
                    dragInfo:SetSuccessful(false);
                end
                self.status:SetText(L("editor.dropSlot"));
                return;
            end
            if (cell.slot <= self.maxSteps
                and not (record.shortcutType == Turbine.UI.Lotro.ShortcutType.Skill and record.skillName)
                and not (record.shortcutType == Turbine.UI.Lotro.ShortcutType.Item and record.itemName)) then
                if (dragInfo) then
                    dragInfo:SetSuccessful(false);
                end
                self.status:SetText(L("editor.triggerUnknown"));
                return;
            end
            self:Assign(record);
            slot.quickslot:SetShortcut(Turbine.UI.Lotro.Shortcut(record.shortcutType, record.data));
            if (dragInfo) then
                dragInfo:SetSuccessful(false);
            end
        end
        slot.DragDrop = HandleSkillDrop;
        slot.quickslot.DragDrop = HandleSkillDrop;
        slot.number.DragDrop = HandleSkillDrop;
        slot.number.MouseEnter = function()
            self.hoverCell = slotIndex;
        end;
        slot.number.MouseDown = function(_, args)
            if (args.Button == Turbine.UI.MouseButton.Left) then
                self.dragFrom = slotIndex;
            end
        end;
        slot.number.MouseUp = function(_, args)
            local from, to = self.dragFrom, self.hoverCell;
            self.dragFrom = nil;
            if (from and to and from ~= to and self.cells[from] and self.cells[to]) then
                self.suppressClick = true;
                self:MoveCellTo(from, to);
            end
        end;
        slot.number.MouseClick = function(_, args)
            if (self.suppressClick) then
                self.suppressClick = false;
                return;
            end
            local cell = self:SelectCell(slotIndex);
            if (not cell) then
                return;
            end
            if (args.Button == Turbine.UI.MouseButton.Left) then
                self:Refresh();
                self:ShowSkillMenu();
                if (cell.slot == self.finisherSlot) then
                    self.status:SetText(L("editor.dropFinisher"));
                else
                    self.status:SetText(L("editor.chooseTrigger"));
                end
            elseif (args.Button == Turbine.UI.MouseButton.Right) then
                self:Clear(cell.slot);
            end
        end
        self.slots[i] = slot;
    end

    local detailTitle = Turbine.UI.Label();
    self.detailTitle = detailTitle;
    detailTitle:SetParent(self);
    detailTitle:SetPosition(230, 112);
    detailTitle:SetSize(250, 20);
    detailTitle:SetVisible(false);
    detailTitle:SetText(L("editor.selectedSlot"));
    detailTitle:SetForeColor(Turbine.UI.Color(1, 0.9, 0.5));

    self.detail = Turbine.UI.Label();
    self.detail:SetParent(self);
    self.detail:SetPosition(230, 137);
    self.detail:SetSize(250, 38);
    self.detail:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
    self.detail:SetForeColor(Turbine.UI.Color(0.95, 0.95, 0.95));

    self.triggerJoinButton = Turbine.UI.Lotro.Button();
    self.triggerJoinButton:SetParent(self);
    self.triggerJoinButton:SetPosition(230, 112);
    self.triggerJoinButton:SetSize(250, 22);
    self.triggerJoinButton.Click = function()
        self:ToggleTriggerJoin();
    end;

    self.skillTitle = Turbine.UI.Label();
    self.skillTitle:SetParent(self);
    self.skillTitle:SetPosition(230, 178);
    self.skillTitle:SetSize(250, 20);
    self.skillTitle:SetText(L("editor.classSkills"));
    self.skillTitle:SetForeColor(Turbine.UI.Color(0.8, 0.8, 0.8));

    self.classNames = self.getClassNames();
    self.selectedClass = self.settings.selectedClass or "Guardian";
    local classFound = false;
    for _, className in ipairs(self.classNames) do
        if (className == self.selectedClass) then
            classFound = true;
            break;
        end
    end
    if (not classFound) then
        self.selectedClass = self.classNames[1];
    end
    self.classButton = Turbine.UI.Lotro.Button();
    self.classButton:SetParent(self);
    self.classButton:SetPosition(230, 198);
    self.classButton:SetSize(250, 24);
    self.classButton:SetText(self.selectedClass and ClassLabel(self.selectedClass) or L("editor.chooseClass"));
    self.classButton.Click = function()
        local menu = Turbine.UI.ContextMenu();
        local items = menu:GetItems();
        for _, className in ipairs(self.classNames) do
            local selectedClass = className;
            local item = Turbine.UI.MenuItem(ClassLabel(selectedClass));
            item.Click = function()
                self.selectedClass = selectedClass;
                self.settings.selectedClass = selectedClass;
                self.classButton:SetText(ClassLabel(selectedClass));
                self.page = 1;
                self.save();
                self:Refresh();
            end;
            items:Add(item);
        end
        menu:ShowMenu();
    end

    self.searchBox = Turbine.UI.Lotro.TextBox();
    self.searchBox:SetParent(self);
    self.searchBox:SetPosition(230, 226);
    self.searchBox:SetSize(250, 24);
    self.searchBox:SetMultiline(false);
    self.searchBox:SetText("");
    self.searchBox.TextChanged = function()
        self.page = 1;
        self:Refresh();
    end

    self.skillButtons = {};
    self.skillIcons = {};
    for i = 1, self.pageSize do
        local index = i;
        local button = Turbine.UI.Lotro.Button();
        button:SetParent(self);
        button:SetPosition(260, 256 + (i - 1) * 25);
        button:SetSize(220, 24);
        button.Click = function()
            local skill = self.skills[(self.page - 1) * self.pageSize + index];
            if (skill) then
                self:Assign(skill);
            end
        end;
        self.skillButtons[i] = button;

        local icon = Turbine.UI.Label();
        icon:SetParent(self);
        icon:SetPosition(230, 256 + (i - 1) * 25);
        icon:SetSize(24, 24);
        icon:SetMouseVisible(false);
        icon:SetBackColor(Turbine.UI.Color(1, 0.08, 0.08, 0.1));
        self.skillIcons[i] = icon;
    end

    self.captureLabel = Turbine.UI.Label();
    self.captureLabel:SetParent(self);
    self.captureLabel:SetPosition(230, 462);
    self.captureLabel:SetSize(250, 18);
    self.captureLabel:SetText(L("editor.captureLabel"));
    self.captureLabel:SetForeColor(Turbine.UI.Color(0.8, 0.8, 0.8));

    self.captureText = Turbine.UI.Lotro.TextBox();
    self.captureText:SetParent(self);
    self.captureText:SetPosition(230, 482);
    self.captureText:SetSize(250, 24);
    self.captureText:SetMultiline(false);

    self.captureButton = Turbine.UI.Lotro.Button();
    self.captureButton:SetParent(self);
    self.captureButton:SetPosition(230, 512);
    self.captureButton:SetSize(120, 24);
    self.captureButton:SetText(L("editor.capture"));
    self.captureButton.Click = function()
        if (self.selectedSlot > self.maxSteps) then
            self.status:SetText(L("editor.selectTriggerCapture"));
        elseif (self.beginCapture) then
            if (self.beginCapture(self.comboIndex, self.selectedSlot)) then
                self.status:SetText(L("editor.useSkill"));
            else
                self.status:SetText(L("editor.captureCancelled"));
            end
        end
    end;

    self.useCaptureButton = Turbine.UI.Lotro.Button();
    self.useCaptureButton:SetParent(self);
    self.useCaptureButton:SetPosition(354, 512);
    self.useCaptureButton:SetSize(126, 24);
    self.useCaptureButton:SetText(L("editor.useText"));
    self.useCaptureButton.Click = function()
        local phrase = string.gsub(self.captureText:GetText() or "", "^%s*(.-)%s*$", "%1");
        if (phrase == "") then
            self.status:SetText(L("editor.captureFirst"));
            return;
        end
        if (self.selectedSlot > self.maxSteps) then
            self.status:SetText(L("editor.selectTriggerText"));
            return;
        end
        self:Assign({
            skillName = phrase;
            chatPattern = phrase;
            capturedFromChat = true;
        });
    end;

    self.previousButton = Turbine.UI.Lotro.Button();
    self.previousButton:SetParent(self);
    self.previousButton:SetPosition(230, 432);
    self.previousButton:SetSize(78, 24);
    self.previousButton:SetText(L("editor.previous"));
    self.previousButton.Click = function()
        self.page = math.max(1, self.page - 1);
        self:Refresh();
    end;

    self.nextButton = Turbine.UI.Lotro.Button();
    self.nextButton:SetParent(self);
    self.nextButton:SetPosition(314, 432);
    self.nextButton:SetSize(70, 24);
    self.nextButton:SetText(L("editor.next"));
    self.nextButton.Click = function()
        local pages = math.max(1, math.ceil(#self.skills / self.pageSize));
        self.page = math.min(pages, self.page + 1);
        self:Refresh();
    end;

    self.refreshSkillsButton = Turbine.UI.Lotro.Button();
    self.refreshSkillsButton:SetParent(self);
    self.refreshSkillsButton:SetPosition(390, 432);
    self.refreshSkillsButton:SetSize(90, 24);
    self.refreshSkillsButton:SetText(L("editor.refreshSkills"));
    self.refreshSkillsButton.Click = function()
        self.page = 1;
        self:Refresh();
    end;

    self.legendTrigger = Turbine.UI.Label();
    self.legendTrigger:SetParent(self);
    self.legendTrigger:SetPosition(16, 414);
    self.legendTrigger:SetSize(100, 18);
    self.legendTrigger:SetText(L("editor.legendTrigger"));
    self.legendTrigger:SetForeColor(Turbine.UI.Color(0.45, 0.7, 1));

    self.legendFinisher = Turbine.UI.Label();
    self.legendFinisher:SetParent(self);
    self.legendFinisher:SetPosition(118, 414);
    self.legendFinisher:SetSize(110, 18);
    self.legendFinisher:SetText(L("editor.legendFinisher"));
    self.legendFinisher:SetForeColor(Turbine.UI.Color(1, 0.8, 0.25));

    self.addPairButton = Turbine.UI.Lotro.Button();
    self.addPairButton:SetParent(self);
    self.addPairButton:SetPosition(16, 440);
    self.addPairButton:SetSize(202, 26);
    self.addPairButton:SetText(L("editor.addPair"));
    self.addPairButton.Click = function()
        self:InsertCell("P");
    end;


    self.moveLeftButton = Turbine.UI.Lotro.Button();
    self.moveLeftButton:SetParent(self);
    self.moveLeftButton:SetPosition(16, 530);
    self.moveLeftButton:SetSize(98, 26);
    self.moveLeftButton:SetText(L("editor.moveLeft"));
    self.moveLeftButton.Click = function()
        self:MoveCell(-1);
    end;

    self.moveRightButton = Turbine.UI.Lotro.Button();
    self.moveRightButton:SetParent(self);
    self.moveRightButton:SetPosition(120, 530);
    self.moveRightButton:SetSize(98, 26);
    self.moveRightButton:SetText(L("editor.moveRight"));
    self.moveRightButton.Click = function()
        self:MoveCell(1);
    end;

    self.addTriggerButton = Turbine.UI.Lotro.Button();
    self.addTriggerButton:SetParent(self);
    self.addTriggerButton:SetPosition(16, 470);
    self.addTriggerButton:SetSize(98, 26);
    self.addTriggerButton:SetText(L("editor.addTrigger"));
    self.addTriggerButton.Click = function()
        self:InsertCell("T");
    end;

    self.addFinisherButton = Turbine.UI.Lotro.Button();
    self.addFinisherButton:SetParent(self);
    self.addFinisherButton:SetPosition(120, 470);
    self.addFinisherButton:SetSize(98, 26);
    self.addFinisherButton:SetText(L("editor.addFinisher"));
    self.addFinisherButton.Click = function()
        self:InsertCell("F");
    end;

    self.removeCellButton = Turbine.UI.Lotro.Button();
    self.removeCellButton:SetParent(self);
    self.removeCellButton:SetPosition(16, 500);
    self.removeCellButton:SetSize(98, 26);
    self.removeCellButton:SetText(L("editor.removeCell"));
    self.removeCellButton.Click = function()
        self:RemoveCell();
    end;

    self.clearButton = Turbine.UI.Lotro.Button();
    self.clearButton:SetParent(self);
    self.clearButton:SetPosition(120, 500);
    self.clearButton:SetSize(98, 26);
    self.clearButton:SetText(L("editor.clearSlot"));
    self.clearButton.Click = function()
        self:Clear(self.selectedSlot);
    end;

    self.resetComboButton = Turbine.UI.Lotro.Button();
    self.resetComboButton:SetParent(self);
    self.resetComboButton:SetPosition(16, 560);
    self.resetComboButton:SetSize(98, 26);
    self.resetComboButton:SetText(L("editor.clearAll"));
    self.resetComboButton.Click = function()
        self:ResetCombo();
    end;
    self.priorityButton = Turbine.UI.Lotro.Button();
    self.priorityButton:SetParent(self);
    self.priorityButton:SetPosition(120, 560);
    self.priorityButton:SetSize(98, 26);
    self.priorityButton.Click = function()
        local _, combo = self:GetComboPosition();
        if (not combo) then
            return;
        end
        local menu = Turbine.UI.ContextMenu();
        local current = ComboNextLogic.GetPriority(self.settings.seqs[combo.rules[1]]);
        for level = 0, 9 do
            local priority = level > 0 and level or nil;
            local label = level == 0 and L("editor.priorityNone")
                or L("editor.priorityLevel", level);
            if (level == 1) then
                label = L("editor.priorityHighest");
            elseif (level == 9) then
                label = L("editor.priorityLowest");
            end
            local item = Turbine.UI.MenuItem((current == priority and "> " or "") .. label);
            item.Click = function()
                for _, index in ipairs(combo.rules) do
                    self.settings.seqs[index].priority = priority;
                end
                self.save();
                self:Refresh();
                if (self.displayChanged) then
                    self.displayChanged();
                end
                self.status:SetText(L("editor.priorityHint"));
            end;
            menu:GetItems():Add(item);
        end
        menu:ShowMenu();
    end;
    self.effectScope = "self";
    self.effectEvent = "gained";
    self.scopeButton = Turbine.UI.Lotro.Button();
    self.scopeButton:SetParent(self);
    self.scopeButton:SetPosition(230, 404);
    self.scopeButton:SetSize(120, 24);
    self.scopeButton.Click = function()
        self.effectScope = self.effectScope == "self" and "target" or "self";
        self:Refresh();
    end;
    self.eventButton = Turbine.UI.Lotro.Button();
    self.eventButton:SetParent(self);
    self.eventButton:SetPosition(360, 404);
    self.eventButton:SetSize(120, 24);
    self.eventButton.Click = function()
        self.effectEvent = self.effectEvent == "gained" and "lost" or "gained";
        self:Refresh();
    end;

    self.anyOrderButton = Turbine.UI.Lotro.Button();
    self.anyOrderButton:SetParent(self);
    self.anyOrderButton:SetPosition(230, 576);
    self.anyOrderButton:SetSize(250, 26);
    self.anyOrderButton.Click = function()
        local _, combo = self:GetComboPosition();
        if (not combo) then
            return;
        end
        local menu = Turbine.UI.ContextMenu();
        for _, mode in ipairs({ "ordered", "any", "allConditions" }) do
            local selectedMode = mode;
            local item = Turbine.UI.MenuItem(L("editor.mode." .. mode));
            item.Click = function()
                for _, index in ipairs(combo.rules) do
                    ComboNextLogic.NormalizeRule(self.settings.seqs[index]);
                    self.settings.seqs[index].triggerMode = selectedMode;
                    self.settings.seqs[index].anyOrder = selectedMode == "any" or nil;
                end
                self.save();
                self.changed();
                self:Refresh();
                self.status:SetText(L("editor.modeHint." .. selectedMode));
            end;
            menu:GetItems():Add(item);
        end
        menu:ShowMenu();
    end;

    self.itemTimerLabel = Turbine.UI.Label();
    self.itemTimerLabel:SetParent(self);
    self.itemTimerLabel:SetPosition(16, 608);
    self.itemTimerLabel:SetSize(146, 24);
    self.itemTimerLabel:SetText(L("editor.itemCooldown"));
    self.itemTimerLabel:SetForeColor(Turbine.UI.Color(0.95, 0.95, 0.95));
    self.itemTimerText = Turbine.UI.Lotro.TextBox();
    self.itemTimerText:SetParent(self);
    self.itemTimerText:SetPosition(166, 608);
    self.itemTimerText:SetSize(56, 24);
    self.itemTimerText:SetMultiline(false);
    self.itemTimerSave = Turbine.UI.Lotro.Button();
    self.itemTimerSave:SetParent(self);
    self.itemTimerSave:SetPosition(230, 608);
    self.itemTimerSave:SetSize(96, 24);
    self.itemTimerSave:SetText(L("editor.save"));
    self.itemTimerSave.Click = function()
        local sequence = self.settings.seqs[self.comboIndex];
        local record = sequence and (self.selectedSlot == self.finisherSlot
            and sequence.finisher or sequence.skills[self.selectedSlot]);
        local duration = tonumber(self.itemTimerText:GetText());
        if (not duration or duration < 1 or duration > 3600 or duration % 1 ~= 0) then
            self.status:SetText(L("editor.itemCooldownInvalid"));
            return;
        end
        if (record and record.shortcutType == Turbine.UI.Lotro.ShortcutType.Item) then
            local name = record.itemName or record.skillName;
            for _, cfg in ipairs(self.settings.seqs) do
                local function UpdateItem(item)
                    if (type(item) == "table" and item.shortcutType == record.shortcutType
                        and (item.itemName or item.skillName) == name) then
                        item.itemCooldown = duration;
                    end
                end
                UpdateItem(cfg.finisher);
                for _, item in pairs(cfg.skills) do
                    UpdateItem(item);
                end
            end
            self.save();
            self:Refresh();
            self.status:SetText(L("editor.itemTimerSaved"));
        end
    end;
    self.itemReadyButton = Turbine.UI.Lotro.Button();
    self.itemReadyButton:SetParent(self);
    self.itemReadyButton:SetPosition(334, 608);
    self.itemReadyButton:SetSize(146, 24);
    self.itemReadyButton:SetText(L("editor.markReady"));
    self.itemReadyButton.Click = function()
        local sequence = self.settings.seqs[self.comboIndex];
        local record = sequence and (self.selectedSlot == self.finisherSlot
            and sequence.finisher or sequence.skills[self.selectedSlot]);
        if (record and self.markItemReady) then
            self.markItemReady(record);
            self.status:SetText(L("editor.itemMarkedReady"));
        end
    end;
    self.classValueLabel = Turbine.UI.Label();
    self.classValueLabel:SetParent(self);
    self.classValueLabel:SetPosition(16, 608);
    self.classValueLabel:SetSize(180, 24);
    self.classValueLabel:SetText(L("class.configure"));
    self.classValueLabel:SetForeColor(Turbine.UI.Color(0.95, 0.95, 0.95));
    self.classCompareButton = Turbine.UI.Lotro.Button();
    self.classCompareButton:SetParent(self);
    self.classCompareButton:SetPosition(200, 608);
    self.classCompareButton:SetSize(68, 24);
    self.classCompare = "ge";
    self.classCompareButton.Click = function()
        local sequence = self.settings.seqs[self.comboIndex];
        local record = sequence and sequence.skills[self.selectedSlot];
        local definition = record and ComboNextClassTriggers.Definition(record.classTrigger);
        if (not definition or definition.boolean) then
            return;
        end
        local choices = { "lt", "le", "eq", "ge", "gt" };
        for index, choice in ipairs(choices) do
            if (choice == self.classCompare) then
                self.classCompare = choices[index % #choices + 1];
                break;
            end
        end
        self.classCompareButton:SetText(L("class.compare." .. self.classCompare));
    end;
    self.classValueText = Turbine.UI.Lotro.TextBox();
    self.classValueText:SetParent(self);
    self.classValueText:SetPosition(276, 608);
    self.classValueText:SetSize(66, 24);
    self.classValueText:SetMultiline(false);
    self.classValueSave = Turbine.UI.Lotro.Button();
    self.classValueSave:SetParent(self);
    self.classValueSave:SetPosition(350, 608);
    self.classValueSave:SetSize(130, 24);
    self.classValueSave:SetText(L("editor.save"));
    self.classValueSave.Click = function()
        local sequence = self.settings.seqs[self.comboIndex];
        local old = sequence and sequence.skills[self.selectedSlot];
        local record = old and ComboNextClassTriggers.Record(old.classTrigger,
            self.classCompare, tonumber(self.classValueText:GetText()));
        if (not record) then
            self.status:SetText(L("class.invalidValue"));
            return;
        end
        self:Assign(record);
    end;
    self.shareButton = Turbine.UI.Lotro.Button();
    self.shareButton:SetParent(self);
    self.shareButton:SetPosition(230, 546);
    self.shareButton:SetSize(250, 26);
    self.shareButton:SetText(L("share.button"));
    self.shareButton.Click = function()
        if (self.openShare) then
            self.openShare();
        end
    end;

    self.status = Turbine.UI.Label();
    self.status:SetParent(self);
    self.status:SetPosition(16, 640);
    self.status:SetSize(466, 44);
    self.status:SetText(L("editor.instructions"));
    self.status:SetForeColor(Turbine.UI.Color(0.9, 0.85, 0.65));

    self:SelectLastCell();
    self:Refresh();
    self:SetVisible(true);
end

function ComboNextSequenceEditor:EnsureGroups()
    local maxId = 0;
    for _, sequence in ipairs(self.settings.seqs) do
        if (type(sequence.groupId) == "number") then
            maxId = math.max(maxId, sequence.groupId);
        end
    end
    for _, sequence in ipairs(self.settings.seqs) do
        if (type(sequence.groupId) ~= "number") then
            maxId = maxId + 1;
            sequence.groupId = maxId;
        end
    end
    ComboNextLogic.NormalizePriorities(self.settings.seqs);
end

function ComboNextSequenceEditor:NextGroupId()
    local maxId = 0;
    for _, sequence in ipairs(self.settings.seqs) do
        if (type(sequence.groupId) == "number") then
            maxId = math.max(maxId, sequence.groupId);
        end
    end
    return maxId + 1;
end

-- A combo is the list of rules (trigger steps plus a finisher) sharing a groupId.
function ComboNextSequenceEditor:GetCombos()
    self:EnsureGroups();
    local combos, byId = {}, {};
    for index, sequence in ipairs(self.settings.seqs) do
        local combo = byId[sequence.groupId];
        if (not combo) then
            combo = { id = sequence.groupId; rules = {}; };
            byId[sequence.groupId] = combo;
            combos[#combos + 1] = combo;
        end
        combo.rules[#combo.rules + 1] = index;
    end
    return combos;
end

-- Returns combo position, combo, rule position, combo list for the current rule.
function ComboNextSequenceEditor:GetComboPosition()
    local combos = self:GetCombos();
    for comboPosition, combo in ipairs(combos) do
        for rulePosition, index in ipairs(combo.rules) do
            if (index == self.comboIndex) then
                return comboPosition, combo, rulePosition, combos;
            end
        end
    end
    return 0, nil, 0, combos;
end

function ComboNextSequenceEditor:IsRuleEmpty(sequence)
    if (sequence.finisher) then
        return false;
    end
    for step = 1, self.maxSteps do
        if (sequence.skills and sequence.skills[step]) then
            return false;
        end
    end
    return true;
end

function ComboNextSequenceEditor:IsGroupEmpty(combo)
    for _, index in ipairs(combo.rules) do
        if (not self:IsRuleEmpty(self.settings.seqs[index])) then
            return false;
        end
    end
    return true;
end

function ComboNextSequenceEditor:SelectCell(cellIndex)
    local cell = self.cells and self.cells[cellIndex];
    if (cell) then
        self.comboIndex = cell.rule;
        self.selectedSlot = cell.slot;
    end
    return cell;
end

-- Flattens the current combo into trigger/finisher cells, one per slot of each rule.
function ComboNextSequenceEditor:GetChain(combo)
    local chain = {};
    for _, index in ipairs(combo.rules) do
        local sequence = self.settings.seqs[index];
        for step = 1, ((sequence.starter or sequence.shared) and 0 or math.max(1, sequence.stepCount or 1)) do
            chain[#chain + 1] = { role = "T"; record = sequence.skills and sequence.skills[step];
                rule = index; slot = step; join = ComboNextLogic.GetJoin(sequence, step) };
        end
        if (not sequence.open) then
            chain[#chain + 1] = { role = "F"; record = sequence.finisher; rule = index; slot = self.finisherSlot; };
        end
    end
    return chain;
end

function ComboNextSequenceEditor:FindCell(chain)
    for position, cell in ipairs(chain) do
        if (cell.rule == self.comboIndex and cell.slot == self.selectedSlot) then
            return position;
        end
    end
    return nil;
end

-- Rebuilds the combo's rules from a flat chain: triggers collect until a finisher closes the rule.
function ComboNextSequenceEditor:ApplyChain(combo, chain, selectPosition)
    local first = combo.rules[1];
    local template = self.settings.seqs[first];
    local rules = {};
    local current = { skills = {}; joins = {}; count = 0; };
    local function flush(finisher, finisherEmpty, starter, shared, open)
        rules[#rules + 1] = {
            anyOrder = template.anyOrder;
            triggerMode = ComboNextLogic.GetMode(template);
            starter = starter or nil;
            shared = shared or nil;
            open = open or nil;
            name = template.name;
            groupId = template.groupId;
            priority = template.priority;
            skills = current.skills;
            triggerJoins = current.joins;
            stepCount = math.max(1, current.count);
            finisher = finisher;
            emptyFinisher = finisherEmpty and true or nil;
        };
        current = { skills = {}; joins = {}; count = 0; };
    end
    local landing = {};
    for position, cell in ipairs(chain) do
        if (cell.role == "T") then
            if (current.count >= self.maxSteps) then
                flush();
            end
            current.count = current.count + 1;
            current.skills[current.count] = cell.record;
            if (current.count > 1) then
                current.joins[current.count] = cell.join or "AND";
            end
            landing[position] = { rule = #rules + 1; slot = current.count; };
        else
            local starter, shared = false, false;
            if (current.count == 0) then
                local previous = rules[#rules];
                if (not previous or previous.starter) then
                    starter = true;
                else
                    shared = true;
                    for step = 1, previous.stepCount do
                        current.skills[step] = previous.skills[step];
                        if (step > 1) then
                            current.joins[step] = previous.triggerJoins[step];
                        end
                    end
                    current.count = previous.stepCount;
                end
            end
            landing[position] = { rule = #rules + 1; slot = self.finisherSlot; };
            flush(cell.record, cell.record == nil, starter, shared);
        end
    end
    if (current.count > 0) then
        flush(nil, false, false, false, true);
    elseif (#rules == 0) then
        flush();
    end
    for position = #combo.rules, 1, -1 do
        table.remove(self.settings.seqs, combo.rules[position]);
    end
    for position, rule in ipairs(rules) do
        table.insert(self.settings.seqs, first + position - 1, rule);
    end
    local target = landing[selectPosition] or landing[#chain] or { rule = 1; slot = 1; };
    self.comboIndex = first + target.rule - 1;
    self.selectedSlot = target.slot;
    self.save();
    self.changed();
    self:Refresh();
end

function ComboNextSequenceEditor:ToggleTriggerJoin()
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    local position = chain and self:FindCell(chain);
    local cell = position and chain[position];
    if (not cell or cell.role ~= "T" or cell.slot <= 1) then
        return;
    end
    cell.join = cell.join == "OR" and "AND" or "OR";
    self:ApplyChain(combo, chain, position);
    self.status:SetText(L("editor.joinHint"));
end

function ComboNextSequenceEditor:InsertCell(role)
    local _, combo = self:GetComboPosition();
    if (not combo) then
        self.status:SetText(L("editor.createFirst"));
        return;
    end
    local chain = self:GetChain(combo);
    local needed = role == "P" and 2 or 1;
    if (#chain + needed > self.maxCells) then
        self.status:SetText(L("editor.chainFull", self.maxCells));
        return;
    end
    local position = (self:FindCell(chain) or #chain) + 1;
    if (role == "P") then
        position = #chain + 1;
        table.insert(chain, position, { role = "T"; });
        table.insert(chain, position + 1, { role = "F"; });
        self:ApplyChain(combo, chain, position);
        self.status:SetText(L("editor.pairAdded"));
        return;
    end
    table.insert(chain, position, { role = role; });
    self:ApplyChain(combo, chain, position);
    self.status:SetText(L(role == "T" and "editor.triggerAdded" or "editor.finisherAdded"));
end

function ComboNextSequenceEditor:SwitchRole()
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    local position = chain and self:FindCell(chain);
    if (not position) then
        return;
    end
    local cell = chain[position];
    local record = cell.record;
    if (cell.role == "T") then
        if (record and not (record.shortcutType and record.data ~= nil)) then
            self.status:SetText(L("editor.roleBlocked"));
            return;
        end
        cell.role = "F";
    else
        if (record and not (record.chatPattern or record.effectName or record.classTrigger
            or (record.shortcutType == Turbine.UI.Lotro.ShortcutType.Skill and record.skillName)
            or (record.shortcutType == Turbine.UI.Lotro.ShortcutType.Item and record.itemName))) then
            self.status:SetText(L("editor.triggerUnknown"));
            return;
        end
        cell.role = "T";
    end
    self:ApplyChain(combo, chain, position);
    self.status:SetText(L(cell.role == "T" and "editor.nowTrigger" or "editor.nowFinisher"));
end

function ComboNextSequenceEditor:MoveCellTo(from, to)
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    if (not chain or not chain[from] or not chain[to]) then
        return;
    end
    table.insert(chain, to, table.remove(chain, from));
    self:ApplyChain(combo, chain, to);
    self.status:SetText(L("editor.moved"));
end

function ComboNextSequenceEditor:MoveCell(delta)
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    local position = chain and self:FindCell(chain);
    if (position and chain[position + delta]) then
        self:MoveCellTo(position, position + delta);
    end
end

function ComboNextSequenceEditor:RemoveCell()
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    local position = chain and self:FindCell(chain);
    if (not position) then
        return;
    end
    table.remove(chain, position);
    self:ApplyChain(combo, chain, math.max(1, position - 1));
    self.status:SetText(L("editor.cellRemoved"));
end

function ComboNextSequenceEditor:SaveCurrentName()
    local comboPosition, combo = self:GetComboPosition();
    if (not combo) then
        return;
    end
    local name = string.gsub(self.nameBox:GetText() or "", "^%s*(.-)%s*$", "%1");
    if (name == "") then
        name = L("editor.comboDefault", comboPosition);
    end
    name = string.sub(name, 1, 24);
    local renamed = false;
    for _, index in ipairs(combo.rules) do
        local sequence = self.settings.seqs[index];
        if (sequence.name ~= name) then
            sequence.name = name;
            renamed = true;
        end
    end
    if (renamed) then
        self.save();
        self.changed();
    end
end

function ComboNextSequenceEditor:MoveCombo(delta)
    local comboPosition, _, _, combos = self:GetComboPosition();
    local target = combos[comboPosition + delta];
    if (target) then
        self:SelectCombo(target.rules[1]);
    end
end

function ComboNextSequenceEditor:SelectLastCell()
    local _, combo = self:GetComboPosition();
    local chain = combo and self:GetChain(combo);
    local last = chain and chain[#chain];
    if (last) then
        self.comboIndex = last.rule;
        self.selectedSlot = last.slot;
    end
end

function ComboNextSequenceEditor:SelectCombo(comboIndex)
    if (not self.settings.seqs[comboIndex]) then
        return false;
    end
    self:SaveCurrentName();
    self.comboIndex = comboIndex;
    self.selectedSlot = 1;
    self:SelectLastCell();
    self:Refresh();
    return true;
end

function ComboNextSequenceEditor:Assign(skill, slotIndex)
    if (skill and skill.classTrigger) then
        skill = ComboNextClassTriggers.Record(skill.classTrigger, skill.classCompare, skill.classValue);
        if (not skill) then
            self.status:SetText(L("class.invalid"));
            return;
        end
    elseif (skill and skill.effectName) then
        skill = {
            skillName = (skill.effectFamily or skill.healthBelow) and skill.skillName or skill.effectName;
            effectName = skill.effectName;
            effectFamily = skill.effectFamily;
            healthBelow = skill.healthBelow;
            effectScope = self.effectScope;
            effectEvent = skill.healthBelow and "gained" or self.effectEvent;
            icon = skill.icon;
        };
    end
    local sequence = self.settings.seqs[self.comboIndex];
    if (not sequence) then
        self.status:SetText(L("editor.createFirst"));
        return;
    end
    if (slotIndex) then
        self.selectedSlot = slotIndex;
    end
    if (self.selectedSlot == self.finisherSlot) then
        if (not skill.shortcutType or skill.data == nil) then
            self.status:SetText(L("editor.setNext"));
            return;
        end
        sequence.finisher = skill;
        sequence.emptyFinisher = nil;
    else
        sequence.skills[self.selectedSlot] = skill;
        sequence.stepCount = math.max(sequence.stepCount or 1, self.selectedSlot);
    end
    self.save();
    self.changed();
    self:Refresh();
    local savedName = skill.skillName or skill.itemName or L("editor.shortcut");
    self.status:SetText(self.selectedSlot == self.finisherSlot
        and L("editor.savedNext", savedName)
        or L("editor.savedTrigger", savedName, self.selectedSlot));
end

function ComboNextSequenceEditor:Clear(slotIndex)
    local sequence = self.settings.seqs[self.comboIndex];
    if (not sequence) then
        return;
    end
    if (slotIndex == self.finisherSlot) then
        sequence.finisher = nil;
        sequence.emptyFinisher = true;
    else
        sequence.skills[slotIndex] = nil;
    end
    self.save();
    self.changed();
    self.status:SetText(L("editor.slotCleared"));
    self:Refresh();
end

function ComboNextSequenceEditor:SelectSlot(comboIndex, slotIndex)
    if (not self.settings.seqs[comboIndex]) then
        return false;
    end
    self:SaveCurrentName();
    self.comboIndex = math.max(1, math.min(comboIndex, #self.settings.seqs));
    local maximumSlot = self.finisherSlot;
    self.selectedSlot = math.max(1, math.min(slotIndex or 1, maximumSlot));
    self:Refresh();
    return true;
end

function ComboNextSequenceEditor:ResetCombo()
    local _, combo = self:GetComboPosition();
    if (not combo) then
        return;
    end
    self:SaveCurrentName();
    self:ApplyChain(combo, { { role = "T"; }, { role = "F"; } }, 1);
    self.page = 1;
    self.status:SetText(L("editor.chainCleared"));
end

function ComboNextSequenceEditor:CreateCombo()
    local combos = self:GetCombos();
    local index = #self.settings.seqs + 1;
    local comboNumber = #combos + 1;
    self.settings.seqs[index] = {
        name = L("editor.comboDefault", comboNumber);
        groupId = self:NextGroupId();
        skills = {};
        stepCount = 1;
        emptyFinisher = true;
    };
    self.comboIndex = index;
    self.selectedSlot = self.finisherSlot;
    self.page = 1;
    self.save();
    self.changed(index);
    self.status:SetText(L("editor.created", comboNumber));
    self:Refresh();
end

function ComboNextSequenceEditor:RemoveEmptyCombos()
    self:SaveCurrentName();
    local current = self.settings.seqs[self.comboIndex];
    local kept, removed = {}, 0;
    for _, sequence in ipairs(self.settings.seqs) do
        if (self:IsRuleEmpty(sequence) and sequence ~= current) then
            removed = removed + 1;
        else
            kept[#kept + 1] = sequence;
        end
    end
    if (removed == 0) then
        self.status:SetText(L("editor.emptyRemoved", 0));
        return;
    end
    self.settings.seqs = kept;
    for index, sequence in ipairs(kept) do
        if (sequence == current) then
            self.comboIndex = index;
        end
    end
    self.selectedSlot = 1;
    self.save();
    self.changed();
    self.status:SetText(L("editor.emptyRemoved", removed));
    self:Refresh();
end

function ComboNextSequenceEditor:DeleteCombo()
    local _, combo = self:GetComboPosition();
    if (not combo) then
        return;
    end
    for position = #combo.rules, 1, -1 do
        table.remove(self.settings.seqs, combo.rules[position]);
    end
    self.comboIndex = math.max(1, math.min(combo.rules[1], #self.settings.seqs));
    self.selectedSlot = 1;
    self.save();
    self.changed();
    self.status:SetText(L("editor.comboDeleted"));
    self:Refresh();
end

function ComboNextSequenceEditor:Refresh()
    self.skills = self.getSkills(self.selectedClass, self.searchBox:GetText());
    local effectsMode = self.selectedClass == ComboNextConstants.effectsClass;
    self.scopeButton:SetVisible(effectsMode);
    self.eventButton:SetVisible(effectsMode);
    self.scopeButton:SetText(L(self.effectScope == "self" and "editor.scopeSelf" or "editor.scopeTarget"));
    self.eventButton:SetText(L(self.effectEvent == "gained" and "editor.eventGained" or "editor.eventLost"));
    local comboCount = #self.settings.seqs;
    self.comboIndex = math.max(1, math.min(self.comboIndex, comboCount));
    local sequence = self.settings.seqs[self.comboIndex];
    local comboPosition, combo, rulePosition, combos = self:GetComboPosition();
    local ruleCount = combo and #combo.rules or 0;
    local comboName = sequence and (sequence.name or L("editor.comboDefault", comboPosition));
    self.chooseCombo:SetText(sequence
        and L("editor.comboLabel", string.sub(comboName, 1, 14))
        or L("editor.chooseCombo"));
    self.previousCombo:SetEnabled(comboCount > 0 and comboPosition > 1);
    self.nextCombo:SetEnabled(comboPosition > 0 and comboPosition < #combos);
    self.chooseCombo:SetEnabled(comboCount > 0);
    self.saveName:SetEnabled(sequence ~= nil);
    self.deleteCombo:SetEnabled(sequence ~= nil);
    self.multiFinisherToggle:SetText(L("editor.showFinishers",
        L(self.settings.showAllFinishers and "editor.on" or "editor.off")));
    self.multiFinisherToggle:SetEnabled(true);
    self.anyOrderButton:SetEnabled(sequence ~= nil);
    self.anyOrderButton:SetText(L("editor.mode." .. ComboNextLogic.GetMode(sequence or {})));
    self.nameBox:SetEnabled(sequence ~= nil);
    self.nameBox:SetText(sequence and sequence.name or "");
    self.clearButton:SetEnabled(sequence ~= nil);
    self.resetComboButton:SetEnabled(sequence ~= nil);
    self.priorityButton:SetEnabled(sequence ~= nil);
    local priority = sequence and ComboNextLogic.GetPriority(sequence);
    self.priorityButton:SetText(L("editor.priorityButton",
        priority and tostring(priority) or L("editor.priorityNoneShort")));
    self.captureButton:SetEnabled(sequence ~= nil and self.selectedSlot <= self.maxSteps);
    self.useCaptureButton:SetEnabled(sequence ~= nil and self.selectedSlot <= self.maxSteps);
    self.addPairButton:SetEnabled(sequence ~= nil);
    self.addTriggerButton:SetEnabled(sequence ~= nil);
    self.addFinisherButton:SetEnabled(sequence ~= nil);
    self.moveLeftButton:SetEnabled(sequence ~= nil);
    self.moveRightButton:SetEnabled(sequence ~= nil);
    self.removeCellButton:SetEnabled(sequence ~= nil);

    local stepCount = sequence and (sequence.stepCount or 1) or 0;
    if (sequence and not sequence.stepCount) then
        for i = 1, self.maxSteps do
            if (sequence.skills[i]) then
                stepCount = i;
            end

        end
        sequence.stepCount = math.max(stepCount, 1);
    end

    self.cells = combo and self:GetChain(combo) or {};
    for i = 1, self.maxCells do
        local slot = self.slots[i];
        local cell = self.cells[i];
        local value = cell and cell.record;
        local isFinisher = cell and cell.role == "F";
        slot:SetVisible(cell ~= nil);
        slot.quickslot:SetVisible(cell ~= nil);
        slot.overlay:SetVisible(cell ~= nil);
        slot.number:SetVisible(cell ~= nil);
        slot.frame:SetVisible(cell ~= nil);
        local showJoin = cell and cell.role == "T" and cell.slot > 1;
        slot.joinButton:SetVisible(showJoin == true);
        slot.joinButton:SetText(showJoin and L("editor.join." .. cell.join) or "");
        slot.frame:SetBackColor(isFinisher and Turbine.UI.Color(1, 0.95, 0.7, 0.1)
            or Turbine.UI.Color(1, 0.25, 0.55, 1));
        slot.number:SetText(cell and tostring(i) or "");
        slot.number:SetForeColor(cell and cell.rule == self.comboIndex and cell.slot == self.selectedSlot
            and Turbine.UI.Color(1, 1, 0.65, 0.25)
            or Turbine.UI.Color(1, 1, 1));
        local shortcutType = value and (value.shortcutType or value.type or value.Type);
        local shortcutData = value and (value.data or value.Data);
        if (cell and shortcutType and shortcutData ~= nil) then
            slot.quickslot:SetShortcut(Turbine.UI.Lotro.Shortcut(shortcutType, shortcutData));
            slot.overlay:SetBackground(nil);
        else
            slot.quickslot:SetShortcut(Turbine.UI.Lotro.Shortcut());
            slot.overlay:SetBackground(cell and value and value.icon or nil);
        end
    end

    local selected = sequence and (self.selectedSlot == self.finisherSlot
        and sequence.finisher or sequence.skills[self.selectedSlot]);
    local selectedTitle = self.selectedSlot == self.finisherSlot
        and L("editor.recommended") or L("editor.triggerSkill", self.selectedSlot);
    local canJoin = sequence ~= nil and self.selectedSlot > 1 and self.selectedSlot <= self.maxSteps;
    self.triggerJoinButton:SetVisible(canJoin);
    self.triggerJoinButton:SetText(canJoin and L("editor.joinPrevious",
        L("editor.join." .. ComboNextLogic.GetJoin(sequence, self.selectedSlot))) or "");
    local itemSelected = type(selected) == "table"
        and selected.shortcutType == Turbine.UI.Lotro.ShortcutType.Item;
    for _, control in ipairs({ self.itemTimerLabel, self.itemTimerText,
        self.itemTimerSave, self.itemReadyButton }) do
        control:SetVisible(itemSelected);
    end
    self.itemTimerText:SetText(itemSelected and tostring(selected.itemCooldown or "") or "");
    self.itemReadyButton:SetEnabled(itemSelected and tonumber(selected.itemCooldown) ~= nil
        and tonumber(selected.itemCooldown) >= 1);
    local classSelected = type(selected) == "table" and selected.classTrigger ~= nil
        and self.selectedSlot ~= self.finisherSlot;
    for _, control in ipairs({ self.classValueLabel, self.classCompareButton,
        self.classValueText, self.classValueSave }) do
        control:SetVisible(classSelected);
    end
    if (classSelected) then
        self.classCompare = selected.classCompare;
        self.classCompareButton:SetText(L("class.compare." .. self.classCompare));
        local definition = ComboNextClassTriggers.Definition(selected.classTrigger);
        self.classCompareButton:SetEnabled(definition ~= nil and not definition.boolean);
        self.classValueText:SetText(tostring(selected.classValue));
        self.classValueLabel:SetText(definition and L("class.range",
            definition.min or 0, definition.max or 1) or L("class.configure"));
    end
    self.detail:SetText(sequence and (selectedTitle .. "\n"
        .. ((selected and selected.effectName and L("editor.effectDetail", (selected.effectFamily or selected.healthBelow) and selected.skillName or selected.effectName,
                L(selected.effectScope == "target" and "editor.scopeTarget" or "editor.scopeSelf"),
                L(selected.effectEvent == "lost" and "editor.eventLost" or "editor.eventGained")))
            or (selected and selected.skillName)
            or (selected and selected.itemName)
            or (selected and (self.selectedSlot > self.maxSteps
                and L("editor.dropActionbar") or L("editor.chooseCatalog")))
            or L("editor.emptySlot"))
        or L("editor.createToStart")));

    local pages = math.max(1, math.ceil(#self.skills / self.pageSize));
    self.page = math.min(self.page, pages);
    self.skillTitle:SetText(L("editor.skillsCount", ClassLabel(self.selectedClass), #self.skills));
    for i = 1, self.pageSize do
        local skill = self.skills[(self.page - 1) * self.pageSize + i];
        self.skillButtons[i]:SetVisible(sequence ~= nil and skill ~= nil);
        self.skillIcons[i]:SetVisible(sequence ~= nil and skill ~= nil);
        if (skill) then
            self.skillButtons[i]:SetText(skill.skillName);
            self.skillIcons[i]:SetBackground(skill.icon);
        end
    end
    self.previousButton:SetEnabled(self.page > 1);
    self.nextButton:SetEnabled(self.page < pages);
    if (not sequence) then
        self.status:SetText(L("editor.createHint"));
    elseif (#self.skills == 0) then
        self.status:SetText(L("editor.noSkills"));
    else
        self.status:SetText(L("editor.chooseSkill"));
    end
    if (effectsMode and #(self.searchBox:GetText() or "") < 2) then
        self.status:SetText(L("editor.effectHint"));
    end
    if (classSelected) then
        local definition = ComboNextClassTriggers.Definition(selected.classTrigger);
        self.status:SetText(L(definition and definition.boolean and "class.hint.boolean"
            or definition and definition.slot and "class.hint.gambit"
            or selected.classTrigger == "balance" and "class.hint.balance" or "class.hint.numeric"));
    end
end

function ComboNextSequenceEditor:CaptureChatMessage(message, mode)
    self.speechCaptured = mode == "speech";
    if (self.speechCaptured) then
        local quoted = string.match(message or "", "^[^'\"]-[,:]%s*['\"](.*)['\"]%s*$");
        message = quoted or message;
    end
    self.captureText:SetText(message or "");
    self.status:SetText(L("editor.captured"));
end

function ComboNextSequenceEditor:ApplyTheme(accent, status)
    self.skillTitle:SetForeColor(accent);
    self.detailTitle:SetForeColor(accent);
    self.captureLabel:SetForeColor(accent);
    self.status:SetForeColor(status);
end

function ComboNextSequenceEditor:ShowSkillMenu()
    local menu = Turbine.UI.ContextMenu();
    local menuItems = menu:GetItems();
    for _, className in ipairs(self.classNames) do
        local selectedClass = className;
        local classItem = Turbine.UI.MenuItem(ClassLabel(selectedClass));
        menuItems:Add(classItem);
        local classItems = classItem:GetItems();
        local skills = self.getSkills(selectedClass, "");
        for _, skill in ipairs(skills) do
            local selectedSkill = skill;
            local skillItem = Turbine.UI.MenuItem(selectedSkill.skillName);
            classItems:Add(skillItem);
            skillItem.Click = function()
                self.selectedClass = selectedClass;
                self.settings.selectedClass = selectedClass;
                self.classButton:SetText(ClassLabel(selectedClass));
                self.searchBox:SetText("");
                self:Assign(selectedSkill, self.selectedSlot);
            end;
        end
    end
    menu:ShowMenu();
end
