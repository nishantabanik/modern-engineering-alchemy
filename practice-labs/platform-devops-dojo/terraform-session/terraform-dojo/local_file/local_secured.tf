resource "local_file" "myfile" {
  filename = "/tmp/example.txt"
  content_base64  = base64encode("This is an example file created by Terraform local_file resource.")
  file_permission = "0777"
}