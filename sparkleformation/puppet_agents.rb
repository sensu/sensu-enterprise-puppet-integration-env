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

  resources(:puppet_agent_launch_configuration) do
    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do |sets|
        sets.default += [ 'configure_aws_hostname', 'configure_ntp', 'cfn_hup', 'install_puppet_agent' ]
        sets.sensu [ ]
      end
    end
    registry!(:sensu_client,
      :queue_password => ref!(:rabbitmq_password),
      :rabbitmq_hostname => ref!(:rabbitmq_hostname)
    )
    registry!(:configure_aws_hostname)
    registry!(:configure_ntp)
    registry!(:cfn_hup, :puppet_agent, :resource_name => process_key!(:puppet_agent_launch_configuration))
    registry!(:install_puppet_agent)
  end
end
