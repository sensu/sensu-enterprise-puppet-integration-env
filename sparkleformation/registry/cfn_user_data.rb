SfnRegistry.register(:cfn_user_data) do |_name, _config|
  user_data(
    base64!(
      join!(
        "#!/bin/bash\n",
        "apt-get update\n",
        "apt-get -y install python-setuptools\n",
        "easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz\n",
        '/usr/local/bin/cfn-init -v --region ',
        region!,
        ' -s ',
        stack_name!,
        " -r #{process_key!(_config[:init_resource])} --role ",
        ref!(:cfn_role),
        ' --configsets ', [_config.fetch(:configsets, 'default')].flatten.compact.join(','),
        "\n",
        "/usr/local/bin/cfn-signal -e $? --region ",
        region!,
        ' --stack ',
        stack_name!,
        ' --resource ',
        process_key!(_config[:signal_resource]),
        "\n /usr/local/bin/cfn-hup --config /etc/cfn\n"
      )
    )
  )
end
