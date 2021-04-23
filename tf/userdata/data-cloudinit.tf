data "local_file" "common" {
  filename = "${path.module}/files/common.sh"
}

data "local_file" "tags" {
  filename = "${path.module}/files/tags.sh"
}

data "local_file" "hostname" {
  filename = "${path.module}/files/hostname.sh"
}

data "template_cloudinit_config" "common" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = data.local_file.common.content
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.local_file.tags.content
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.local_file.hostname.content
  }
}