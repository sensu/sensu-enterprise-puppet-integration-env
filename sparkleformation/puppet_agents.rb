SparkleFormation.new(:puppet_agents).load(:base, :compute).overrides do

  dynamic!(:asg, :puppet_agent)

  resources(:puppet_agent_launch_configuration) do
  #   metadata('AWS::CloudFormation::Init') do
  #     _camel_keys_set(:auto_disable)
  #     configSets do |sets|
  #       sets.default sets.default.push('install_puppet')
  #     end
  #     install_puppet do
  #       packages do
  #         apt.set!('puppet', [])
  #       end
  #     end
  #   end
    registry!(:configure_aws_hostname)
  end

end
