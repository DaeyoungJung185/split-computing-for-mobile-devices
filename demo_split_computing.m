% Small numerical example using the VGG-19 measurements in the TSC archive.
sampleFolder = fileparts(mfilename('fullpath'));
profile = readmatrix(fullfile(sampleFolder, 'data', 'vgg19_profiles.csv'));

% Three illustrative devices with two CPU profiles.
cpuProfile = [2; 1; 2];
cpuEnergyScale = [1, 18 / 27];
cpuMs = profile(:, 1:2);
gpuMs = profile(:, 3);
outputMbit = 32 * profile(:, 4).';
macCount = profile(:, 5);
parameterCount = profile(:, 6);

% Cost of executing through the split row locally, then transmitting its
% output and processing the remaining layers at the edge.
cost.localMs = cumsum(cpuMs(:, cpuProfile), 1).';
cost.edgeMsBySplit = [flipud(cumsum(flipud(gpuMs(2:end)))); 0].';

% Device-side energy model from parameter.m and S001_PA_het.m.
joulesPerMac = 4.5e-11;
joulesPerParameterBit = 1.3e-8;
layerEnergyJ = (joulesPerMac * macCount) * cpuEnergyScale(cpuProfile) ...
    + (32 * joulesPerParameterBit) * parameterCount;
localEnergyJ = cumsum(layerEnergyJ, 1).';

scenario.cycles = 8;
scenario.intervalMs = 180;
scenario.latencyWeight = 0.5;
scenario.initialEnergyJ = [6000; 6000; 6000];
scenario.latencyRangeMs = [77.787354539, scenario.intervalMs];
scenario.energyRangeJ = [0.0200704, 59.98784973204];

% Published bandwidth range and power settings (TSC, p. 1805).
channel.bandwidthMHz = [40; 80; 120];
channel.txPowerW = 0.5;
channel.noisePowerW = 1e-9;
channel.shadowStdDb = 10;  % 3GPP urban macro shadowing spread.
channel.distanceKm = [0.25; 0.20; 0.15];  % Illustrative device locations.
channel.seed = 1;
[uplinkMbps, channelGain] = sample_uplink_rates(channel, scenario.cycles);

% All candidate splits use the same draw for a given device and cycle.
% Equation (5) gives transmission service time. Transmit energy is power
% times service time in seconds, excluding time spent waiting in the queue.
rateByDeviceAndCycle = reshape(uplinkMbps.', numel(cpuProfile), 1, scenario.cycles);
cost.uplinkMs = 1000 * outputMbit ./ rateByDeviceAndCycle;
cost.energyJ = localEnergyJ + channel.txPowerW .* cost.uplinkMs ./ 1000;

adaptive = simulate_split_computing(cost, scenario);

% Run the same simulator with only the fully local split available.
fullyLocal = simulate_split_computing(cost, scenario, size(cost.localMs, 2));

fprintf('Sampled uplink rate in Mbps by cycle (columns are devices):\n');
disp(round(uplinkMbps, 3));
fprintf('Selected VGG-19 profile row by cycle (columns are devices):\n');
disp(adaptive.splitRow);
fprintf('%-14s %16s %16s\n', 'Policy', 'Mean latency (ms)', 'Mean energy (J)');
fprintf('%-14s %16.3f %16.3f\n', 'Adaptive', ...
    mean(adaptive.latencyMs(:)), mean(adaptive.energyJ(:)));
fprintf('%-14s %16.3f %16.3f\n', 'Fully local', ...
    mean(fullyLocal.latencyMs(:)), mean(fullyLocal.energyJ(:)));
