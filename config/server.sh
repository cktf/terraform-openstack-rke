#!/bin/bash

install_packages() {
    echo Installing packages
    sudo apt update
    sudo apt install -y unzip jq
}

install_transit() {
    echo Installing transit
    sudo curl -fsSL -o /tmp/transit.zip ${vault_url}
    sudo unzip -q /tmp/transit.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/transit

    echo Configuring transit
    sudo mkdir -p /etc/transit.d /opt/transit
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/transit.d/agent.hcl
        api_addr      = "http://$(hostname):8400"
        disable_mlock = true

        listener "tcp" {
            address         = "0.0.0.0:8400"
            tls_disable     = true
        }

        storage "file" {
            path = "/opt/transit"
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/systemd/system/transit.service
        [Unit]
        Description=Transit
        Documentation=https://www.vaultproject.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        User=transit
        Group=transit
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=transit server -config=/etc/transit.d
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2
        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
    sudo useradd -r -s /bin/false transit
    sudo chmod -R 0700 /etc/transit.d /opt/transit
    sudo chown -R transit:transit /etc/transit.d /opt/transit
    sudo systemctl enable transit

    echo Unsealing transit
    sudo systemctl start transit
    sleep 3
    
    export VAULT_ADDR=http://127.0.0.1:8400
    vault operator init -key-shares=1 -key-threshold=1 -format="json" > /tmp/keys.json
    export VAULT_TOKEN=$(cat /tmp/keys.json | jq -r '.root_token')
    vault operator unseal $(cat /tmp/keys.json | jq -r '.unseal_keys_b64[0]')
    vault secrets enable transit
    vault write -f transit/keys/autounseal
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /tmp/autounseal.hcl
        path "transit/encrypt/autounseal" {
            capabilities = [ "update" ]
        }

        path "transit/decrypt/autounseal" {
            capabilities = [ "update" ]
        }
	EOF
    vault policy write autounseal /tmp/autounseal.hcl
    vault token create -policy=autounseal -id=transit
}

install_vault() {
    echo Installing vault
    sudo curl -fsSL -o /tmp/vault.zip ${vault_url}
    sudo unzip -q /tmp/vault.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/vault

    echo Configuring vault
    sudo mkdir -p /etc/vault.d /opt/vault
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/vault.d/agent.hcl
        api_addr      = "http://$(hostname):8200"
        cluster_addr  = "http://$(hostname):8201"
        disable_mlock = true
        ui            = true

        listener "tcp" {
            address         = "0.0.0.0:8200"
            cluster_address = "0.0.0.0:8201"
            tls_disable     = true
            #   tls_cert_file      = "/opt/vault/tls/vault-cert.pem"
            #   tls_key_file       = "/opt/vault/tls/vault-key.pem"
            #   tls_client_ca_file = "/opt/vault/tls/vault-ca.pem"
        }

        storage "raft" {
            path = "/opt/vault"

            retry_join {
                leader_api_addr = "http://$(cloud-init query ds.meta_data.meta.leader_ip):8200"
                # leader_tls_servername   = "<VALID_TLS_SERVER_NAME>"
                # leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
                # leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
                # leader_client_key_file  = "/opt/vault/tls/vault-key.pem"
            }
        }

        seal "transit" {
            address         = "http://$(cloud-init query ds.meta_data.meta.leader_ip):8400"
            token           = "transit"
            key_name        = "autounseal"
            mount_path      = "transit/"
            disable_renewal = false
            tls_skip_verify = true
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/systemd/system/vault.service
        [Unit]
        Description=Vault
        Documentation=https://www.vaultproject.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        User=vault
        Group=vault
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=vault server -config=/etc/vault.d
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2
        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
    sudo useradd -r -s /bin/false vault
    sudo chmod -R 0700 /etc/vault.d /opt/vault
    sudo chown -R vault:vault /etc/vault.d /opt/vault
    sudo systemctl enable vault
}

install_xtemplate() {
    echo Installing xtemplate
    sudo curl -fsSL -o /tmp/xtemplate.zip ${xtemplate_url}
    sudo unzip -q /tmp/xtemplate.zip -d /usr/local/bin
    sudo mv /usr/local/bin/consul-template /usr/local/bin/xtemplate
    sudo chown root:root /usr/local/bin/xtemplate

    echo Configuring xtemplate
    sudo mkdir -p /etc/xtemplate.d /opt/xtemplate
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/xtemplate.d/agent.hcl
        vault {
            address      = "http://localhost:8200"
            token        = "root"
            unwrap_token = false
            renew_token  = false
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/systemd/system/xtemplate.service
        [Unit]
        Description=XTemplate
        Documentation=https://github.com/hashicorp/consul-template/
        Wants=network-online.target
        After=network-online.target

        [Service]
        User=xtemplate
        Group=xtemplate
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=xtemplate -config=/etc/xtemplate.d
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2
        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
}

install_consul() {
    echo Installing consul
    sudo curl -fsSL -o /tmp/consul.zip ${consul_url}
    sudo unzip -q /tmp/consul.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/consul

    echo Configuring consul
    sudo mkdir -p /etc/consul.d /opt/consul
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/consul.d/agent.hcl
        datacenter = "$(cloud-init query ds.meta_data.meta.datacenter)"
        retry_join = ["$(cloud-init query ds.meta_data.meta.leader_ip)"]
        data_dir   = "/opt/consul"
        server     = true

        bootstrap_expect   = 1
        leave_on_terminate = true

        addresses {
            http = "0.0.0.0"
        }
        # ports {
        #   grpc = 8502
        # }

        connect {
            enabled = true
        }

        ui_config {
            enabled = true
        }

        telemetry {

        }

        # Gossip Encryption Section (UDP)
        # encrypt                 = "gossip.key"
        # encrypt_verify_incoming = true
        # encrypt_verify_outgoing = true

        # RPC Encryption Section (TCP)
        # ca_file                = "ca.crt"
        # cert_file              = "agent.crt"
        # key_file               = "agent.key"
        # verify_incoming        = true
        # verify_outgoing        = true
        # verify_server_hostname = true

        acl {
            enabled                  = true
            default_policy           = "deny"
            down_policy              = "extend-cache"
            enable_token_persistence = true
            enable_key_list_policy   = true

            #   tokens {
            #     initial_management = "master.token"
            #     agent              = "master.token"
            #   }
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/xtemplate.d/consul.hcl
        template {
            source      = "/etc/consul.d/gossip.key.tpl"
            destination = "/etc/consul.d/gossip.key"
            perms       = 0600
            command     = "sh -c 'date && sudo service consul restart'"
        }
        template {
            source      = "/etc/consul.d/agent.key.tpl"
            destination = "/etc/consul.d/agent.key"
            perms       = 0600
            command     = "sh -c 'date && consul reload'"
        }
        template {
            source      = "/etc/consul.d/agent.crt.tpl"
            destination = "/etc/consul.d/agent.crt"
            perms       = 0600
            command     = "sh -c 'date && consul reload'"
        }
        template {
            source      = "/etc/consul.d/ca.crt.tpl"
            destination = "/etc/consul.d/ca.crt"
            perms       = 0600
            command     = "sh -c 'date && consul reload'"
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/consul.d/gossip.key.tpl
        {{ with secret "kv-v2/data/consul/config/encryption" }}
        {{ .Data.data.key}}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/consul.d/agent.key.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.private_key }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/consul.d/agent.crt.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.certificate }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/consul.d/ca.crt.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h"}}
        {{ .Data.issuing_ca }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/systemd/system/consul.service
        [Unit]
        Description=Consul
        Documentation=https://www.consul.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        User=consul
        Group=consul
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=consul agent -config-dir=/etc/consul.d
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2
        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
    sudo useradd -r -s /bin/false consul
    sudo chmod -R 0700 /etc/consul.d /opt/consul
    sudo chown -R consul:consul /etc/consul.d /opt/consul
    sudo systemctl enable consul
    # TODO: SConfigure DNS to forward to 8600 (Useful in debugging services from consul nodes)
}

install_nomad() {
    echo Installing nomad
    sudo curl -fsSL -o /tmp/nomad.zip ${nomad_url}
    sudo unzip -q /tmp/nomad.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/nomad

    echo Configuring nomad
    sudo mkdir -p /etc/nomad.d /opt/nomad
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/nomad.d/agent.hcl
        datacenter = "dc1"
        data_dir   = "/opt/nomad"

        server {
            enabled = true
        }

        consul {
            address = "127.0.0.1:8500"

            server_service_name = "nomad"
            client_service_name = "nomad-client"

            auto_advertise   = true
            server_auto_join = true
            client_auto_join = true
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/xtemplate.d/nomad.hcl
        template {
            source      = "/etc/nomad.d/agent.hcl.tpl"
            destination = "/etc/nomad.d/agent.hcl"
            perms       = 0600
            command     = "/opt/rotate_key.sh"
        }
        template {
            source      = "/etc/nomad.d/agent.key.tpl"
            destination = "/etc/nomad.d/agent.key"
            perms       = 0600
            command     = "/opt/rotate_key.sh"
        }
        template {
            source      = "/etc/nomad.d/agent.crt.tpl"
            destination = "/etc/nomad.d/agent.crt"
            perms       = 0600
            command     = "/opt/rotate_key.sh"
        }
        template {
            source      = "/etc/nomad.d/ca.crt.tpl"
            destination = "/etc/nomad.d/ca.crt"
            perms       = 0600
            command     = "/opt/rotate_key.sh"
        }
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/nomad.d/gossip.key.tpl
        {{ with secret "kv-v2/data/nomad/config/encryption" }}
        {{ .Data.data.key}}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/nomad.d/agent.key.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.private_key }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/nomad.d/agent.crt.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.certificate }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/nomad.d/ca.crt.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h"}}
        {{ .Data.issuing_ca }}
        {{ end }}
	EOF
    sudo cat <<-EOF | sed -r 's/^ {8}//' >> /etc/systemd/system/nomad.service
        [Unit]
        Description=Nomad
        Documentation=https://www.nomadproject.io/docs/
        Wants=network-online.target
        After=network-online.target
        Wants=consul.service
        After=consul.service

        [Service]
        User=nomad
        Group=nomad
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=nomad agent -config=/etc/nomad.d
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2
        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
    sudo useradd -r -s /bin/false nomad
    sudo chmod -R 0700 /etc/nomad.d /opt/nomad
    sudo chown -R nomad:nomad /etc/nomad.d /opt/nomad
    sudo systemctl enable nomad
}

clear_cache() {
    echo Clearing cache
    sudo rm -Rf /var/lib/apt/lists/*
    sudo rm -Rf /tmp

    sudo service vault start
    sudo service xtemplate start
    sudo service consul start
    sudo service nomad start
}

LEADER_IP=$(nslookup $(cloud-init query ds.meta_data.meta.leader_ip) | grep "Address" | awk '{print $2}' | sed -n 2p)
SELF_IP=$(nslookup $(hostname) | grep "Address" | awk '{print $2}' | sed -n 2p)

if [ $MASTER_IP == $SELF_IP ]
then
    install_transit
    export VAULT_ADDR=http://127.0.0.1:8200
    vault operator init -format="json" > /tmp/keys.json
    export VAULT_TOKEN=$(cat /tmp/keys.json | jq -r '.root_token')
fi

install_packages
install_vault
install_xtemplate
install_consul
# install_nomad
clear_cache

# leader        (consul, nomad)
# datacenter    (consul, nomad)
# ???           (consul, nomad) (wan federation)
# vault_leader  (wan federation)
# vault_token   (transit?) (generate VToken out of all regions)
# vault_key     (transit?) (generate RootCA out of all regions)
# vault_crt     (transit?)
# vault_ca      (transit?)