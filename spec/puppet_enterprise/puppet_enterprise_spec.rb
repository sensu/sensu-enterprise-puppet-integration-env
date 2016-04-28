require_relative '../spec_helper'

describe 'puppet enterprise' do

  %w( puppetserver puppetdb activemq nginx console-services orchestration-services postgresql ).each do |svc|
    describe service("pe-#{svc}") do
      it { should be_running }
    end
  end

  describe process('puppet agent') do
    it { should be_running }
  end

end
