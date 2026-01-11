# Hiera-based AdGuard Home configuration
#
# This example demonstrates using Hiera for node-specific configuration.
# All parameters are defined in Hiera data files instead of in the manifest.
#
# Usage:
#   1. Create Hiera data files in data/nodes/
#   2. Apply with: puppet apply examples/hiera_based.pp
#
# Example Hiera structure:
#
# data/nodes/adguard-primary.example.com.yaml:
#   ha_adguard::ensure: 'present'
#   ha_adguard::ha_enabled: true
#   ha_adguard::ha_role: 'primary'
#   ha_adguard::keepalived_enabled: true
#   ha_adguard::vip_address: '192.168.1.100'
#   ha_adguard::vrrp_priority: 150
#   ha_adguard::cluster_nodes:
#     - '192.168.1.10'
#     - '192.168.1.11'
#
# data/nodes/adguard-replica.example.com.yaml:
#   ha_adguard::ensure: 'present'
#   ha_adguard::ha_enabled: true
#   ha_adguard::ha_role: 'replica'
#   ha_adguard::keepalived_enabled: true
#   ha_adguard::vip_address: '192.168.1.100'
#   ha_adguard::vrrp_priority: 100
#   ha_adguard::sync_enabled: true
#   ha_adguard::sync_origin_url: 'http://192.168.1.10:3000'

include ha_adguard
