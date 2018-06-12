output "master" {
  value = "${aws_eip.master_ip.public_ip}"
}

output "worker" {
  value = "${aws_instance.worker.*.public_ip}"
}

output "master_internal" {
  value = "${aws_instance.master.private_ip}"
}

output "worker_internal" {
  value = "${aws_instance.worker.*.private_ip}"
}
