#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_control_plane37
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# This must be run before any upgrade takes place.
# It creates the service signer certs (and any others) if they were not in
# existence previously.
log "Upgrade will be skipped. Could not find the flag: #{node['cookbook-openshift3']['control_upgrade_flag']}" do
  level :warn
  not_if { ::File.file?(node['cookbook-openshift3']['control_upgrade_flag']) }
end

if ::File.file?(node['cookbook-openshift3']['control_upgrade_flag'])

  node.force_override['cookbook-openshift3']['upgrade'] = true
  node.force_override['cookbook-openshift3']['ose_major_version'] = node['cookbook-openshift3']['upgrade_ose_major_version']
  node.force_override['cookbook-openshift3']['ose_version'] = node['cookbook-openshift3']['upgrade_ose_version']
  node.force_override['cookbook-openshift3']['openshift_docker_image_version'] = node['cookbook-openshift3']['upgrade_openshift_docker_image_version']

  server_info = OpenShiftHelper::NodeHelper.new(node)
  is_master_server = server_info.on_master_server?
  is_node_server = server_info.on_node_server?

  if is_master_server
    config_options = YAML.load_file("#{node['cookbook-openshift3']['openshift_common_master_dir']}/master/master-config.yaml")
    unless config_options['kubernetesMasterConfig']['apiServerArguments'].key?('storage-backend')
      Chef::Log.error('The cluster must be migrated to etcd v3 prior to upgrading to 3.7')
      node.run_state['issues_detected'] = true
    end
  end

  include_recipe 'cookbook-openshift3::upgrade_control_plane37_part1' unless node.run_state['issues_detected']

  if is_master_server || is_node_server
    %w(excluder docker-excluder).each do |pkg|
      yum_package "#{node['cookbook-openshift3']['openshift_service_type']}-#{pkg} = #{node['cookbook-openshift3']['ose_version'].to_s.split('-')[0]}"
      execute "Enable #{node['cookbook-openshift3']['openshift_service_type']}-#{pkg}" do
        command "#{node['cookbook-openshift3']['openshift_service_type']}-#{pkg} disable"
      end
    end
  end
end