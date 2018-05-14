#!/bin/sh
#
# Output Bulwark masernode metrics data for Mackerel

bulwarkcli="/usr/local/bin/bulwark-cli -conf=/root/.bulwark/bulwark.conf"

# Number of blocks generated average in 24 hours
block_generated_size_day=912
current_time=`date +%s`

#
# Print metric data with Mackerel format.
#
# @param string $1 Metric name
# @param string $2 Metric value
#
print_metric () {
  echo "bulwark.$1\t$2\t${current_time}"
}

#
# Print block elapsed time since block generated
#
# @param string $1 Block height
#
get_block_elapsed_time () {
  local block_hash=`${bulwarkcli} getblockhash $1`
  local block_time=`${bulwarkcli} getblock $block_hash | jq .time`
  local elapsed_time=$((current_time - block_time))
  echo $elapsed_time
}

# Get generated block height in 24 hours
block_count=`${bulwarkcli} getblockcount`
block_height=$((block_count - block_generated_size_day))
block_generated_elapsed=`get_block_elapsed_time $block_height`
if [ $block_generated_elapsed -gt 86400 ]; then
  while [ $block_generated_elapsed -gt 86400 ]; do
    block_height=$((block_height + 1))
    block_generated_elapsed=`get_block_elapsed_time $block_height`
  done
else
  while [ 86400 -ge $block_generated_elapsed ]; do
    block_height=$((block_height - 1))
    block_generated_elapsed=`get_block_elapsed_time $block_height`
  done
  block_height=$((block_height + 1))
fi
block_generated_day=$((block_count - block_height))

# Get master node address on this server
addr=`${bulwarkcli} masternode status | jq -r .addr`

# Get masternode count
masternode_count=`${bulwarkcli} masternode count`

# Get specific address masternode ranked status
masternode_ranked=`${bulwarkcli} masternode list $addr | jq .[]`

# Output total server count
masternode_total=`echo $masternode_count | jq .total`
print_metric count.total $masternode_total

# Output stable server count
masternode_stable=`echo $masternode_count | jq .stable`
print_metric count.stable $masternode_stable

# Output rank
metric_value=`echo $masternode_ranked | jq .rank`
print_metric count.rank $metric_value

# Output activetime
activetime=`echo $masternode_ranked | jq .activetime`
metric_value=`echo "scale=3; $activetime / 86400" | bc`
print_metric activetime.days $metric_value

# Output estimate payout hours
estimate_payout_hours=`echo "scale=2; 24 / ($block_generated_day / $masternode_stable)" | bc`
print_metric payout.estimate_payout $estimate_payout_hours

# Output last paid elapsed time
lastpaid=`echo $masternode_ranked | jq .lastpaid`
lastpaid_elapsed=`echo "scale=2; ($current_time - $lastpaid) / 3600" | bc`
print_metric payout.lastpaid_elapsed $lastpaid_elapsed

# Output achievement rate
payout_rate=`echo "scale=3; ($lastpaid_elapsed / $estimate_payout_hours) * 100" | bc`
print_metric payout_rate.rate $payout_rate

# Output last seen elapsed time
lastseen=`echo $masternode_ranked | jq .lastseen`
metric_value=`echo "scale=2; ($current_time - $lastseen) / 60" | bc`
print_metric lastseen.elapsed_minutes $metric_value
