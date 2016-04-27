SparkleFormation.dynamic(:asg) do |name, config={}|

  %w( min max ).each do |limit|
    parameters("#{name}_#{limit}_size".to_sym) do
      type 'Number'
      default 1
    end
  end

  parameters("#{name}_key_name".to_sym) do
    type 'String'
    default ENV['AWS_KEY_NAME'] if ENV.key?('AWS_KEY_NAME')
  end

  parameters("#{name}_instance_type".to_sym) do
    type 'String'
    default 't2.micro'
  end

  dynamic!(:iam_instance_profile, name) do
    properties do
      path '/'
      roles [ config.fetch(:iam_roles, ref!(:cfn_role)) ].compact.flatten
    end
  end

  dynamic!(:ec2_security_group, name) do
    properties do
      group_description "#{name} AutoScaling Group"
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

  dynamic!(:launch_configuration, name) do
    properties do
      instance_type ref!("#{name}_instance_type".to_sym)
      image_id map!(:official_amis, region!, 'trusty')
      key_name ref!("#{name}_key_name".to_sym)
      associate_public_ip_address config.fetch(:associate_public_ip_address, 'true')
      iam_instance_profile ref!("#{name}_iam_instance_profile".to_sym)
      security_groups [ config.fetch(:security_groups, ref!("#{name}_ec2_security_group".to_sym)) ].compact.flatten
      user_data registry!(:cfn_user_data, name,
        :init_resource => "#{name}_launch_configuration".to_sym,
        :signal_resource => "#{name}_auto_scaling_group".to_sym,
        :configsets => [ config.fetch(:configsets, :default) ].compact.flatten
      )
    end
  end

  dynamic!(:auto_scaling_group, name) do
    properties do
      v_p_c_zone_identifier config.fetch(:subnet_ids, ref!(:public_subnet_ids))
      launch_configuration_name ref!("#{name}_launch_configuration".to_sym)
      min_size ref!("#{name}_min_size".to_sym)
      max_size ref!("#{name}_max_size".to_sym)
      tags array!(
        -> {
          key 'Name'
          value join!(stack_name!, name, :options => { :delimiter => ' ' })
          propagate_at_launch true
        }
      )
    end

    creation_policy.resource_signal do
      count ref!("#{name}_min_size".to_sym)
      timeout 'PT15M'
    end
  end

 end
