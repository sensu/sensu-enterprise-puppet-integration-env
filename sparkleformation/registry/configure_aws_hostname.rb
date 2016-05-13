SfnRegistry.register(:configure_aws_hostname) do
  metadata('AWS::CloudFormation::Init') do
    _camel_keys_set(:auto_disable)
    configure_aws_hostname do
      files('/etc/resolvconf/resolv.conf.d/tail') do
        # the last 'search' directive in compiled /etc/resolv.conf should win, so bring on the hacks
        # please don't copy this pattern for production :)
        mode "000644"
        content join!("search ec2.internal ", region!, ".compute.amazonaws.com\n")
      end
      files('/usr/local/bin/ec2-hostname.sh') do
        mode "000755"
        content join!(
                  "#!/bin/bash\n",
                  "DOMAIN=",
                  region!,
                  ".compute.amazonaws.com\n",
                  "HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname | cut -d . -f 1)\n",
                  "LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)\n",
                  "hostname $HOSTNAME.$DOMAIN\n",
                  "echo $HOSTNAME.$DOMAIN > /etc/hostname\n",
                  "cat<<EOF > /etc/hosts\n",
                  "# This file is automatically genreated by ec2-hostname script\n",
                  "127.0.0.1 localhost\n",
                  "$LOCAL_IPV4 $HOSTNAME.$DOMAIN $HOSTNAME\n",
                  "# The following lines are desirable for IPv6 capable hosts\n",
                  "::1 ip6-localhost ip6-loopback\n",
                  "fe00::0 ip6-localnet\n",
                  "ff00::0 ip6-mcastprefix\n",
                  "ff02::1 ip6-allnodes\n",
                  "ff02::2 ip6-allrouters\n",
                  "ff02::3 ip6-allhosts\n",
                  "EOF\n"
                )
      end
      commands('00_apt_get_update') do
        command 'sudo apt-get update'
      end
      commands('01_apt_get_install_curl') do
        command 'sudo apt-get -y install curl'
      end
      commands('02_configure_aws_hostname') do
        command 'sudo /usr/local/bin/ec2-hostname.sh'
      end
      commands('03_update_resolvconf') do
        command 'sudo resolvconf -u'
      end
    end
  end
end
