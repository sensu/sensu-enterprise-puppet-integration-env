require_relative '../spec_helper'

describe 'puppet agents' do

  describe process('puppet agent') do
    it { should be_running }
  end

  describe process('sensu-client') do
    it { should be_running }
  end

end
