SparkleFormation.new(:infrastructure) do
  nest!(:lazy_vpc__nat_subnet_vpc)
  nest!(:puppet)
end
