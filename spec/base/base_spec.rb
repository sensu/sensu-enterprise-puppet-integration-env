require_relative '../spec_helper'

describe 'base' do

  describe port(22) do
    it { should be_listening }
  end

  describe process('cfn-hup') do
    it { should be_running }
  end

  describe process('puppet agent') do
    it { should be_running }
  end

  describe command('hostname -f') do
    its(:stdout) { should match(/^.*.compute-1.amazonaws.com$/) }
  end

end
