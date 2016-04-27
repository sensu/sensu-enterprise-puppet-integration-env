SfnRegistry.register(:install_puppet_agent) do

  root!.parameters do
    puppet_server_hostname.type 'String'
  end

  metadata('AWS::CloudFormation::Init') do
    _camel_keys_set(:auto_disable)
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
end
