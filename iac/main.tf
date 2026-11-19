terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  vms = ["vm1", "vm2"] # vm1 = web | vm2 = api + mysql

  # MACs fixos, iguais as reservas DHCP da rede "default" do libvirt.
  # Sem isso cada VM nasce com MAC aleatorio, o dnsmasq casa o hostname
  # com a reserva antiga e nao entrega IP (wait_for_lease estoura o tempo).
  macs = {
    vm1 = "52:54:00:DE:1A:A8" # 192.168.122.227
    vm2 = "52:54:00:16:41:24" # 192.168.122.122
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "disk" {
  count          = length(local.vms)
  name           = "${local.vms[count.index]}.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  format         = "qcow2"
  size           = 10 * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "init" {
  count = length(local.vms)
  name  = "${local.vms[count.index]}-cloudinit.iso"
  pool  = "default"

  user_data = templatefile("${path.module}/cloud_init.cfg", {
    hostname = local.vms[count.index]
    ssh_key  = trimspace(file(pathexpand("~/.ssh/devops_lab.pub")))
  })
}

resource "libvirt_domain" "vm" {
  count  = length(local.vms)
  name   = local.vms[count.index]
  memory = 2048
  vcpu   = 1

  # Repassa a CPU real do host (a imagem mysql:8 exige x86-64-v2, que a CPU padrao qemu64 nao tem)
  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.init[count.index].id

  network_interface {
    network_name   = "default"
    mac            = local.macs[local.vms[count.index]]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.disk[count.index].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

output "ips" {
  value = {
    for vm in libvirt_domain.vm : vm.name => vm.network_interface[0].addresses[0]
  }
}
