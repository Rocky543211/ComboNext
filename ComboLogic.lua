ComboNextLogic = {};

function ComboNextLogic.GetMode(cfg)
    return cfg.triggerMode or (cfg.anyOrder and "any" or "ordered");
end

function ComboNextLogic.IsCurrent(mode)
    return mode == "allConditions" or mode == "anyConditions";
end

function ComboNextLogic.Advance(state, triggers, matches)
    if (#triggers == 0) then
        state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
        return;
    end
    if (state.done) then
        state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
    end
    if (triggers.mode == "or") then
        for _, trigger in ipairs(triggers) do
            if (matches(trigger)) then
                state.progress, state.done, state.matched = 1, true, { trigger.name };
                return;
            end
        end
        return;
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
    local qualifies = #triggers > 0 and (state.progress == #triggers
        or (triggers.mode == "anyConditions" and state.progress > 0));
    if (not qualifies) then
        state.conditionConsumed = nil;
    end
    state.done = qualifies and not state.conditionConsumed;
    return state.done;
end

function ComboNextLogic.Consume(state)
    state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
    state.eventTimes = {};
    state.conditionConsumed = true;
end

function ComboNextLogic.CooldownReady(resetTime, now)
    if (type(resetTime) ~= "number") then
        return nil;
    end
    return resetTime <= now;
end
