SparkleFormation.new(:puppet_enterprise).load(:base, :compute).overrides do

  pe_release = '2016.1.1'
  pe_release_arch = "puppet-enterprise-#{pe_release}-ubuntu-14.04-amd64"

  parameters(:puppet_enterprise_password) do
    type 'String'
    default 'secret'
  end

  dynamic!(:security_group_with_rules, :puppet,
    :ingress => {
      :ssh => {
        :protocol => 'tcp',
        :ports => 22
      },
      :https => {
        :protocol => 'tcp',
        :ports => 443
      },
      :puppet_server => {
        :protocol => 'tcp',
        :ports => 8140,
        :source_security_group => ref!(:puppet_security_group)
      },
      :puppetdb => {
        :protocol => 'tcp',
        :ports => 8081,
        :source_security_group => ref!(:puppet_security_group)
      },
      :mcollective => {
        :protocol => 'tcp',
        :ports => 61613,
        :source_security_group => ref!(:puppet_security_group)
      },
      :orchestration => {
        :protocol => 'tcp',
        :ports => 8142,
        :source_security_group => ref!(:puppet_security_group)
      }
    }
  )


  resources(:puppet_enterprise_instance_profile) do
    type 'AWS::IAM::InstanceProfile'
    properties do
      path '/'
      roles [ ref!(:cfn_role) ]
    end
  end

  resources(:puppet_enterprise_ec2_instance) do
    type 'AWS::EC2::Instance'
    serverspec do
      spec_patterns [File.join(Dir.pwd, 'spec/puppet_enterprise/*_spec.rb')]
    end
    properties do
      instance_type 'm3.large'
      network_interfaces array!(
        -> {
          associate_public_ip_address true
          device_index 0
          subnet_id select!(1, ref!(:public_subnet_ids))
          group_set [ ref!(:puppet_security_group) ]
        }
      )
      image_id map!(:official_amis, region!, 'trusty')
      iam_instance_profile ref!(:puppet_enterprise_instance_profile)
      key_name ref!(:ssh_key_name)
      user_data registry!(:cfn_user_data, :puppet,
        :init_resource => :puppet_enterprise_ec2_instance,
        :signal_resource => :puppet_enterprise_ec2_instance
      )
      tags array!(
        -> {
          key 'Name'
          value join!(stack_name!, 'Puppet Enterprise', :options => { :delimiter => ' ' })
        }
      )
    end

    creation_policy.resource_signal do
      count 1
      timeout 'PT15M'
    end

    registry!(:configure_aws_hostname)
    registry!(:configure_ntp)
    registry!(:cfn_hup, :puppet_enterprise, :resource_name => process_key!(:puppet_enterprise_ec2_instance))

    metadata('AWS::CloudFormation::Init') do
      _camel_keys_set(:auto_disable)
      configSets do |sets|
        default [
          :configure_aws_hostname,
          :configure_ntp,
          :cfn_hup,
          :install_puppet_enterprise
        ]
      end
      install_puppet_enterprise do
        sources do
          set!('/usr/src/', "https://s3.amazonaws.com/pe-builds/released/#{pe_release}/#{pe_release_arch}.tar.gz")
        end

        files('/etc/puppetlabs/puppet/autosign.conf') do
          content join!('*.', region!, '.compute.amazonaws.com')
        end

        files("/usr/src/#{pe_release_arch}/write-answers.sh") do
          content join!(
            "#!/bin/bash\n",
            "DOMAIN=",
            region!,
            ".compute.amazonaws.com\n",
            "HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname | cut -d . -f 1)\n",
            "LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)\n",
            "cat <<EOF > /usr/src/#{pe_release_arch}/answers.txt\n",
            "q_install=y\n",
            "q_vendor_packages_install=y\n",
            "q_puppetmaster_install=y\n",
            "q_all_in_one_install=y\n",
            "q_puppetagent_certname=$HOSTNAME.$DOMAIN\n",
            "q_puppetmaster_certname=$HOSTNAME.$DOMAIN\n",
            "q_puppetmaster_dnsaltnames=$HOSTNAME,$HOSTNAME.$DOMAIN\n",
            "q_pe_check_for_updates=y\n",
            "q_puppet_enterpriseconsole_httpd_port=443\n",
            "q_puppet_enterpriseconsole_auth_password=", ref!(:puppet_enterprise_password), "\n",
            "q_database_install=y\n",
            "q_puppetdb_database_name=pe-puppetdb\n",
            "q_puppetdb_database_password=", ref!(:puppet_enterprise_password), "\n",
            "q_puppetdb_database_user=pe-puppetdb\n",
            "EOF"
          )
          mode "000750"
        end

        commands('00_create_answers_file') do
          command "/usr/src/#{pe_release_arch}/write-answers.sh"
        end

        commands('01_install_puppet_enterprise') do
          command "/usr/src/#{pe_release_arch}/puppet-enterprise-installer -a /usr/src/#{pe_release_arch}/answers.txt"
          test 'test ! -d /opt/puppetlabs'
        end
      end
    end
  end

  outputs do
    ssh_address do
      value join!('ubuntu@', attr!(:puppet_enterprise_ec2_instance, :public_dns_name))
    end
    puppet_server_hostname do
      value attr!(:puppet_enterprise_ec2_instance, :public_dns_name)
    end
    puppet_security_group_id do
      value attr!(:puppet_security_group, :group_id)
    end
  end

end
