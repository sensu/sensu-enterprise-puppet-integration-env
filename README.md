# Sensu Enterprise Puppet Integration Environment

This SparkleParty deploys an integration environment for testing Sensu Enterprise integration with Puppet Enterprise.

## Deploying

```
bundle install
bundle exec sfn create sensu-puppet-test --file infrastructure
```

## The players
* puppet enterprise (not running sensu-client)
* sensu enterprise (running puppet agent, sensu-client)
* an autoscaling cast of five puppet agents (running puppet agent, sensu-client. tagged in sensu with puppet_agent subscription)

## The scene
1. on the sensu node, run `sudo tail -f /var/log/sensu/sensu-enterprise.log | grep -v user_agent | grep puppet` to watch for puppet activity
2. observe on puppet and sensu dashboards that clients are registered etc.
3. note that autoscaling puppet agent instances are configured to auto register with puppet server and run sensu client
4. terminate instances in the autoscaling group, will cause sensu to alert on keepalives
5. revoking certificates on the puppet enterprise node will cause sensu to delete the associated sensu client object
6. observe via dashboard that sensu keepalive alerts are automatically resolved by puppet integration