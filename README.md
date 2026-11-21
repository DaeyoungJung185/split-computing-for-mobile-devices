# Split Computing for Mobile Devices: Energy and Latency Perspective

This repository contains a MATLAB numerical simulation of the split-point selection heuristic in Algorithm 1 of [1]. The example compares adaptive split selection with fully local inference using measured VGG-19 CPU and GPU layer timings and a seeded uplink model.

## Run the example

Open the repository folder in MATLAB and run `demo_split_computing`. The example uses base MATLAB and models three devices with two CPU profiles and one shared edge server. Each device releases eight inference requests 180 ms apart. The latency weight is 0.5.

The following results were verified in MATLAB R2026a. Each mean is over the 24 requests in that policy's run.

| Policy | Mean inference latency (ms) | Mean device energy (J) |
| --- | ---: | ---: |
| Adaptive split selection | 335.895 | 45.190 |
| Fully local inference | 445.588 | 59.791 |

## Split selection and queues

[`select_split_points.m`](select_split_points.m) implements the per-cycle search.

1. Visit devices in order of increasing residual energy.
2. Evaluate each feasible split from the schedule committed so far. Adding a trial request to the shared edge queue can change the waits of devices whose splits were already selected.
3. Average latency and device energy over the current device and the devices already assigned in the cycle. Normalize both averages using the scenario bounds and compute the weighted score.
4. Commit the lowest-scoring split and its queue updates, then move to the next device.

[`simulate_split_computing.m`](simulate_split_computing.m) carries unfinished work across cycles and deducts device energy at the end of each cycle. Local computation and uplink transmission have separate queues on each device. An uplink request becomes eligible when its local computation finishes. The edge server serves requests in arrival order and finishes work already in service before starting the next request. Fully local inference uses the local computation queue. The stage timings follow Eqs. (2), (4), (6), and (8) of [1]. The sample applies the residual-energy constraint in Eq. (15) when screening split candidates.

## Input data and uplink model

[`data/vgg19_profiles.csv`](data/vgg19_profiles.csv) contains CPU and GPU layer timings in milliseconds, tensor sizes in millions of 32-bit elements, MAC counts, and parameter counts. The first profile row corresponds to sending the input tensor to the edge. The last row corresponds to fully local inference.

[`sample_uplink_rates.m`](sample_uplink_rates.m) computes uplink rates as $B\log_2(1+P_{\mathrm{tx}}h/\sigma^2)$, where $h$ is the linear channel gain. The example uses bandwidths of 40, 80, and 120 MHz, transmit power of 0.5 W, and noise power of $10^{-9}$ W, consistent with the settings in [1, Sec. VI].

The demo uses the 2 GHz urban macrocell path-loss expression $128.1+37.6\log_{10}(d)$ in dB, where $d$ is in kilometres, and the 10 dB shadowing standard deviation from [2, Sec. 4.5.2]. It models log-normal gain by adding Gaussian shadowing in dB and converting the resulting path loss to linear gain. The distances of 0.25, 0.20, and 0.15 km, independent draws for each device and cycle, and random seed 1 are settings of this example.

For a given device and cycle, all candidates use the same sampled rate. Tensor size in megabits divided by that rate gives transmission time in seconds, following Eq. (5) of [1]. Transmit power multiplied by that service time gives the transmission energy term in Eq. (9).

## Inspect the simulation results

After running the example, use the following expressions to inspect cycle 5.

```matlab
uplinkMbps(5, :)
adaptive.priorityOrder(5, :)
[adaptive.splitCandidates(:), squeeze(adaptive.candidateScore(5, 2, :))]
squeeze(adaptive.waitMs(5, :, :))
```

The third expression shows device 2's candidate scores at its turn in the search. The last expression shows each device's final waiting times in milliseconds in local, uplink, and edge order. A request released in a later cycle can reach the edge first and change an earlier request's final wait.

## References

[1] D. Jung, J. Lee, H. Jeong, D. Cha, H. Kim, and S. Pack, “Split computing for mobile devices: Energy and latency perspective,” *IEEE Trans. Serv. Comput.*, vol. 18, no. 3, pp. 1798–1810, May/Jun. 2025, doi: [10.1109/TSC.2025.3564885](https://doi.org/10.1109/TSC.2025.3564885).

[2] ETSI, “LTE; Evolved Universal Terrestrial Radio Access (E-UTRA); Radio Frequency (RF) system scenarios,” ETSI TR 136 942 V18.0.0 (3GPP TR 36.942 Release 18), May 2024, sec. 4.5.2. [Online]. Available: [ETSI TR 136 942](https://www.etsi.org/deliver/etsi_TR/136900_136999/136942/18.00.00_60/tr_136942v180000p.pdf).
