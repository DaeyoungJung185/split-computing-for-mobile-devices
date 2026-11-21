function [uplinkMbps, channelGain] = sample_uplink_rates(channel, cycleCount)
% Draw one log-normal channel gain per device and inference cycle.
% Outputs are indexed by cycle and device. Bandwidth is in MHz, distance
% in km, and transmit and noise powers in W.

    distanceKm = channel.distanceKm(:).';
    bandwidthMHz = channel.bandwidthMHz(:).';
    assert(~isempty(distanceKm) && numel(distanceKm) == numel(bandwidthMHz), ...
        'Provide one distance and one bandwidth per device.');
    validateattributes(distanceKm, {'numeric'}, {'real', 'finite', 'positive'});
    validateattributes(bandwidthMHz, {'numeric'}, {'real', 'finite', 'positive'});
    validateattributes(channel.shadowStdDb, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(channel.txPowerW, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(channel.noisePowerW, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});

    % 3GPP TR 36.942, Section 4.5.2, urban macro median path loss.
    medianLossDb = 128.1 + 37.6 * log10(distanceKm);
    stream = RandStream('mt19937ar', 'Seed', channel.seed);
    shadowLossDb = channel.shadowStdDb .* randn(stream, cycleCount, numel(distanceKm));
    channelGain = 10 .^ (-(medianLossDb + shadowLossDb) / 10);

    % TSC paper, p. 1803: rate = B log2(1 + P_tx * gain / noise_power).
    snr = channel.txPowerW .* channelGain ./ channel.noisePowerW;
    uplinkMbps = bandwidthMHz .* (log1p(snr) ./ log(2));
    assert(all(isfinite(uplinkMbps(:)) & uplinkMbps(:) > 0), ...
        'The sampled channel must yield finite, positive uplink rates.');
end
