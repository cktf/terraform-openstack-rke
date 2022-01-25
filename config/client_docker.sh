#!/bin/bash
install_packages() {
    echo Installing packages
    sudo apt update
    sudo apt install -y unzip jq
}

install_xtemplate() {
    $URL=$1

    echo Installing xtemplate
    curl -fsSL -o /tmp/xtemplate.zip $URL
    sudo unzip -q /tmp/xtemplate.zip -d /usr/local/bin
    sudo mv /usr/local/bin/consul-template /usr/local/bin/xtemplate
    sudo chown root:root /usr/local/bin/xtemplate

    echo Configuring xtemplate
    sudo mkdir -p /etc/xtemplate.d /opt/xtemplate
    sudo cat <<-EOF >> /etc/xtemplate.d/agent.hcl
        vault {
            address      = "http://localhost:8200"
            token        = "root"
            unwrap_token = false
            renew_token  = false
        }
	EOF
    sudo cat <<-EOF >> /etc/systemd/system/xtemplate.service
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

        ## Configure unit start rate limiting. Units which are started more than
        ## *burst* times within an *interval* time span are not permitted to start any
        ## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
        ## systemd version) to configure the checking interval and `StartLimitBurst`
        ## to configure how many starts per interval are allowed. The values in the
        ## commented lines are defaults.

        # StartLimitBurst = 5

        ## StartLimitIntervalSec is used for systemd versions >= 230
        # StartLimitIntervalSec = 10s

        ## StartLimitInterval is used for systemd versions < 230
        # StartLimitInterval = 10s

        TasksMax=infinity
        OOMScoreAdjust=-1000

        [Install]
        WantedBy=multi-user.target
	EOF
}

install_consul() {
    $URL=$1

    echo Installing consul
    curl -fsSL -o /tmp/consul.zip $URL
    sudo unzip -q /tmp/consul.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/consul

    echo Configuring consul
    sudo mkdir -p /etc/consul.d /opt/consul
    sudo cat <<-EOF >> /etc/consul.d/agent.hcl
        datacenter = "dc1"
        data_dir   = "/opt/consul"
        server     = false

        # Gossip Encryption Section (UDP)
        encrypt                 = "qDOPBEr+/oUVeOFQOnVypxwDaHzLrD+lvjo5vCEBbZ0="
        encrypt_verify_incoming = true
        encrypt_verify_outgoing = true

        # RPC Encryption Section (TCP)
        # ca_file = "consul-agent-ca.pem"

        # When: Manual TLS (Clients)
        # cert_file = "dc1-client-consul-0.pem"
        # key_file  = "dc1-client-consul-0-key.pem"

        # verify_incoming        = true
        # verify_outgoing        = true
        # verify_server_hostname = true

        # When: Automatic TLS (Clients)
        # auto_encrypt {
        #   tls = true
        # }

        # acl {
        #   enabled        = true
        #   default_policy = "deny"
        #   down_policy    = "extend-cache"
        #   # TODO: Check needed
        #   enable_token_persistence = true
        #   enable_key_list_policy   = true

        #   # Create policy, token on servers then put in client config (Use Vault ?)
        #   tokens {
        #     agent = "????-????-????-????"
        #   }
        # }
	EOF
    sudo cat <<-EOF >> /etc/xtemplate.d/consul.hcl
        template {
            source      = "/etc/consul.d/agent.hcl.tpl"
            destination = "/etc/consul.d/agent.hcl"
            perms       = 0600
            command     = "sh -c 'date && sudo service consul restart'"
        }
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
    sudo cat <<-EOF >> /etc/consul.d/gossip.key.tpl
        {{ with secret "kv-v2/data/consul/config/encryption" }}
        {{ .Data.data.key}}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/consul.d/agent.key.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.private_key }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/consul.d/agent.crt.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.certificate }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/consul.d/ca.crt.tpl
        {{ with secret "pki_int/issue/consul-dc1" "common_name=server.dc1.consul" "ttl=24h"}}
        {{ .Data.issuing_ca }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/systemd/system/consul.service
        [Unit]
        Description=Consul
        Documentation=https://www.consul.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        User=consul
        Group=consul
        ExecReload=/bin/kill -HUP $MAINPID
        ExecStart=consul agent -config-dir=/etc/consul.d \
            -retry-join=$(cloud-init query ds.meta_data.meta.leader_ip)
        KillMode=process
        KillSignal=SIGINT
        LimitNOFILE=65536
        LimitNPROC=infinity
        Restart=on-failure
        RestartSec=2

        ## Configure unit start rate limiting. Units which are started more than
        ## *burst* times within an *interval* time span are not permitted to start any
        ## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
        ## systemd version) to configure the checking interval and `StartLimitBurst`
        ## to configure how many starts per interval are allowed. The values in the
        ## commented lines are defaults.

        # StartLimitBurst = 5

        ## StartLimitIntervalSec is used for systemd versions >= 230
        # StartLimitIntervalSec = 10s

        ## StartLimitInterval is used for systemd versions < 230
        # StartLimitInterval = 10s

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
    $URL=$1

    echo Installing nomad
    curl -fsSL -o /tmp/nomad.zip $URL
    sudo unzip -q /tmp/nomad.zip -d /usr/local/bin
    sudo chown root:root /usr/local/bin/nomad

    echo Configuring nomad
    sudo mkdir -p /etc/nomad.d /opt/nomad
    sudo cat <<-EOF >> /etc/nomad.d/agent.hcl
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
    sudo cat <<-EOF >> /etc/xtemplate.d/nomad.hcl
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
    sudo cat <<-EOF >> /etc/nomad.d/gossip.key.tpl
        {{ with secret "kv-v2/data/nomad/config/encryption" }}
        {{ .Data.data.key}}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/nomad.d/agent.key.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.private_key }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/nomad.d/agent.crt.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h" "alt_names=localhost" "ip_sans=127.0.0.1"}}
        {{ .Data.certificate }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/nomad.d/ca.crt.tpl
        {{ with secret "pki_int/issue/nomad-dc1" "common_name=server.dc1.nomad" "ttl=24h"}}
        {{ .Data.issuing_ca }}
        {{ end }}
	EOF
    sudo cat <<-EOF >> /etc/systemd/system/nomad.service
        [Unit]
        Description=Nomad
        Documentation=https://www.nomadproject.io/docs/
        Wants=network-online.target
        After=network-online.target

        # When using Nomad with Consul it is not necessary to start Consul first. These
        # lines start Consul before Nomad as an optimization to avoid Nomad logging
        # that Consul is unavailable at startup.
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

        ## Configure unit start rate limiting. Units which are started more than
        ## *burst* times within an *interval* time span are not permitted to start any
        ## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
        ## systemd version) to configure the checking interval and `StartLimitBurst`
        ## to configure how many starts per interval are allowed. The values in the
        ## commented lines are defaults.

        # StartLimitBurst = 5

        ## StartLimitIntervalSec is used for systemd versions >= 230
        # StartLimitIntervalSec = 10s

        ## StartLimitInterval is used for systemd versions < 230
        # StartLimitInterval = 10s

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

install_packages
install_xtemplate "${xtemplate_url}"
install_consul "${consul_url}"
install_nomad "${nomad_url}"
clear_cache
