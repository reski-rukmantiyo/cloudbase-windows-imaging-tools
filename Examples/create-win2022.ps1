# Copyright 2016 Cloudbase Solutions Srl
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

$ErrorActionPreference = "Stop"

$scriptPath =Split-Path -Parent $MyInvocation.MyCommand.Definition | Split-Path
git -C $scriptPath submodule update --init
if ($LASTEXITCODE) {
    throw "Failed to update git modules."
}

try {
    Join-Path -Path $scriptPath -ChildPath "\WinImageBuilder.psm1" | Remove-Module -ErrorAction SilentlyContinue
    Join-Path -Path $scriptPath -ChildPath "\Config.psm1" | Remove-Module -ErrorAction SilentlyContinue
    Join-Path -Path $scriptPath -ChildPath "\UnattendResources\ini.psm1" | Remove-Module -ErrorAction SilentlyContinue
} finally {
    Join-Path -Path $scriptPath -ChildPath "\WinImageBuilder.psm1" | Import-Module
    Join-Path -Path $scriptPath -ChildPath "\Config.psm1" | Import-Module
    Join-Path -Path $scriptPath -ChildPath "\UnattendResources\ini.psm1" | Import-Module
}

# The Windows image file path that will be generated
$virtualDiskPath = "E:\images\my-windows-image.raw"

# The wim file path is the installation image on the Windows ISO

$wimFilePath = "D:\Sources\install.wim"

# VirtIO ISO contains all the synthetic drivers for the KVM hypervisor
$virtIOISOPath = "c:\images\virtio.iso"
# Note(avladu): Do not use stable 0.1.126 version because of this bug https://github.com/crobinso/virtio-win-pkg-scripts/issues/10
# Note (atira): Here https://fedorapeople.org/groups/virt/virtio-win/CHANGELOG you can see the changelog for the VirtIO drivers
$virtIODownloadLink = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/virtio-win-0.1.240.iso"

# Download the VirtIO drivers ISO from Fedora
# (New-Object System.Net.WebClient).DownloadFile($virtIODownloadLink, $virtIOISOPath)

# Extra drivers path contains the drivers for the baremetal nodes
# Examples: Chelsio NIC Drivers, Mellanox NIC drivers, LSI SAS drivers, etc.
# The cmdlet will recursively install all the drivers from the folder and subfolders
$extraDriversPath = "c:\drivers\"

# Every Windows ISO can contain multiple Windows flavors like Core, Standard, Datacenter
# Usually, the second image version is the Standard one
$image = (Get-WimFileImagesInfo -WimFilePath $wimFilePath)[1]

# The path were you want to create the config fille
$configFilePath = Join-Path $scriptPath "config.ini"
New-WindowsImageConfig -ConfigFilePath $configFilePath

#This is an example how to automate the image configuration file according to your needs
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "wim_file_path" -Value $wimFilePath
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_name" -Value "Windows Server 2022 SERVERSTANDARD"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_path" -Value "c:\images\win2022.qcow2"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "image_type" -Value "KVM"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "disk_layout" -Value "UEFI"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "virtual_disk_format" -Value "QCOW2"
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "disk_size" -Value (10GB)
Set-IniFileValue -Path $configFilePath -Section "drivers" -Key "virtio_iso_path" -Value $virtIOISOPath
Set-IniFileValue -Path $configFilePath -Section "drivers" -Key "drivers_path" -Value $extraDriversPath
#Set-IniFileValue -Path $configFilePath -Section "updates" -Key "install_updates" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "updates" -Key "purge_updates" -Value "True"
# Set-IniFileValue -Path $configFilePath -Section "sysprep" -Key "disable_swap" -Value "True"
#Set-IniFileValue -Path $configFilePath -Section "custom" -Key "install_qemu_ga" -Value "True"
# Set-IniFileValue -Path $configFilePath -Section "custom" -Key "install_cloudinit" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "compress_qcow2" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "enable_custom_wallpaper" -Value "False"
Set-IniFileValue -Path $configFilePath -Section "Default" -Key "shrink_image_to_minimum_size" -Value "True"
# Set-IniFileValue -Path $configFilePath -Section "Default" -Key "enable_administrator_account" -Value "True"
# Set-IniFileValue -Path $configFilePath -Section "Default" -Key "enable_active_mode" -Value "True"
Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "cloudbase_init_unattended_config_path" -Value "Examples\cloudbase-init-unattend.conf"
Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "cloudbase_init_config_path" -Value "Examples\cloudbase-init.conf"
# Set-IniFileValue -Path $configFilePath -Section "sysprep" -Key "unattend_xml_path" -Value "Examples\unattend.xml"
Set-IniFileValue -Path $configFilePath -Section "cloudbase_init" -Key "msi_path" -Value "c:\images\CloudbaseInitSetup_1_1_4_x64.msi"
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "cpu_count" -Value "4"
Set-IniFileValue -Path $configFilePath -Section "vm" -Key "ram_size" -Value "4294967296"
Set-IniFileValue -Path $configFilePath -Section "custom" -Key "time_zone" -Value "SE Asia Standard Time"

# This scripts generates a raw image file that, after being started as an instance and
# after it shuts down, it can be used with Ironic or KVM hypervisor in OpenStack.
New-WindowsCloudImage -ConfigFilePath $configFilePath
