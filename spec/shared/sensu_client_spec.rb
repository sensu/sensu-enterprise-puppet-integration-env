require_relative '../spec_helper'

describe 'sensu-client' do
  describe service('sensu-client') do
    it { should be_running }
  end

  describe port(3030) do
    it { should be_listening }
  end
end
