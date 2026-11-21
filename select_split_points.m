function schedule = select_split_points(cost, state, scenario, splitCandidates)
% Choose split points for one cycle using the search order in Algorithm 1.
% Adapted from S001_PA_het.m. Stage columns are local, uplink, and edge.
% Server availability and edge queue timestamps are absolute milliseconds.

    deviceCount = size(cost.localMs, 1);
    [~, priorityOrder] = sort(state.remainingEnergyJ, 'ascend');

    committed.splitRow = zeros(deviceCount, 1);
    committed.serviceMs = zeros(deviceCount, 3);
    committed.waitMs = zeros(deviceCount, 3);
    committed.energyJ = zeros(deviceCount, 1);
    committed.localFreeMs = state.localFreeMs;
    committed.uplinkFreeMs = state.uplinkFreeMs;
    committed.edgeQueue = state.edgeQueue;
    candidateScore = inf(deviceCount, numel(splitCandidates));

    for position = 1:deviceCount
        device = priorityOrder(position);
        assignedDevices = priorityOrder(1:position);  % Algorithm 1's W plus this device.
        bestScore = inf;

        for candidateIndex = 1:numel(splitCandidates)
            splitRow = splitCandidates(candidateIndex);
            % Apply the residual-energy constraint from Eq. (15).
            if cost.energyJ(device, splitRow) > state.remainingEnergyJ(device)
                continue;
            end

            % Every trial starts from the same committed schedule.
            trial = evaluate_candidate(committed, cost, state, device, splitRow);
            score = split_objective(trial, assignedDevices, scenario);
            candidateScore(device, candidateIndex) = score;
            if score < bestScore
                bestScore = score;
                bestSchedule = trial;
            end
        end

        if ~isfinite(bestScore)
            error('splitComputing:NoFeasibleSplit', ...
                'Device %d has no feasible split at t = %.3f ms with %.6g J remaining.', ...
                device, state.releaseMs, state.remainingEnergyJ(device));
        end
        % Commit the split and any changes it caused to the edge queue.
        committed = bestSchedule;
    end

    schedule = committed;
    schedule.priorityOrder = priorityOrder;
    schedule.candidateScore = candidateScore;
end

function trial = evaluate_candidate(committed, cost, state, device, splitRow)
% Apply the stage timings in Eqs. (2), (4), (6), and (8).

    trial = committed;
    trial.splitRow(device) = splitRow;
    trial.energyJ(device) = cost.energyJ(device, splitRow);

    % The request joins the device's local queue at its cycle release.
    localStartMs = max(state.releaseMs, state.localFreeMs(device));
    trial.waitMs(device, 1) = localStartMs - state.releaseMs;
    trial.serviceMs(device, 1) = cost.localMs(device, splitRow);
    trial.localFreeMs(device) = localStartMs + trial.serviceMs(device, 1);

    % Algorithm 1's terminal split executes the entire model locally.
    if splitRow == size(cost.localMs, 2)
        return;
    end

    % Uplink queue clearance is measured when the local output is ready.
    localFinishMs = trial.localFreeMs(device);
    uplinkStartMs = max(localFinishMs, state.uplinkFreeMs(device));
    trial.waitMs(device, 2) = uplinkStartMs - localFinishMs;
    trial.serviceMs(device, 2) = cost.uplinkMs(device, splitRow);
    trial.uplinkFreeMs(device) = uplinkStartMs + trial.serviceMs(device, 2);

    % The intermediate output joins a shared FIFO after transmission.
    % Recompute affected windows, including pending requests from older cycles.
    trial.serviceMs(device, 3) = cost.edgeMsBySplit(splitRow);
    trial.edgeQueue = insert_edge_request(trial.edgeQueue, state.edgeReadyMs, ...
        state.requestOffset + device, trial.uplinkFreeMs(device), ...
        trial.serviceMs(device, 3));

    inCurrentCycle = trial.edgeQueue.RequestId > state.requestOffset;
    cycleDevices = trial.edgeQueue.RequestId(inCurrentCycle) - state.requestOffset;
    trial.waitMs(cycleDevices, 3) = trial.edgeQueue.StartMs(inCurrentCycle) ...
        - trial.edgeQueue.ArrivalMs(inCurrentCycle);
end

function queue = insert_edge_request(queue, serverReadyMs, requestId, arrivalMs, serviceMs)
% Insert by arrival time. Request IDs break ties by cycle, then device.

    queue(end + 1, :) = {requestId, arrivalMs, serviceMs, 0, 0};
    queue = sortrows(queue, {'ArrivalMs', 'RequestId'});
    insertion = find(queue.RequestId == requestId, 1);

    % Earlier requests retain their windows. Later requests may have to wait.
    if insertion > 1
        serverReadyMs = queue.FinishMs(insertion - 1);
    end
    for row = insertion:height(queue)
        queue.StartMs(row) = max(queue.ArrivalMs(row), serverReadyMs);
        queue.FinishMs(row) = queue.StartMs(row) + queue.ServiceMs(row);
        serverReadyMs = queue.FinishMs(row);
    end
end

function score = split_objective(trial, assignedDevices, scenario)
% Algorithm 1 averages over W plus the current device before normalizing.

    latencyMs = sum(trial.serviceMs(assignedDevices, :) + ...
        trial.waitMs(assignedDevices, :), 2);
    meanLatencyMs = mean(latencyMs);
    meanEnergyJ = mean(trial.energyJ(assignedDevices));

    latencyScore = (meanLatencyMs - scenario.latencyRangeMs(1)) ...
        / diff(scenario.latencyRangeMs);
    energyScore = (meanEnergyJ - scenario.energyRangeJ(1)) ...
        / diff(scenario.energyRangeJ);
    score = scenario.latencyWeight * latencyScore ...
        + (1 - scenario.latencyWeight) * energyScore;
end
