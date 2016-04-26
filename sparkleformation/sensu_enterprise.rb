SparkleFormation.new(:sensu_enterprise).load(:base, :compute).overrides do
  registry!(:official_amis, :sensu, :type => 'ebs')

  parameters do
    public_subnet_ids do
      type 'CommaDelimitedList'
    end

    rabbitmq_password do
      type 'String'
      default ::SecureRandom.hex
    end
  end

  resources do
    sensu_ec2_instance do
      type 'AWS::EC2::Instance'
      properties do
        image_id map!(:official_amis, region!, 'trusty')
        instance_type 'm3.large'
        iam_instance_profile ref!(:sensu_instance_profile)
        key_name ref!(:ssh_key_name)
        network_interfaces array!(
          -> {
            associate_public_ip_address true
            device_index 0
            subnet_id select!(0, ref!(:public_subnet_ids))
            group_set [ ref!(:sensu_security_group) ]
          }
        )
        registry!(:cfn_user_data, :sensu,
          :init_resource => :sensu_ec2_instance,
          :signal_resource => :sensu_ec2_instance,
          :configsets => [ :default, :sensu_enterprise, :sensu ]
        )
      end
      creation_policy do
        resource_signal do
          count 1
          timeout 'PT15M'
        end
      end
      metadata('AWS::CloudFormation::Init') do
        _camel_keys_set(:auto_disable)
        configSets do
          default [ :configure_aws_hostname, :install_puppet_agent, :cfn_hup ]
          sensu_enterprise [ ]
          sensu [ ]
        end
        sensu_enterprise do
          files('/etc/sensu/conf.d/checks/check_truth.json') do
            content do
              checks.check_truth do
                subscribers ['all']
                command 'true'
                interval 10
              end
            end
          end
        end
      end
      registry!(:configure_aws_hostname)
      registry!(:cfn_hup, :sensu_enterprise, :resource_name => process_key!(:sensu_ec2_instance))
      registry!(:install_puppet_agent)
      registry!(:sensu_rabbitmq, :queue_password => ref!(:rabbitmq_password))
      registry!(:sensu_redis)
      registry!(:sensu_enterprise, :queue_password => ref!(:rabbitmq_password))
      registry!(:sensu_client, :queue_password => ref!(:rabbitmq_password))
    end

    sensu_instance_profile do
      type 'AWS::IAM::InstanceProfile'
      properties do
        path '/'
        roles [ ref!(:cfn_role) ]
      end
    end
  end

  dynamic!(:security_group_with_rules, :sensu,
    :ingress => {
      :ssh => {
        :protocol => 'tcp',
        :ports => 22
      },
      :http => {
        :protocol => 'tcp',
        :ports => 3000
      },
      :rabbitmq => {
        :protocol => 'tcp',
        :ports => 5672
      }
    },
    :egress => {
      :all => {
        :protocol => '-1',
        :ports => [1, 65535]
      }
    }
  )

  outputs do
    ssh_address do
      value join!('ubuntu@', attr!(:sensu_ec2_instance, :public_dns_name))
    end
    rabbitmq_hostname do
      value attr!(:sensu_ec2_instance, :public_dns_name)
    end
    rabbitmq_password do
      value ref!(:rabbitmq_password)
    end
    sensu_dashboard_url do
      value join!('http://', attr!(:sensu_ec2_instance, :public_dns_name), ':3000')
    end
  end
end
