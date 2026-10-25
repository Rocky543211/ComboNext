ComboNextLogic = {};

function ComboNextLogic.GetPriority(cfg)
    local priority = cfg.priority;
    if (type(priority) == "number" and priority >= 1 and priority <= 9
        and priority % 1 == 0) then
        return priority;
    end
    return nil;
end

-- A combo's first rule owns the priority; all of its finisher rules share it.
function ComboNextLogic.NormalizePriorities(seqs)
    local firstByGroup = {};
    for _, cfg in ipairs(seqs) do
        if (cfg.groupId ~= nil) then
            local first = firstByGroup[cfg.groupId];
            if (first) then
                cfg.priority = first.priority;
            else
                firstByGroup[cfg.groupId] = cfg;
            end
        end
    end
end

function ComboNextLogic.OrderRules(seqs)
    local order, firstByGroup, positions = {}, {}, {};
    for index, cfg in ipairs(seqs) do
        order[index] = index;
        local first = cfg.groupId ~= nil and firstByGroup[cfg.groupId] or nil;
        if (not first) then
            first = index;
            if (cfg.groupId ~= nil) then
                firstByGroup[cfg.groupId] = first;
            end
        end
        positions[index] = first;
    end
    table.sort(order, function(a, b)
        local firstA, firstB = positions[a], positions[b];
        local priorityA = ComboNextLogic.GetPriority(seqs[firstA]) or 10;
        local priorityB = ComboNextLogic.GetPriority(seqs[firstB]) or 10;
        if (priorityA ~= priorityB) then
            return priorityA < priorityB;
        elseif (firstA ~= firstB) then
            return firstA < firstB;
        end
        return a < b;
    end);
    return order;
end

function ComboNextLogic.GetMode(cfg)
    local mode = cfg.triggerMode or (cfg.anyOrder and "any" or "ordered");
    if (mode == "or") then
        return "ordered";
    elseif (mode == "anyConditions") then
        return "allConditions";
    end
    return mode;
end

function ComboNextLogic.GetJoin(cfg, index)
    if (index <= 1) then
        return "AND";
    end
    local join = cfg.triggerJoins and cfg.triggerJoins[index];
    if (join) then
        return join;
    end
    return (cfg.triggerMode == "or" or cfg.triggerMode == "anyConditions") and "OR" or "AND";
end

function ComboNextLogic.NormalizeRule(cfg)
    local joins = {};
    for index = 2, cfg.stepCount or 1 do
        joins[index] = ComboNextLogic.GetJoin(cfg, index);
    end
    cfg.triggerJoins = joins;
    cfg.triggerMode = ComboNextLogic.GetMode(cfg);
end

-- AND groups are alternatives separated by OR.
function ComboNextLogic.GetGroups(triggers)
    local groups = {};
    for index, trigger in ipairs(triggers) do
        if (index == 1 or trigger.join == "OR") then
            groups[#groups + 1] = { mode = triggers.mode; first = index };
        end
        local group = groups[#groups];
        group[#group + 1] = trigger;
    end
    return groups;
end

function ComboNextLogic.IsCurrent(mode)
    return mode == "allConditions" or mode == "anyConditions";
end

local function AdvanceGroup(state, triggers, matches)
    if (#triggers == 0) then
        state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
        return;
    end
    if (state.done) then
        state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
    end
    if (triggers.mode == "any") then
        local used = {};
        for _, name in ipairs(state.matched) do
            for index, trigger in ipairs(triggers) do
                if (not used[index] and trigger.name == name) then
                    used[index] = true;
                    break;
                end
            end
        end
        for index, trigger in ipairs(triggers) do
            if (not used[index] and matches(trigger)) then
                state.matched[#state.matched + 1] = trigger.name;
                break;
            end
        end
        state.progress = #state.matched;
        state.done = state.progress == #triggers;
        return;
    end
    local candidate = math.min(state.progress + 1, #triggers);
    while (candidate > 0) do
        local matched = true;
        for index = 1, candidate do
            local observedIndex = state.progress + 1 - candidate + index;
            if (observedIndex <= state.progress) then
                matched = state.matched[observedIndex] == triggers[index].name;
            else
                matched = matches(triggers[index]);
            end
            if (not matched) then
                break;
            end
        end
        if (matched) then
            break;
        end
        candidate = candidate - 1;
    end
    state.progress, state.done, state.matched = candidate, candidate == #triggers, {};
    for index = 1, candidate do
        state.matched[index] = triggers[index].name;
    end
end

function ComboNextLogic.Advance(state, triggers, matches)
    local groups = ComboNextLogic.GetGroups(triggers);
    if (#groups <= 1) then
        AdvanceGroup(state, triggers, matches);
        return;
    end
    if (state.done) then
        state.branches = nil;
    end
    state.branches = state.branches or {};
    local best;
    for index, group in ipairs(groups) do
        local branch = state.branches[index] or { progress = 0; done = false; matched = {} };
        state.branches[index] = branch;
        AdvanceGroup(branch, group, matches);
        if (not best or (branch.done and not best.done)
            or (branch.done == best.done and branch.progress > best.progress)) then
            best = branch;
        end
    end
    state.progress, state.done, state.matched = best.progress, best.done, best.matched;
end

function ComboNextLogic.EvaluateConditions(state, triggers, evaluate)
    state.progress, state.matched, state.conditions = 0, {}, {};
    for index, trigger in ipairs(triggers) do
        local satisfied, detail = evaluate(trigger, index);
        state.conditions[index] = { satisfied = satisfied; detail = detail };
        if (satisfied == true) then
            state.progress = state.progress + 1;
            state.matched[#state.matched + 1] = trigger.name;
        end
    end
    local qualifies = false;
    for _, group in ipairs(ComboNextLogic.GetGroups(triggers)) do
        local groupTrue = true;
        for offset = 1, #group do
            if (state.conditions[group.first + offset - 1].satisfied ~= true) then
                groupTrue = false;
                break;
            end
        end
        qualifies = qualifies or groupTrue;
    end
    if (not qualifies) then
        state.conditionConsumed = nil;
    end
    state.done = qualifies and not state.conditionConsumed;
    return state.done;
end

function ComboNextLogic.Consume(state)
    state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
    state.eventTimes = {};
    state.branches = nil;
    state.conditionConsumed = true;
end

function ComboNextLogic.CooldownReady(resetTime, now)
    if (type(resetTime) ~= "number") then
        return nil;
    end
    return resetTime <= now;
end
