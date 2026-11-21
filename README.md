# Split Computing for Mobile Devices: Energy and Latency Perspective

This repository contains a MATLAB numerical simulation of queue-aware split-point selection for mobile edge inference (Algorithm 1 in [1]).

## Run the example

Download or clone the repository, open its folder in MATLAB, and run the demo.

```matlab
demo_split_computing
```

The demo uses base MATLAB and compares adaptive split selection with fully local inference on three devices over eight inference cycles. The table shows MATLAB R2026a results averaged over 24 requests per policy.

| Policy | Mean inference latency (ms) | Mean device energy (J) |
| --- | ---: | ---: |
| Adaptive split selection | 335.895 | 45.190 |
| Fully local inference | 445.588 | 59.791 |

## Split selection and queues

Each cycle, the heuristic processes devices in order of increasing residual energy. It scores each feasible split using a weighted sum of normalized mean latency and energy across the current device and those already assigned. It commits the best split and its queue updates before moving to the next device. [Split-selection code](select_split_points.m)

The simulator carries unfinished local, uplink, and edge work across cycles. The shared edge server serves requests in arrival order. The simulator deducts energy use from each device's remaining budget after each cycle. [Simulation code](simulate_split_computing.m)

## Input data and uplink model

The example uses measured VGG-19 CPU and GPU layer timings, tensor sizes, MAC counts, and parameter counts. [VGG-19 profiles](data/vgg19_profiles.csv)

The uplink model uses seeded log-normal channel gains with the urban macrocell path-loss expression and shadowing spread from [2, Sec. 4.5.2]. [Uplink code](sample_uplink_rates.m)

## References

[1] D. Jung, J. Lee, H. Jeong, D. Cha, H. Kim, and S. Pack, “Split computing for mobile devices: Energy and latency perspective,” *IEEE Trans. Serv. Comput.*, vol. 18, no. 3, pp. 1798–1810, May/Jun. 2025, doi: [10.1109/TSC.2025.3564885](https://doi.org/10.1109/TSC.2025.3564885).

[2] ETSI, “LTE; Evolved Universal Terrestrial Radio Access (E-UTRA); Radio Frequency (RF) system scenarios,” ETSI TR 136 942 V18.0.0 (3GPP TR 36.942 Release 18), May 2024, sec. 4.5.2. [Online]. Available: [ETSI TR 136 942](https://www.etsi.org/deliver/etsi_TR/136900_136999/136942/18.00.00_60/tr_136942v180000p.pdf).
