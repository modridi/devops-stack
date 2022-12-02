resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
