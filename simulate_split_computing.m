function result = simulate_split_computing(cost, scenario, splitCandidates)
% Run the split-point heuristic for periodic inference requests.
% Cost rows are devices and columns are split rows. The final split row is
% fully local. Uplink and energy costs can also be indexed by cycle in
% dimension 3. Times are in ms and device energy is in J.

    [deviceCount, splitCount] = size(cost.localMs);
    if nargin < 3
        splitCandidates = 1:splitCount;
    end

    assert(isequal(size(cost.uplinkMs), size(cost.energyJ)) && ...
        size(cost.uplinkMs, 1) == deviceCount && size(cost.uplinkMs, 2) == splitCount, ...
        'Uplink and energy costs must have matching device and split dimensions.');
    costCycleCount = size(cost.uplinkMs, 3);
    assert(ndims(cost.uplinkMs) <= 3 && (costCycleCount == 1 || costCycleCount == scenario.cycles), ...
        'Provide fixed costs or one cost matrix per inference cycle.');
    assert(numel(cost.edgeMsBySplit) == splitCount, 'Provide one edge cost per split row.');
    assert(numel(scenario.initialEnergyJ) == deviceCount, 'Provide one energy budget per device.');
    assert(diff(scenario.latencyRangeMs) > 0 && diff(scenario.energyRangeJ) > 0, ...
        'The normalization ranges must be increasing.');
    assert(~isempty(splitCandidates) && all(ismember(splitCandidates(:), 1:splitCount)), ...
        'Split candidates must refer to rows in the model profile.');

    cycleCount = scenario.cycles;
    state.localFreeMs = zeros(deviceCount, 1);
    state.uplinkFreeMs = zeros(deviceCount, 1);
    state.remainingEnergyJ = scenario.initialEnergyJ(:);
    state.edgeReadyMs = 0;
    state.edgeQueue = array2table(zeros(0, 5), 'VariableNames', ...
        {'RequestId', 'ArrivalMs', 'ServiceMs', 'StartMs', 'FinishMs'});

    result.splitCandidates = splitCandidates(:).';
    result.splitRow = zeros(cycleCount, deviceCount);
    result.priorityOrder = zeros(cycleCount, deviceCount);
    result.energyJ = zeros(cycleCount, deviceCount);
    result.waitMs = zeros(cycleCount, deviceCount, 3);
    result.serviceMs = zeros(cycleCount, deviceCount, 3);
    result.edgeWindowMs = zeros(cycleCount, deviceCount, 2);
    result.candidateScore = zeros(cycleCount, deviceCount, numel(splitCandidates));

    cycleCost.localMs = cost.localMs;
    cycleCost.edgeMsBySplit = cost.edgeMsBySplit;
    for cycle = 1:cycleCount
        state.releaseMs = (cycle - 1) * scenario.intervalMs;
        state.requestOffset = (cycle - 1) * deviceCount;

        % Release completed entries. A request still in service stays in
        % the timeline and is never preempted by a later arrival.
        lastFinished = find(state.edgeQueue.FinishMs <= state.releaseMs, 1, 'last');
        if ~isempty(lastFinished)
            state.edgeReadyMs = state.edgeQueue.FinishMs(lastFinished);
            state.edgeQueue(1:lastFinished, :) = [];
        end

        costIndex = min(cycle, costCycleCount);
        cycleCost.uplinkMs = cost.uplinkMs(:, :, costIndex);
        cycleCost.energyJ = cost.energyJ(:, :, costIndex);
        schedule = select_split_points(cycleCost, state, scenario, splitCandidates);

        result.splitRow(cycle, :) = schedule.splitRow.';
        result.priorityOrder(cycle, :) = schedule.priorityOrder.';
        result.energyJ(cycle, :) = schedule.energyJ.';
        result.waitMs(cycle, :, :) = reshape(schedule.waitMs, 1, deviceCount, 3);
        result.serviceMs(cycle, :, :) = reshape(schedule.serviceMs, 1, deviceCount, 3);
        result.candidateScore(cycle, :, :) = reshape(schedule.candidateScore, ...
            1, deviceCount, numel(splitCandidates));

        % A later cycle may shift a previous cycle's not-yet-served edge
        % requests. Update the reported waits and windows after each commit.
        queue = schedule.edgeQueue;
        for row = 1:height(queue)
            requestIndex = queue.RequestId(row) - 1;
            requestCycle = floor(requestIndex / deviceCount) + 1;
            device = mod(requestIndex, deviceCount) + 1;
            releaseMs = (requestCycle - 1) * scenario.intervalMs;
            result.waitMs(requestCycle, device, 3) = queue.StartMs(row) - queue.ArrivalMs(row);
            result.edgeWindowMs(requestCycle, device, 1) = queue.StartMs(row) - releaseMs;
            result.edgeWindowMs(requestCycle, device, 2) = queue.FinishMs(row) - releaseMs;
        end

        state.localFreeMs = schedule.localFreeMs;
        state.uplinkFreeMs = schedule.uplinkFreeMs;
        state.edgeQueue = queue;
        state.remainingEnergyJ = state.remainingEnergyJ - schedule.energyJ;
    end

    result.latencyMs = sum(result.waitMs + result.serviceMs, 3);
    result.remainingEnergyJ = state.remainingEnergyJ;
end
