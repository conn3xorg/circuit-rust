# Facts give each host's architecture, which picks the release tarball, and
# its distribution, which picks package names.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(keys(local.targets), self.arch)
      error_message = "Host ${each.key} is ${self.arch}. This circuit installs the x86_64 and aarch64 Linux GNU builds."
    }
  }
}

locals {
  targets = { x86_64 = "x86_64-unknown-linux-gnu", aarch64 = "aarch64-unknown-linux-gnu" }
  target  = { for name in keys(var.hosts) : name => lookup(local.targets, data.conn3x_host.facts[name].arch, data.conn3x_host.facts[name].arch) }
  release = { for name, t in local.target : name => "rust-${var.rust_version}-${t}" }
  home    = "/opt/rust/${var.rust_version}"
}

circuit "rust" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tool" {
    for_each = ["curl", "tar"]
    package {
      name = item.value
    }
  }

  step "xz" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "xz-utils" : "xz"
    }
  }

  # rustc calls cc to link, so a toolchain without gcc can't build a program.
  step "linker" {
    package {
      name = "gcc"
    }
  }

  step "libc" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libc6-dev" : "glibc-devel"
    }
  }

  step "dir" {
    directory {
      path = "/opt/rust"
    }
  }

  # The download step keeps the tarball only if it matches the checksum.
  step "download" {
    download {
      url    = "https://static.rust-lang.org/dist/${local.release[each.key]}.tar.xz"
      sha256 = var.checksums[data.conn3x_host.facts[each.key].arch]
      dest   = "/opt/rust/${local.release[each.key]}.tar.xz"
    }
  }

  # The tarball holds a set of components and an install.sh to merge them. The
  # docs and the rest stay out, because hosts rarely want them.
  step "install" {
    command {
      command = "cd /opt/rust && tar -xf '${local.release[each.key]}.tar.xz' && '${local.release[each.key]}/install.sh' --prefix='${local.home}' --components='rustc,cargo,rust-std-${local.target[each.key]},rustfmt-preview,clippy-preview' --disable-ldconfig && rm -rf '${local.release[each.key]}'"
      unless  = "[ -x '${local.home}/bin/rustc' ] && [ -x '${local.home}/bin/cargo' ] && [ -x '${local.home}/bin/rustfmt' ] && [ -x '${local.home}/bin/cargo-clippy' ]"
    }
  }

  step "link" {
    for_each = ["rustc", "rustdoc", "cargo", "rustfmt", "cargo-fmt", "cargo-clippy", "clippy-driver"]
    link {
      path   = "/usr/local/bin/${item.value}"
      target = "${local.home}/bin/${item.value}"
    }
  }
}
