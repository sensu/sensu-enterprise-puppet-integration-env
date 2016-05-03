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

    puppet_security_group_id.type 'String'
    puppet_server_hostname.type 'String'
  end

  resources do
    sensu_ec2_instance do
      type 'AWS::EC2::Instance'
      serverspec do
        spec_patterns [File.join(Dir.pwd, 'spec/sensu_enterprise/*_spec.rb')]
      end
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
            group_set [ ref!(:sensu_security_group), ref!(:puppet_security_group_id) ]
          }
        )
        registry!(:cfn_user_data, :sensu,
          :init_resource => :sensu_ec2_instance,
          :signal_resource => :sensu_ec2_instance,
          :configsets => [ :default, :sensu_enterprise, :sensu ]
        )
        tags array!(
          -> {
            key 'Name'
            value join!(stack_name!, 'Sensu Enterprise', :options => { :delimiter => ' ' })
          }
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
          default [ :configure_aws_hostname, :install_puppet_agent, :cfn_hup, :create_keystores ]
          sensu_enterprise [ ]
          sensu [ ]
        end
        create_keystores do
          packages.apt do
            set!('openjdk-7-jre-headless', [])
          end
          commands('00_mkdir_etc_sensu_ssl_puppet') do
            command 'mkdir -p /etc/sensu/ssl/puppet'
          end
          commands('01_import_ca_to_truststore') do
            command 'keytool -import -alias "CA" -file /etc/puppetlabs/puppet/ssl/certs/ca.pem -keystore /etc/sensu/ssl/puppet/truststore.jks -storepass secret -noprompt'
            test 'test ! -e /etc/sensu/ssl/puppet/truststore.jks'
          end
          commands('02_generate_p12') do
            command 'cat /etc/puppetlabs/puppet/ssl/private_keys/$(hostname -f).pem /etc/puppetlabs/puppet/ssl/certs/$(hostname -f).pem | openssl pkcs12 -export -out /tmp/sensu-enterprise-temp.p12 -name sensu-enterprise -passout pass:secret'
            test 'test ! -e /etc/sensu/ssl/puppet/keystore.jks'
          end
          commands('03_import_p12_to_keystore') do
            command 'keytool -importkeystore  -destkeystore /etc/sensu/ssl/puppet/keystore.jks -srckeystore /tmp/sensu-enterprise-temp.p12 -srcstoretype PKCS12 -alias sensu-enterprise -srcstorepass secret -deststorepass secret'
            test 'test ! -e /etc/sensu/ssl/puppet/keystore.jks'
          end
        end
        sensu_enterprise_config do
          files('/etc/sensu/conf.d/integrations/puppet.json') do
            content.puppet do
              endpoint join!('https://', ref!(:puppet_server_hostname), ':8081/pdb/query/v4/nodes/')
              ssl do
                keystore_file '/etc/sensu/ssl/puppet/keystore.jks'
                keystore_password 'secret'
                truststore_file '/etc/sensu/ssl/puppet/truststore.jks'
                truststore_password 'secret'
              end
            end
          end
          files('/etc/sensu/conf.d/checks/check_truth.json') do
            content '{ "checks": { "check_truth": { "command": "true", "interval": 10, "subscribers": ["all"] } } }'
          end

          files('/etc/sensu/conf.d/keepalive.json') do
            content do
              handlers.keepalive do
                type 'set'
                handlers ['puppet']
              end
            end
          end
        end
        commands('create_config_dir') do
          command 'mkdir -p /etc/sensu && chown -R sensu.sensu /etc/sensu && chmod o-r /etc/sensu/ssl/puppet/*.jks'
        end
      end
      registry!(:configure_aws_hostname)
      registry!(:cfn_hup, :sensu_enterprise, :configsets => [:default, :sensu_enterprise, :sensu], :resource_name => process_key!(:sensu_ec2_instance))
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
