# Configure the Provider
provider "google" {
  project     = "your-project-id"
  region      = "us-central1"
  zone        = "us-central1-a"
}

# Create a Firewall Rule to Allow HTTP Traffic to the Load Balancer
resource "google_firewall" "allow_http_to_lb" {
  name    = "allow-http-to-lb"
  network = google_compute_network.default.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["http-lb"]
}

# Create a Compute Instance
resource "google_compute_instance" "jenkins_instance" {
  name         = "jenkins-instance"
  machine_type = "e2-medium"
  zone         = google_compute_network.default.zone

  network_interface {
    network = google_compute_network.default.id
    subnetwork = google_compute_subnetwork.default.id
    access_config {
      // Optional: If you need public IP access, uncomment this block
      // name = "external-nat"
    }
  }

  boot_disk {
    initialize_params {
      image = google_compute_image.debian.self_link
    }
  }

  metadata = {
    startup-script = <<EOF
      sudo apt-get update -y
      sudo apt-get install -y default-jdk openjdk-11-jdk
      sudo apt-get install -y wget
      wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-key | sudo apt-key add -
      echo deb https://pkg.jenkins.io/debian-stable binary/ | sudo tee -a /etc/apt/sources.list
      sudo apt-get update -y
      sudo apt-get install -y jenkins
      sudo systemctl start jenkins
      sudo systemctl enable jenkins
EOF
  }

  tags = ["http-lb"]
}

# Create a Load Balancer
resource "google_compute_forwarding_rule" "http_lb_forwarding_rule" {
  name       = "http-lb-forwarding-rule"
  ip_protocol = "TCP"
  port_range = "80"
  target = google_compute_target_pool.http_lb_target_pool.self_link
}

resource "google_compute_target_pool" "http_lb_target_pool" {
  name = "http-lb-target-pool"

  health_checks = [google_compute_health_check.http_health_check.self_link]

  instances = [google_compute_instance.jenkins_instance.self_link]
}

resource "google_compute_health_check" "http_health_check" {
  name        = "http-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port_specification = "8080"
  }
}
