SparkleFormation.new(:puppet).load(:base, :compute).overrides do

  parameters(:puppet_enterprise_password) do
    type 'String'
    default 'secret'
  end

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
        },
        -> {
          cidr_ip '0.0.0.0/0'
          from_port 443
          to_port 443
          ip_protocol 'tcp'
        },
        -> {
          cidr_ip '0.0.0.0/0'
          from_port 8081
          to_port 8081
          ip_protocol 'tcp'
        },
        -> {
          cidr_ip '0.0.0.0/0'
          from_port 8140
          to_port 8140
          ip_protocol 'tcp'
        },
        -> {
          cidr_ip '0.0.0.0/0'
          from_port 61613
          to_port 61613
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
      user_data registry!(:cfn_user_data, :puppet,
        :init_resource => :puppet_ec2_instance,
        :signal_resource => :puppet_ec2_instance
      )
    end

    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do
        default [ 'install_puppet_enterprise'  ]
      end
      install_puppet_enterprise do
        sources do
          set!('/usr/src/puppet-enterprise', 'https://s3.amazonaws.com/pe-builds/released/2016.1.1/puppet-enterprise-2016.1.1-ubuntu-14.04-amd64.tar.gz')
        end
        files('/usr/src/puppet-enterprise/write-answers.sh') do
          content join!(
            "#!/bin/bash\n",
            "DOMAIN=compute-1.amazonaws.com\n",
            "HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname | cut -d . -f 1)\n",
            "LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)\n",
            "cat <<EOF > /usr/src/puppet-enterprise/answers.txt\n",
            "q_install=y\n",
            "q_vendor_packages_install=y\n",
            "q_puppetmaster_install=y\n",
            "q_all_in_one_install=y\n",
            "q_puppetagent_certname=$HOSTNAME.$DOMAIN\n",
            "q_puppetmaster_certname=$HOSNTAME.$DOMAIN\n",
            "q_puppetmaster_dnsaltnames=$HOSTNAME,$HOSTNAME.$DOMAIN\n",
            "q_pe_check_for_updates=y\n",
            "q_puppet_enterpriseconsole_httpd_port=443\n",
            "q_puppet_enterpriseconsole_auth_password=", ref!(:puppet_enterprise_password), "\n",
            "q_database_install=y\n",
            "q_puppetdb_database_name=pe-puppetdb\n",
            "q_puppetdb_database_password=", ref!(:puppet_enterprise_password), "\n",
            "q_puppetdb_database_user=pe-puppetdb\n"
          )
          mode 00750
        end

        commands('00_create_answers_file') do
          command '/usr/src/puppet-enterprise/write-answers.sh'
        end

        commands('01_install_puppet_enterprise') do
          command '/usr/src/puppet-enterprise/puppet-enterprise-installer -a /usr/src/puppet-enterprise/answers.txt'
        end
      end
    end
    registry!(:configure_aws_hostname)
  end

  outputs do
    ssh_address do
      value join!('ubuntu@', attr!(:puppet_ec2_instance, :public_dns_name))
    end
  end

end
