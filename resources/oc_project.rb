#
# Cookbook Name:: cookbook-openshift3
# Resources:: oc_project
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

provides :oc_project
property :project_name, String, required: true, name_property: true
property :description, String, default: '""'
property :display_name, String, default: '""'
property :node_selector, String, default: '""'

action :create do
  execute "Create Project [#{new_resource.project_name}]" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} adm new-project #{new_resource.project_name} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --node-selector=#{new_resource.node_selector} --description=#{new_resource.description} --display-name=#{new_resource.display_name}"
    sensitive true
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get namespace/#{new_resource.project_name} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
  end
end
