#
# Cookbook Name:: is_apaas_openshift_cookbook
# Resources:: openshift_deploy_router
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

use_inline_resources
provides :openshift_deploy_router if defined? provides

def whyrun_supported?
  true
end

action :create do
  converge_by "Deploy Router on #{node['fqdn']}" do
    execute 'Annotate Hosted Router Project' do
      command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} annotate --overwrite namespace/${namespace_router} openshift.io/node-selector=${selector_router}"
      environment(
        'selector_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_selector'],
        'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
      )
      not_if "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get namespace/${namespace_router} --template '{{ .metadata.annotations }}' | fgrep -q openshift.io/node-selector:${selector_router}"
      only_if "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get namespace/${namespace_router} --no-headers"
    end

    execute 'Create Hosted Router Certificate' do
      command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} create secret generic router-certs --from-file tls.crt=${certfile} --from-file tls.key=${keyfile} -n ${namespace_router}"
      environment(
        'certfile' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_certfile'],
        'keyfile' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_keyfile'],
        'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
      )
      cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
      only_if { ::File.file?(node['is_apaas_openshift_cookbook']['openshift_hosted_router_certfile']) && ::File.file?(node['is_apaas_openshift_cookbook']['openshift_hosted_router_keyfile']) }
      not_if "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get secret router-certs -n $namespace_router --no-headers"
    end

    deploy_options = %w(--selector=${selector_router} -n ${namespace_router}) + Array(new_resource.deployer_options)
    execute 'Deploy Hosted Router' do
      command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} adm router #{deploy_options.join(' ')} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig || true"
      environment(
        'selector_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_selector'],
        'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
      )
      cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
      only_if "[[ `#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get pod --selector=router=router --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig | wc -l` -eq 0 ]]"
    end

    execute 'Auto Scale Router based on label' do
      command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} scale dc/router --replicas=${replica_number} -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
      environment(
        'replica_number' => Mixlib::ShellOut.new("#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get node --no-headers --selector=#{node['is_apaas_openshift_cookbook']['openshift_hosted_router_selector']} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig | wc -l").run_command.stdout.strip,
        'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
      )
      cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
      not_if "[[ `#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get pod --selector=router=router --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig --no-headers | wc -l` -eq ${replica_number} ]]"
    end

    unless node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_env_router'].empty?
      node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_env_router'].each do |env|
        execute "Set ENV \"#{env.upcase}\" for Hosted Router" do
          command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} set env dc/router #{env} -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
          environment(
            'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
          )
          cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
          not_if "[[ `#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} env dc/router --list -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig` =~ \"#{env}\" ]]"
        end
      end
    end

    if node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_custom_router'] && ::File.exist?(node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_custom_router_file'])
      execute 'Create ConfigMap of the customised Hosted Router' do
        command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} create configmap customrouter --from-file=haproxy-config.template=#{node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_custom_router_file']} -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
        environment(
          'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
        )
        cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
        not_if "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get configmap customrouter -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
      end

      execute 'Set ENV TEMPLATE_FILE for customised Hosted Router' do
        command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} set env dc/router TEMPLATE_FILE=/var/lib/haproxy/conf/custom/haproxy-config.template -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
        environment(
          'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
        )
        cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
        not_if "[[ `#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} env dc/router --list -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig` =~ \"TEMPLATE_FILE=/var/lib/haproxy/conf/custom/haproxy-config.template\" ]]"
      end

      execute 'Set Volume for customised Hosted Router' do
        command "#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} volume dc/router --add --overwrite --name=#{node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_custom_name']} --mount-path=/var/lib/haproxy/conf/custom --type=configmap --configmap-name=customrouter -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig"
        environment(
          'namespace_router' => node['is_apaas_openshift_cookbook']['openshift_hosted_router_namespace']
        )
        cwd node['is_apaas_openshift_cookbook']['openshift_master_config_dir']
        not_if "[[ `#{node['is_apaas_openshift_cookbook']['openshift_common_client_binary']} get -o template dc/router --template={{.spec.template.spec.volumes}} -n ${namespace_router} --config=#{node['is_apaas_openshift_cookbook']['openshift_master_config_dir']}/admin.kubeconfig` =~ \"#{node['is_apaas_openshift_cookbook']['openshift_hosted_deploy_custom_name']}\" ]]"
      end
    end
  end
end
