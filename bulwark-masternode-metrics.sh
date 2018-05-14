#!/bin/sh
#
# Output Bulwark masernode metrics data for Mackerel

bulwarkcli="/usr/local/bin/bulwark-cli -conf=/root/.bulwark/bulwark.conf"
block_info_1day_ago_path="/tmp/bulwark-masternode-metrics-block-info-1day-ago.tmp"

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

block_count=`${bulwarkcli} getblockcount`

# Get over 24 hours block height
block_height=$((block_count - 1000))
if [ -e $block_info_1day_ago_path ]; then
  block_info_1day_ago_height=`cat $block_info_1day_ago_path | jq .height`
  if [ "$block_info_1day_ago_height" -gt 0 ]; then
    block_height="$block_info_1day_ago_height"
  fi
fi

while :; do
  block_hash=`${bulwarkcli} getblockhash $block_height`
  block=`${bulwarkcli} getblock $block_hash`
  block_time=`echo $block | jq .time`
  block_info_elapsed=$((current_time - block_time))

  if [ 86400 -ge $block_info_elapsed ]; then 
    echo $block > $block_info_1day_ago_path
    break;
  fi 

  block_height=$((block_height + 1))
done
block_count_day=$((block_count - block_height))

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
estimate_payout_hours=`echo "scale=2; 24 / ($block_count_day / $masternode_stable)" | bc`
print_metric payout.estimate_payout $estimate_payout_hours

# Output last paid elapsed time
lastpaid=`echo $masternode_ranked | jq .lastpaid`
metric_value=`echo "scale=2; ($current_time - $lastpaid) / 3600" | bc`
print_metric payout.lastpaid_elapsed $metric_value

# Output last seen elapsed time
lastseen=`echo $masternode_ranked | jq .lastseen`
metric_value=`echo "scale=2; ($current_time - $lastseen) / 60" | bc`
print_metric lastseen.elapsed_minutes $metric_value
