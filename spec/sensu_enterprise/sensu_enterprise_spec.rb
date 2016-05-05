require_relative '../spec_helper'

describe 'sensu enterprise' do

  %w( sensu-enterprise sensu-enterprise-dashboard redis-server rabbitmq-server ).each do |svc|
    describe service(svc) do
      it { should be_running }
    end
  end

  describe file('/etc/sensu/conf.d/integrations/puppet.json') do
    it { should exist }
  end

  describe command('rabbitmqctl list_users | grep "^sensu[[:space:]]*\\[.*\\]$"') do
    its(:stdout) { should match "sensu" }
    its(:exit_status) { should eq 0 }
  end

  describe command('rabbitmqctl list_vhosts | grep "^/sensu$"') do
    its(:stdout) { should match "/sensu" }
    its(:exit_status) { should eq 0 }
  end

  describe command('curl -s -i http://localhost:4567/health?consumers=1') do
    its(:stdout) { should match "HTTP/1.1 204 No Content" }
  end

end
