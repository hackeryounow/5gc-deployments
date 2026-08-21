# 5GC Deployments

Deployment collection for multiple open-source 5G core networks (Open5GS, OAI CN5G, free5gc)
together with their RAN / UE simulators (UERANSIM, gnbsim, srsRAN).

## Repository Layout

```
5gc-deployments/
├── open5gs/       # Open5GS core deployments (multiple versions)
├── oai/           # OpenAirInterface CN5G deployment
├── free5gc/       # free5GC deployment
├── ueransim/      # UERANSIM gNB/UE simulators (per core)
├── gnbsim/        # gnbsim simulator (OAI only)
└── srslte/        # srsRAN 4G eNB/UE over ZMQ (Open5GS EPC)
```

## Core Network Versions

### Open5GS (`open5gs/`)

All Open5GS deployments run on the external network `docker_open5gs_default` (172.22.0.0/24).

| Version directory | Build base | Purpose / Notes |
|---|---|---|
| `2.7.7-vonr` | docker_open5gs v2.7.7 images | Baseline SA VoNR deployment (embedded mode, includes IMS/Kamailio stack) |
| `2.8.0-volte-asan` | Open5GS release **v2.8.0**, compiled with **ASAN (AddressSanitizer) enabled** | 4G VoLTE deployment for memory-error / vulnerability testing. ASAN adds runtime overhead and produces detailed crash reports on memory faults; do not use for performance testing |
| `2.8.1-beta-vonr` | Open5GS **latest development branch** | SA VoNR deployment; supports the docker_kamailio build released together with docker_open5gs (custom image version) |
| `2.8.1-gamma-vonr` | Open5GS **latest development branch** | SA VoNR deployment; supports the **official docker_kamailio v6.1.3** instead of the custom Kamailio build |

Version selection guidance:

- Use `2.7.7-vonr` as the stable reference deployment.
- Use `2.8.0-volte-asan` only when ASAN instrumentation is required (fault injection,
  CVE reproduction, fuzzing). Expect a performance penalty.
- Choose between the two latest-branch builds by Kamailio preference:
  `beta` = docker_open5gs-provided Kamailio, `gamma` = official Kamailio v6.1.3.
- Latest-branch builds (`beta`/`gamma`) may contain unstable features; prefer them
  for testing new Open5GS functionality, not for long-running setups.

### OAI CN5G (`oai/`)

| Version directory | Images | Notes |
|---|---|---|
| `2.2.0` | **Official** `oaisoftwarealliance/*` images | Basic NRF-based deployment; MySQL subscriber database (`oai/database/`); network `demo-oai-public-net` (172.20.0.0/16) |

Upgrading OAI only requires changing the image tag in `oai/2.2.0/docker-compose-basic-nrf.yaml`.

### free5GC (`free5gc/`)

| Version directory | Images | Notes |
|---|---|---|
| `4.2.2` | **Official** `free5gc/*` images | Standard deployment with MongoDB; network `422-free5gc_privnet` (10.100.200.0/24); default PLMN 208/93 |

## RAN / UE Simulators

### UERANSIM (`ueransim/`)

| Target core | Image | Origin | Network |
|---|---|---|---|
| Open5GS | `swr.cn-north-4.myhuaweicloud.com/cn_5gc/docker_ueransim:v3.2.8` | Built from the Dockerfile published with **docker_open5gs** (env-var driven config via `COMPONENT_NAME` + init scripts) | `docker_open5gs_default` |
| free5GC | `swr.cn-north-4.myhuaweicloud.com/cn_5gc/docker_ueransim:v3.2.8` | Same docker_open5gs Dockerfile; only the network and subscription parameters differ | `422-free5gc_privnet` |
| OAI | `rohankharade/ueransim:latest` | **Official UERANSIM** image | `demo-oai-public-net` |

Note: the two image families use different configuration mechanisms and are NOT interchangeable:

- docker_open5gs-style image: renders `config/ueransim-{gnb,ue}.yaml` templates through
  init scripts using environment variables (`MCC`, `MNC`, `UE1_*`, `NR_GNB_IP`, `AMF_IP`/`MME_IP`).
- Official image for OAI: environment variables are substituted directly by its own
  entrypoint; the AMF address must resolve to an IP at startup (`nr-gnb` rejects hostnames).

### gnbsim (`gnbsim/`)

| Target core | Image | Notes |
|---|---|---|
| OAI | `rohankharade/gnbsim:latest` | FQDN-based AMF connection (`AMF_FQDN`); network `demo-oai-public-net` |

### srsRAN (`srslte/`)

| Target core | Image | Origin | Notes |
|---|---|---|---|
| Open5GS (EPC/4G) | `swr.cn-north-4.myhuaweicloud.com/cn_5gc/docker_srslte:v23.11` | Same build as docker_open5gs, based on **srsRAN_4G 23.11** | eNB + UE connected via ZMQ (no RF hardware needed); network `docker_open5gs_default` |

## Deployment Notes

1. **Networks are external**: simulator compose files attach to networks created by the
   corresponding core deployment. Start the core first.
2. **IP planning**: NF/simulator IPs are fixed in the compose files; keep simulator IPs
   (UERANSIM gNB 172.22.0.23/10.100.200.204, srsRAN eNB 172.22.0.25, UE 172.22.0.26)
   aligned with `AMF_IP`/`MME_IP` used by the core.
3. **Subscription data must match simulators**: PLMN, K/OPc, slice (S-NSSAI) and DNN/APN
   configured in the simulators must exist in the core's subscriber database
   (Open5GS MongoDB / OAI MySQL / free5GC MongoDB/WebConsole).
4. **DNN consistency**: the OAI SMF only serves DNNs listed in its config
   (`use_local_subscription_info`), so simulator APN/DNN must match the SMF/UPF config,
   not only the database.
5. **Version upgrades**: Open5GS custom images (docker_open5gs) and srsRAN images come
   from the private registry `swr.cn-north-4.myhuaweicloud.com/cn_5gc`; OAI and free5GC
   use official public images and can be upgraded by tag change alone.
