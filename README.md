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
| `vonr-2.7.7` | docker_open5gs v2.7.7 images | Baseline SA VoNR deployment (embedded mode, includes IMS/Kamailio stack) |
| `volte-2.8.0-asan` | Open5GS release **v2.8.0**, compiled with **ASAN (AddressSanitizer) enabled** | 4G VoLTE deployment for memory-error / vulnerability testing. ASAN adds runtime overhead and produces detailed crash reports on memory faults; do not use for performance testing |
| `volte-2.8.0` | Open5GS release **v2.8.0** (docker_open5gs images) | 4G VoLTE deployment with Osmocom CS core (docker_osmohlr / docker_osmomsc); use this one for normal VoLTE testing instead of the ASAN build |
| `vonr-2.8.1-beta` | Open5GS **latest development branch** | SA VoNR deployment; supports the docker_kamailio build released together with docker_open5gs (custom image version) |
| `vonr-2.8.1-gamma` | Open5GS **latest development branch** | SA VoNR deployment; supports the **official docker_kamailio v6.1.3** instead of the custom Kamailio build |

Directory naming convention: `<scenario>-<version>[-<variant>]`, e.g. `vonr-2.7.7`, `volte-2.8.0-asan`.

Version selection guidance:

- Use `vonr-2.7.7` as the stable reference deployment.
- Use `volte-2.8.0-asan` only when ASAN instrumentation is required (fault injection,
  CVE reproduction, fuzzing). Expect a performance penalty.
* Choose between the two latest-branch builds by Kamailio preference:
  `beta` = docker_open5gs-provided Kamailio, `gamma` = official Kamailio v6.1.3.
* Latest-branch builds (`beta`/`gamma`) may contain unstable features; prefer them
  for testing new Open5GS functionality, not for long-running setups.

### OAI CN5G (`oai/`)

| Version directory | Images | Notes |
|----|----|----|
| `2.2.0` | **Official** `oaisoftwarealliance/*:v2.2.0` images | Basic NRF-based deployment; MySQL subscriber database (`oai/database/`); network `demo-oai-public-net` (172.20.0.0/16) |
| `2.2.1` | **Official** `oaisoftwarealliance/*:v2.2.1` images | Same basic NRF-based topology as `2.2.0` on the v2.2.1 release (plain HTTP/2 SBI, no TLS). Start with `docker compose -f docker-compose-basic-nrf.yaml up -d`; verified end-to-end with UERANSIM (subscriber `imsi-208950000000031`, slice SST 222/SD 123, DNN `oai`): registration + PDU session established, UE `uesimtun0` gets `10.1.1.130`, ping to `oai-ext-dn` and to the internet via UPF SNAT both succeed. Network `demo-oai-public-net` (172.20.0.0/16) |
| `2.2.1-tls` | `oaisoftwarealliance/*:develop` images | v2.2.1 with **TLS on the SBI interfaces**. Only AMF/SMF implement TLS in the official images, so a TLS-terminating HAProxy (`oai-sbi-proxy`) fronts NRF/AUSF/UDM. Generate certs first with `./generate_certs.sh`, then `docker compose -f docker-compose-basic-nrf-tls.yaml up -d` |

Upgrading OAI only requires changing the image tag in `oai/<version>/docker-compose-basic-nrf*.yaml`.

Note: the AMF publishes the N2 port `38412/sctp` on the host. If another core (e.g. a running
free5GC AMF) already holds that port, remap it with a compose override (`ports: !override
["38413:38412/sctp"]`); the containerized UERANSIM reaches `oai-amf` over `demo-oai-public-net`
using the internal port, so the host mapping is only needed for an external gNB.

### free5GC (`free5gc/`)

| Version directory | Images | Notes |
|----|----|----|
| `4.3.0` | **Official** `free5gc/*:v4.3.0` images (`tngf`/`nef`/`ueransim` stay `:latest`, as in `4.2.3`) | Standard NRF-based deployment sharing `../config` + `../cert`; network `430_privnet` (10.100.200.0/24, bridge `br-free5gc`); PLMN 208/93. Start with `docker compose up -d`, then run the UE inside the gNB container: `docker exec -it ueransim bash -c "./nr-ue -c ./config/uecfg.yaml"`. The `dbdata` volume starts empty, so provision subscribers first (UE `imsi-208930000000001..005`, Ki `8baf473f2f8fd09487cccbd7097c6862`, OPc `8e27b6af0e692e750f32667a3b14605d`) via the WebConsole (`http://<host>:5000`, `admin`/`free5gc`) or `coresimrunner --mode provision --core-network free5gc`. Verified end-to-end with UERANSIM v3.3.0: gNB NG-Setup + UE initial registration (5G-AKA), two PDU sessions (`uesimtun0` 10.60.0.1 / slice 1-010203, `uesimtun1` 10.61.0.1 / slice 1-112233), `ping 8.8.8.8` at 0% loss via both tunnels and DNS via the SMF-provided 8.8.8.8. Note: `tngf` exits on startup (host networking + hard-coded bind IP `192.168.1.103`) and is not required for the UERANSIM test |
| `4.2.2` | **Official** `free5gc/*` images | Standard deployment with MongoDB; network `422-free5gc_privnet` (10.100.200.0/24); default PLMN 208/93 |
| `ulcl` | **Official** `free5gc/*:v4.2.3` images | ULCL (uplink classifier) deployment modeled after `free5gc-compose/docker-compose-ulcl.yaml`: topology `gNB1 -> I-UPF -> PSA-UPF` with UE pool 10.60.0.0/16; traffic to 1.0.0.1/32 breaks out at I-UPF (`config/ULCL/uerouting.yaml`), everything else egresses at PSA-UPF. Start with `docker compose up -d`, then run the UE inside the gNB container: `docker exec -it ueransim bash -c "./nr-ue -c config/uecfg.yaml"` (uses `config/uecfg-ulcl.yaml`, subscriber `imsi-208930000000001`). SMF requires `-u ./config/uerouting.yaml`; MongoDB volume `ulcl_dbdata` is pre-seeded with the subscribers from the 4.2.3 deployment |

> All free5GC version directories share the same bridge name (`br-free5gc`) and subnet (10.100.200.0/24), so only **one** free5GC deployment can run at a time. Bring down any other running core first (e.g. `docker compose -f <other-core>/docker-compose.yaml down`) before starting a new one, otherwise the network/bridge and container names (`amf`, `smf`, `upf`, `mongodb`, `ueransim`, ...) will conflict.

## RAN / UE Simulators

### UERANSIM (`ueransim/`)

| Target core | Image | Origin | Network |
|----|----|----|----|
| Open5GS | `swr.cn-north-4.myhuaweicloud.com/cn_5gc/docker_ueransim:v3.2.8` | Built from the Dockerfile published with **docker_open5gs** (env-var driven config via `COMPONENT_NAME` + init scripts) | `docker_open5gs_default` |
| free5GC | `swr.cn-north-4.myhuaweicloud.com/cn_5gc/docker_ueransim:v3.2.8` | Same docker_open5gs Dockerfile; only the network and subscription parameters differ | `422-free5gc_privnet` |
| OAI | `rohankharade/ueransim:latest` | **Official UERANSIM** image | `demo-oai-public-net` |

Note: the two image families use different configuration mechanisms and are NOT interchangeable:

* docker_open5gs-style image: renders `config/ueransim-{gnb,ue}.yaml` templates through
  init scripts using environment variables (`MCC`, `MNC`, `UE1_*`, `NR_GNB_IP`, `AMF_IP`/`MME_IP`).
* Official image for OAI: environment variables are substituted directly by its own
  entrypoint; the AMF address must resolve to an IP at startup (`nr-gnb` rejects hostnames).

### gnbsim (`gnbsim/`)

| Target core | Image | Notes |
|----|----|----|
| OAI | `rohankharade/gnbsim:latest` | FQDN-based AMF connection (`AMF_FQDN`); network `demo-oai-public-net` |

### srsRAN (`srslte/`)

| Target core | Image | Origin | Notes |
|----|----|----|----|
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


