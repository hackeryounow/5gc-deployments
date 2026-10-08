-- ============================================================================
-- OAI CN5G develop - subscriber provisioning overlay
--
-- Runs AFTER oai_db.sql (the base schema + sample data from ../database).
-- The base oai_db2.sql ships INCONSISTENT sample rows: the three subscription
-- tables cover disjoint ueids (AuthenticationSubscription=...031+,
-- AccessAndMobilitySubscriptionData=...125+, SessionManagementSubscriptionData
-- =...031+), so no single UE can complete registration + PDU session.
--
-- This overlay makes the conventional OAI test UE 208950000000031 fully
-- consistent for slice sst=222 / sd=00007B and DNN "oai" (the "custom_slice"
-- served by the AMF/SMF/UPF in basic_nrf_config.yaml). Its
-- AuthenticationSubscription row (Ki/OPc/SQN/AMF) already exists in the base
-- SQL and is left untouched.
-- ============================================================================

USE `oai_db`;

-- Access & Mobility subscription data (missing for this UE in the base SQL)
DELETE FROM `AccessAndMobilitySubscriptionData` WHERE `ueid` = '208950000000031';
INSERT INTO `AccessAndMobilitySubscriptionData` (`ueid`, `servingPlmnid`, `nssai`) VALUES
('208950000000031', '20895', '{\"defaultSingleNssais\": [{\"sst\": 222, \"sd\": \"00007B\"}]}');

-- Session Management subscription data: normalize to DNN "oai" (the base row
-- used DNN "default" + a static IP outside the configured UE subnet). Dynamic
-- IP from the "oai" DNN pool 10.1.1.128/25 is used instead.
DELETE FROM `SessionManagementSubscriptionData` WHERE `ueid` = '208950000000031';
INSERT INTO `SessionManagementSubscriptionData` (`ueid`, `servingPlmnid`, `singleNssai`, `dnnConfigurations`) VALUES
('208950000000031', '20895', '{\"sst\": 222, \"sd\": \"00007B\"}', '{\"oai\":{\"pduSessionTypes\":{\"defaultSessionType\":\"IPV4\"},\"sscModes\":{\"defaultSscMode\":\"SSC_MODE_1\"},\"5gQosProfile\":{\"5qi\":6,\"arp\":{\"priorityLevel\":1,\"preemptCap\":\"NOT_PREEMPT\",\"preemptVuln\":\"NOT_PREEMPTABLE\"},\"priorityLevel\":1},\"sessionAmbr\":{\"uplink\":\"100Mbps\",\"downlink\":\"100Mbps\"}}}');
