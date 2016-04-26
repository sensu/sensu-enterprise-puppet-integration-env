SfnRegistry.register(:cfn_hup) do
  metadata('AWS::CloudFormation::Init') do
    _camel_keys_set(:auto_disable)
    cfn_hup do
      files('/etc/cfn/cfn-hup.conf') do
        content join!(
          "[main]\n",
          "interval=2\n",
          "region=", region!, "\n",
          "stack=", stack_id!, "\n"
        )
      end

      files('/etc/cfn/hooks.conf') do
        content join!(
          "[re-init]\n",
          "triggers=post.update\n",
          "path=Resources.#{resource_name!}.Metadata\n",
          "action=cfn-init --verbose --region ", region!,
          ' -s ', stack_name!,
          " -r #{resource_name!} ",
          " --configsets ", [ config.fetch(:configsets, :default) ].compact.flatten.join(','), "\n",
          "runas=root\n"
        )
      end
    end
  end
end
