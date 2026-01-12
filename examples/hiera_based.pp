# Copyright (C) 2026 James Evans
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
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
