require_relative '../spec_helper'

describe 'sensu enterprise' do

  %w( sensu-enterprise sensu-enterprise-dashboard sensu-client redis-server ).each do |svc|
    describe service(svc) do
      it { should be_running }
    end
  end

  describe file('/etc/sensu/conf.d/integrations/puppet.json') do
    it { should exist }
  end

  describe command('curl -s -i http://localhost:4567/health?consumers=1') do
    its(:stdout) { should match "HTTP/1.1 204 No Content" }
  end

end
