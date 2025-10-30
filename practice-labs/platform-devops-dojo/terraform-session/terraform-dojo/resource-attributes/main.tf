 resource "time_static" "time_update" {
}

resource "local_file" "time" {
  filename = "/tmp/time.txt"
  content = "Time stamp of this file is ${time_static.time_update.id}"
}