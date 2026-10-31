output "rust_home" {
  description = "Directory of the installed Rust release on each host, by host name."
  value       = { for name in keys(var.hosts) : name => local.home }
}
