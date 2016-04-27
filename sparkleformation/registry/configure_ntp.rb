SfnRegistry.register(:configure_ntp) do
  metadata('AWS::CloudFormation::Init') do
    _camel_keys_set(:auto_disable)
    configure_ntp do
      packages.apt do
        ntp array!()
      end

      files('/etc/ntp.conf') do
        content <<-EOH
# Use public servers from the pool.ntp.org project.
server 0.amazon.pool.ntp.org iburst
server 1.amazon.pool.ntp.org iburst
server 2.amazon.pool.ntp.org iburst
server 3.amazon.pool.ntp.org iburst
EOH
        mode "000644"
      end

      services.sysvinit.ntp do
        enabled 'true'
        ensureRunning 'true'
        files '/etc/ntp.conf'
      end

    end
  end
end
