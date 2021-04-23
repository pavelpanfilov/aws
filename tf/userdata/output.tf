output "cloudinit_common" {
  value = data.template_cloudinit_config.common.rendered
}