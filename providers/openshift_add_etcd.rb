#
# Cookbook Name:: cookbook-openshift3
# Resources:: openshift_add_etcd
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

use_inline_resources
provides :openshift_add_etcd if defined? provides

def whyrun_supported?
  true
end

action :add_node do
  etcd_servers = new_resource.etcd_servers
  etcd_servers.each do |etcd|
    bash 'add_etcd_nodes_if_needed' do
      code <<-EOH
        liste_nodes=$(etcdctl -C https://${ETCD_SERVER}:${ETCD_CLIENT_PORT} --cert-file $CRT --key-file $KEY --ca-file $CA member list | cut -d' ' -f2)
        if [[ ! $liste_nodes =~ "$ETCD_NODE_FQDN" ]]
        then
          etcdctl -C https://${ETCD_SERVER}:${ETCD_CLIENT_PORT} --cert-file $CRT --key-file $KEY --ca-file $CA member add $ETCD_NODE_FQDN https://${ETCD_NODE_IP}:${ETCD_PEER_PORT}
        fi
        EOH
      environment(
        'ETCD_SERVER' => etcd_servers.find { |etcd_node| etcd_node['fqdn'] == node['fqdn'] }['ipaddress'],
        'ETCD_CLIENT_PORT' => node['cookbook-openshift3']['etcd_client_port'],
        'ETCD_PEER_PORT' => node['cookbook-openshift3']['etcd_peer_port'],
        'CRT' => node['cookbook-openshift3']['etcd_peer_file'],
        'KEY' => node['cookbook-openshift3']['etcd_peer_key'],
        'CA' => node['cookbook-openshift3']['etcd_ca_cert'],
        'ETCD_NODE_FQDN' => etcd['fqdn'],
        'ETCD_NODE_IP' => etcd['ipaddress']
      )
    end
  end
  new_resource.updated_by_last_action(true)
end

action :remove_node do
  etcd_servers = new_resource.etcd_servers
  etcd_servers_to_remove = new_resource.etcd_servers_to_remove
  etcd_servers_to_remove.each do |etcd|
    bash 'remove_etcd_nodes_if_needed' do
      code <<-EOH
        liste_nodes=$(etcdctl -C https://${ETCD_SERVER}:${ETCD_CLIENT_PORT} --cert-file $CRT --key-file $KEY --ca-file $CA member list | cut -d' ' -f2)
        ID_SERVER=$(etcdctl -C https://${ETCD_SERVER}:${ETCD_CLIENT_PORT} --cert-file $CRT --key-file $KEY --ca-file $CA member list | grep $ETCD_NODE_FQDN | cut -d':' -f1)
        if [[ $liste_nodes =~ "$ETCD_NODE_FQDN" ]]
        then
          etcdctl -C https://${ETCD_SERVER}:${ETCD_CLIENT_PORT} --cert-file $CRT --key-file $KEY --ca-file $CA member remove $ID_SERVER
        fi
        EOH
      environment(
        'ETCD_SERVER' => etcd_servers.find { |etcd_node| etcd_node['fqdn'] == node['fqdn'] }['ipaddress'],
        'ETCD_CLIENT_PORT' => node['cookbook-openshift3']['etcd_client_port'],
        'ETCD_PEER_PORT' => node['cookbook-openshift3']['etcd_peer_port'],
        'CRT' => node['cookbook-openshift3']['etcd_peer_file'],
        'KEY' => node['cookbook-openshift3']['etcd_peer_key'],
        'CA' => node['cookbook-openshift3']['etcd_ca_cert'],
        'ETCD_NODE_FQDN' => etcd['fqdn']
      )
    end
  end
  new_resource.updated_by_last_action(true)
end
