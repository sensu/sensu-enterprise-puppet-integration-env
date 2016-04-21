SparkleFormation.new(:puppet).load(:base, :compute).overrides do

  dynamic!(:ec2_security_group, :puppet) do
    properties do
      group_description 'Puppet Compute Instances'
      vpc_id ref!(:vpc_id)
      security_group_ingress array!(
        -> {
          cidr_ip '0.0.0.0/0'
          from_port 22
          to_port 22
          ip_protocol 'tcp'
        }
      )
    end
  end

  resources(:puppet_instance_profile) do
    type 'AWS::IAM::InstanceProfile'
    properties do
      path '/'
      roles [ ref!(:cfn_role) ]
    end
  end

  resources(:puppet_ec2_instance) do
    type 'AWS::EC2::Instance'

    properties do
      instance_type 'm3.large'
      network_interfaces array!(
        -> {
          associate_public_ip_address true
          device_index 0
          subnet_id select!(1, ref!(:public_subnet_ids))
          group_set [ ref!(:puppet_ec2_security_group) ]
        }
      )
      image_id map!(:official_amis, region!, 'trusty')
      iam_instance_profile ref!(:puppet_instance_profile)
      key_name ref!(:ssh_key_name)
    end

    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do
        default [ ]
      end
    end
  end

  outputs do
    ssh_address do
      value join!('ubuntu@', attr!(:puppet_ec2_instance, :public_dns_name))
    end
  end

end
