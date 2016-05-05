SparkleFormation.new(:puppet_agents).load(:base, :compute).overrides do

  parameters.puppet_security_group_id.type 'String'
  parameters.rabbitmq_hostname.type 'String'
  parameters.rabbitmq_password.type 'String'

  dynamic!(
    :asg,
    :puppet_agent,
    :security_groups => ref!(:puppet_security_group_id)
  )

  resources(:puppet_agent_auto_scaling_group) do
    serverspec do
      spec_patterns [ 'shared/sensu_client_spec.rb', 'puppet_agents/*_spec.rb' ].map {|f|  File.join(Dir.pwd, 'spec', f) }
    end
  end

  resources(:puppet_agent_launch_configuration) do
    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do
        default [
          :configure_aws_hostname,
          :configure_ntp,
          :install_puppet_agent,
          :cfn_hup,
          :sensu_core_repo,
          :sensu_core_install,
          :sensu_config,
          :sensu_start
        ]
      end

      sensu_config do
        files('/etc/sensu/conf.d/client_puppet_agent_overrides.json') do
          content '{ "client": { "subscriptions": ["puppet_agent"], "keepalives": { "thresholds": { "warning": 40, "critical": 60 } } } }'
        end
      end

      sensu_start do
        services.sysvinit('sensu-client') do
          enabled 'true'
          ensureRunning 'true'
        end
      end
    end

    registry!(:sensu_core)
    registry!(:sensu_config)
    registry!(:configure_aws_hostname)
    registry!(:configure_ntp)
    registry!(:cfn_hup, :puppet_agent, :resource_name => process_key!(:puppet_agent_launch_configuration))
    registry!(:install_puppet_agent)
  end
end
