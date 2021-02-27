#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Configuration
echo "https://github.com/BlueSkyXN/DNS-AUTO-Switch"
echo "IP+1不好吗：https://www.blueskyxn.com"
echo "BlueSkyXN：开始读取配置"
# Ping API
PING_API=http://IP:8080/ping
echo "BlueSkyXN：Ping·API读取成功"
#使用https://github.com/TorchPing/go-torch 自行搭建测试API 默认监听端口为8080 你也可以用域名反代，记得有/ping

# Original IP
ORG_IP=1.1.1.1

# Failure IP
FAIL_IP=1.1.1.1

# Telegram Bot Token
TG_BOT_TOKEN=1254xxxx:AxxxxxxxxxxxxY

# Telegram Chat ID
TG_CHATID=13xxxx741

#域名 eg.blueskyxn.com
domain="blueskyxn.com"
#主机名 eg·www
host="www"

#End Point 终端地址 请根据地域选择
iam="iam.myhuaweicloud.com"
#eg·iam="iam.ap-southeast-1.myhuaweicloud.com"
#eg·iam="iam.ap-southeast-3.myhuaweicloud.com"

dns="dns.myhuaweicloud.com"
#eg·dns="dns.ap-southeast-1.myhuaweicloud.com"
#eg·dns="dns.ap-southeast-3.myhuaweicloud.com"

echo "BlueSkyXN：配置读取完毕，开启获取Token"

token_X="$(
    curl -L -k -s -D - -X POST \
        "https://$iam/v3/auth/tokens" \
        -H 'content-type: application/json' \
        -d '{
    "auth": {
        "identity": {
            "methods": [
                "password"
            ],
            "password": {
                "user": {
                    "domain": {
                        "name": "菊花帐号名"
                    },
                    "name": "IAM用户名", 
                    "password": "IAM密码" 
                }
            }
        },
        "scope": {
            "domain": {
                "name": "菊花帐号名"
            }
        }
    }
}' | grep X-Subject-Token
)"
echo "BlueSkyXN：Token应该获取成功了！唔呣"
token="$(echo $token_X | awk -F ' ' '{print $2}')"
echo "BlueSkyXN：开启正常运行"
recordsets="$(
    curl -L -k -s -D - \
        "https://$dns/v2/recordsets?name=$host.$domain." \
        -H 'content-type: application/json' \
        -H 'X-Auth-Token: '$token | grep -o "id\":\"[0-9a-z]*\"" | awk -F : '{print $2}' | grep -o "[a-z0-9]*"
)"

RECORDSET_ID=$(echo $recordsets | cut -d ' ' -f 1)
ZONE_ID=$(echo $recordsets | cut -d ' ' -f 2 | cut -d ' ' -f 2)


# Get current and old WAN ip

PRESENT_IP_FILE=$HOME/.ip_$host.$domain.txt
if [ -f $PRESENT_IP_FILE ]; then
  OLD_PRESENT_IP=`cat $PRESENT_IP_FILE`
else
  echo "No file, need IP，请前往root，建立.ip_$host.$domain.txt，然后填入IP"
  OLD_PRESENT_IP=""
fi

# Check service failure
CHECK=$(curl -s "$PING_API/$ORG_IP/22")

if [ "$(echo $CHECK | grep "\"status\":true")" != "" ]; then
  if [ "$ORG_IP" = "$OLD_PRESENT_IP" ]; then
    echo "No service failure found. No DNS record update required. "
    exit 0
  fi
  echo "No service failure found. Updating DNS to $ORG_IP"
  RESPONSE=$(curl -X PUT -L -k -s \
    "https://$dns/v2/zones/$ZONE_ID/recordsets/$RECORDSET_ID" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $token" \
    -d "{\"records\": [\"$ORG_IP\"],\"ttl\": 1}")  
  curl -s "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHATID&text=No service failure found. Updating DNS record $host.$domain to $ORG_IP"
  echo $ORG_IP > $PRESENT_IP_FILE
else
  if [ "$FAIL_IP" = "$OLD_PRESENT_IP" ]; then
    echo "Service failure found. No DNS record update required. "
    exit 0
  fi
  echo "Service failure found. Updating DNS to $FAIL_IP"
  RESPONSE=$(curl -X PUT -L -k -s \
    "https://$dns/v2/zones/$ZONE_ID/recordsets/$RECORDSET_ID" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $token" \
    -d "{\"records\": [\"$FAIL_IP\"],\"ttl\": 1}") 
  curl -s "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHATID&text=Service failure found. Updating DNS record $host.$domain to $FAIL_IP"
  echo $FAIL_IP > $PRESENT_IP_FILE
fi

if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
  echo "Updated succesfuly!"
  exit
else
  echo 'Something went wrong :('
  echo "Response: $RESPONSE"
  exit 1
fi
