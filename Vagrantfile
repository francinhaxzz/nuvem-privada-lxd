# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "cloud-lab"

  # Rede Host-Only para comunicacao com o host
  config.vm.network "private_network", ip: "192.168.56.10"

  # Redirecionamento de portas para acesso aos servicos do projeto
  config.vm.network "forwarded_port", guest: 8081, host: 8081 # Nginx HTTP Prod
  config.vm.network "forwarded_port", guest: 8444, host: 8444 # Nginx HTTPS Prod
  config.vm.network "forwarded_port", guest: 8082, host: 8082 # Nginx HTTP Dev
  config.vm.network "forwarded_port", guest: 8445, host: 8445 # Nginx HTTPS Dev
  config.vm.network "forwarded_port", guest: 8443, host: 8443 # LXD API / UI

  config.vm.provider "virtualbox" do |vb|
    vb.name = "cloud-lab"
    vb.memory = "4096"
    vb.cpus = 2
  end

  # Provisionamento inicial basico
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y openssh-server curl snapd
    snap install lxd --channel=5.0/stable
    usermod -aG lxd vagrant
  SHELL
end
