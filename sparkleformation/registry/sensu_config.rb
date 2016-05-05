SfnRegistry.register(:sensu_config) do |_name, _config = {}|
  metadata('AWS::CloudFormation::Init') do
    _camel_keys_set(:auto_disable)
    sensu_config do
      commands('00_create_config_dir') do
        command 'mkdir -p /etc/sensu && chown -R sensu.sensu /etc/sensu'
      end

      files('/usr/local/bin/sensu_client_generator.sh') do
        content join!(
          "#!/bin/bash\n",
          "cat <<EOF > /etc/sensu/conf.d/client.json\n",
          '{ "client": { "name": "$(hostname -f)", "address": "$(ip route get 8.8.8.8 | awk \'NR==1 {print $NF}\')", "subscriptions": ["all"] } }', "\n",
          "EOF"
        )
        mode "000750"
      end

      commands('01_generate_sensu_client_config') do
        command '/usr/local/bin/sensu_client_generator.sh'
        test 'test ! -e /etc/sensu/conf.d/client.json'
      end

      files('/etc/sensu/config.json') do
        content do
          rabbitmq array!(
            -> {
              host _config.fetch(:rabbitmq_host, '127.0.0.1')
              vhost _config.fetch(:rabbitmq_vhost, '/sensu')
              user _config.fetch(:rabbitmq_user, 'sensu')
              password _config.fetch(:rabbitmq_password, 'secret')
            })
        end
      end
    end
  end
end
