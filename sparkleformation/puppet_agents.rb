SparkleFormation.new(:puppet_agents).load(:base, :compute).overrides do

  parameters.puppet_server_hostname.type 'String'
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
        sets.default += [ 'configure_aws_hostname', 'configure_ntp', 'install_puppet_agent' ]
        sets.sensu [ ]
      end
      install_puppet_agent do
        commands('00_install_puppet_agent') do
          command join!(
            'curl -k https://', ref!(:puppet_server_hostname), ':8140/packages/current/install.bash | sudo bash'
          )
          test 'test ! -e /usr/local/bin/puppet'
        end
        commands('01_run_puppet_agent') do
          command join!(
            'puppet agent --server ', ref!(:puppet_server_hostname), ' --waitforcert 120 -D'
          )
        end
      end
    end
    registry!(:sensu_client,
      :queue_password => ref!(:rabbitmq_password),
      :rabbitmq_hostname => ref!(:rabbitmq_hostname)
    )
    registry!(:configure_aws_hostname)
    registry!(:configure_ntp)
  end
end
