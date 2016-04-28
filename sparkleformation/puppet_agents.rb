SparkleFormation.new(:puppet_agents).load(:base, :compute).overrides do

  parameters.puppet_security_group_id.type 'String'
  parameters.rabbitmq_hostname.type 'String'
  parameters.rabbitmq_password.type 'String'

  dynamic!(
    :asg,
    :puppet_agent,
    :security_groups => ref!(:puppet_security_group_id),
    :configsets => [:default, :sensu]
  )

  resources(:puppet_agent_auto_scaling_group) do
    serverspec do
      spec_patterns [File.join(Dir.pwd, 'spec/puppet_agents/*_spec.rb')]
    end
  end

  resources(:puppet_agent_launch_configuration) do
    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do |sets|
        sets.default += [
          'configure_aws_hostname',
          'configure_ntp',
          'cfn_hup',
          'install_puppet_agent'
        ]
      end
      sensu_client_install do
        files('/etc/sensu/conf.d/client_puppet_agent_overrides.json') do
          content '{ "client": { "subscriptions": ["puppet_agent"], "keepalives": { "thresholds": { "warning": 40, "critical": 60 } } } }'
        end
        services.sysvinit('sensu-client'.to_sym) do
          files ['/etc/sensu/conf.d/client_puppet_agent_overrides.json']
        end
      end
    end
    registry!(:sensu_client,
      :queue_password => ref!(:rabbitmq_password),
      :rabbitmq_hostname => ref!(:rabbitmq_hostname)
    )
    registry!(:configure_aws_hostname)
    registry!(:configure_ntp)
    registry!(:cfn_hup, :puppet_agent, :configsets => [:default, :sensu], :resource_name => process_key!(:puppet_agent_launch_configuration))
    registry!(:install_puppet_agent)
  end
end
