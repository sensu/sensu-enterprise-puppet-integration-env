SparkleFormation.new(:infrastructure) do
  nest!(:lazy_vpc__nat_subnet_vpc)
  nest!(:puppet_enterprise)
  nest!(:sensu_enterprise)
  nest!(:puppet_agents)
end
