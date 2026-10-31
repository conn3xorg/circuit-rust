variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "rust_version" {
  type        = string
  default     = "1.99.1"
  description = "Rust release to install, such as \"1.99.1\". Change checksums with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.rust_version))
    error_message = "rust_version must look like \"1.99.1\"."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the x86_64 and aarch64 rust-VERSION-TARGET.tar.xz tarballs, from each tarball's .sha256 file. Change these with rust_version."
  default = {
    x86_64  = "231fcae47ee950621374725b5fc3b5441d2fbda2955ac45dd7dc816d8876cfe7"
    aarch64 = "a48fb1e853be56ce9b8e2751f5464dbd5e16440cd81e237920f3a5e7e806333e"
  }

  validation {
    condition     = alltrue([for c in values(var.checksums) : can(regex("^[0-9a-f]{64}$", c))])
    error_message = "Each of checksums must be a SHA-256 in lowercase hex."
  }
}
