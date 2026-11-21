# Queue-aware split computing in MATLAB

This numerical simulation sample is adapted from the MATLAB evaluation code for *Split Computing for Mobile Devices: Energy and Latency Perspective*. It demonstrates the paper's residual-energy-based split-selection heuristic on periodic VGG-19 inference requests, using the original execution profiles and a reproducible, time-varying uplink.

## Run the example

Open this folder in MATLAB and run `demo_split_computing`. The example uses base MATLAB, three devices, eight inference cycles, and one shared edge server. It prints the sampled uplink rates, the selected VGG-19 profile rows, and the average latency and device energy for both policies. Row 1 sends the model input to the edge. The final row runs the entire model on the device.

The bundled scenario produces these results in MATLAB R2026a.

| Policy | Mean inference latency (ms) | Mean device energy (J) |
| --- | ---: | ---: |
| Adaptive split selection | 335.895 | 45.190 |
| Fully local inference | 445.588 | 59.791 |

## Split selection and queue model

[`select_split_points.m`](select_split_points.m) implements the per-cycle search in Algorithm 1 of the paper.

1. Visit devices in order of increasing residual energy.
2. For the current device, evaluate each feasible split using a copy of the schedule committed so far. Compute device, uplink, and edge service and waiting times. Inserting an edge request can change the waiting times of devices already assigned in this cycle.
3. Average latency and device energy across the current device and the devices already assigned. Normalize both averages using fixed bounds and apply the latency–energy weight.
4. Commit the lowest-scoring split and its queue updates. Continue with the next device.

[`simulate_split_computing.m`](simulate_split_computing.m) runs successive inference cycles, carries queue state forward, and deducts device energy at the end of each cycle. The uplink queue is checked when local processing finishes, and the shared edge queue serves requests in order of actual arrival. Work already in service continues to completion. Fully local requests use only the device queue. These timings follow Eqs. (2), (4), (6), and (8). Candidates that exceed the device's remaining energy are excluded under Eq. (15).

After running the demo, the following variables expose the per-cycle inputs and decisions.

```matlab
uplinkMbps(5, :)
adaptive.priorityOrder(5, :)
[adaptive.splitCandidates(:), squeeze(adaptive.candidateScore(5, 2, :))]
squeeze(adaptive.waitMs(5, :, :))
```

The candidate scores for device 2 reflect the schedule at its turn in the search. The final waiting times have columns for local computation, uplink transmission, and edge computation. With overlapping cycles, a request released in a later cycle can reach the edge first and change the earlier request's reported wait.

## Wireless model

[`sample_uplink_rates.m`](sample_uplink_rates.m) uses the paper's uplink formula $B\log_2(1+P_{\mathrm{tx}}h/\sigma^2)$. The demo assigns bandwidths of 40, 80, and 120 MHz within the paper's range and uses its 0.5 W transmit power and $10^{-9}$ W noise power (p. 1805).

The gain is log-normal. The demo uses the urban macro median path loss $128.1+37.6\log_{10}(d)$ in dB and a 10 dB shadowing standard deviation from [3GPP TR 36.942, §4.5.2](https://www.etsi.org/deliver/etsi_TR/136900_136999/136942/18.00.00_60/tr_136942v180000p.pdf), cited as reference [30] in the paper. The device distances of 0.25, 0.20, and 0.15 km, independent draws by device and cycle, and random seed 1 are demo settings.

All splits considered for a given device and cycle use the same sampled rate. Dividing the transmitted data size by this rate gives uplink service time in Eq. (5). Transmit energy is power multiplied by this service time in seconds, as in Eq. (9).

## Source and verification

The sample retains the residual-energy ordering, trial evaluation, and commit sequence of the archived `S001_PA_het.m`. The demo uses the archive's energy parameters and normalization bounds. [`data/vgg19_profiles.csv`](data/vgg19_profiles.csv) combines the archived CPU and GPU timing profiles, output sizes, operation counts, and parameter counts. Output sizes are in millions of 32-bit elements.

The queue timing and scoring above follow the published model. For one archived case with fixed rates of 40, 80, and 120 Mbps and a latency weight of 0.5, the sample matched the split decisions, per-stage times, and device energy to numerical precision. Separate checks cover uplink backlog during local processing, edge queue ordering across cycles, fully local inference, and battery feasibility. The bundled scenario illustrates the heuristic with sampled links.

Daeyoung Jung, Jaewook Lee, Hyeonjae Jeong, Dongju Cha, Heewon Kim, and Sangheon Pack. *Split Computing for Mobile Devices: Energy and Latency Perspective*. IEEE Transactions on Services Computing, 18(3), 1798–1810, 2025. [DOI](https://doi.org/10.1109/TSC.2025.3564885)
